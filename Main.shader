shader_type canvas_item;

// all this stuff gets controlled via my main gdscript code
uniform vec3 TRANSFORM;
uniform vec3 lookDir;
uniform int MAX_INCREASES = 15;
uniform int MODE = 0;
uniform vec3 FRIEND_POS; 
uniform bool FLOOR = false;


// i didnt need these pi and tau definitions here i think theyre from noodleswoops
const float PI = 3.14159265;
const float TAU = 2. * PI;

// constants for using 
const int MAX_STEPS = 50;
const float MAX_DIST = 30.;
const float SURF_DIST = .1;
const float TIME = 0.5;


// i think i took the formula from a stackoverflow post, there's a simpler way to express this using transforms and stuff but this works fine
// they rotate the point around the given axis, centered at the origin
vec3 rot_axis(vec3 p, vec3 a, float t) {
	float c = cos(t);
	float s = sin(t);
	mat3 r = mat3(
		vec3(c + a.x * a.x * (1. - c), a.x * a.y * (1. - c) - a.z * s, a.x * a.z * (1. - c) + a.y * s),
		vec3(a.y * a.x * (1. - c) + a.z*s, c + a.y * a.y * (1. - c), a.y * a.z * (1. - c) - a.x * s),
		vec3(a.z * a.x * (1. - c) - a.y * s, a.z * a.y * (1. - c) + a.x * s, c + a.z * a.z * (1. - c))
	);
	return r * p;
}

// these are for convenience
vec3 rot_x(vec3 p, float t) {
	return rot_axis(p, vec3(1,0,0), t);
}
vec3 rot_y(vec3 p, float t) {
	return rot_axis(p, vec3(0,1,0), t);
}
vec3 rot_z(vec3 p, float t) {
	return rot_axis(p, vec3(0,0,1), t);
}

// i took the folding formulas from here https://github.com/HackerPoet/PySpace/blob/master/pyspace/frag.glslhttps://github.com/HackerPoet/PySpace/blob/master/pyspace/frag.glsl
vec3 abs_fold(vec3 p, vec3 c) {
	return abs(p - c) + c;
}
 
vec3 plane_fold(vec3 p, vec3 n, float d){
	return p - 2.0 * min(0.0, dot(p, n) - d) * n;
}

float rand(float seed) {
	return fract(sin(seed * 46.2) * 9356.7);
}

// all of the distance functions were taken from or adapted from Inigo Quilez's incredibly useful article here https://iquilezles.org/articles/distfunctions/https://iquilezles.org/articles/distfunctions/
float dist_sphere(vec3 p, float r) {
	return length(p) - r;
}

float dist_box(vec3 p, vec3 b) {
	vec3 q = abs(p) - b;
	return length(max(q, vec3(0))) + min(max(q.x,max(q.y,q.z)),0.0);
}

float dist_line_segment(vec3 p, vec3 a, vec3 b) {
	vec3 m = b - a;
	float d;
	float t0 = dot(p-a, m)/dot(m,m);
	if (t0 <= 0.) d =  length(p-a);
	else if (t0 >=  1.) d = length(p-b);
	else d = length(p-(a+t0*m));
	return smoothstep(.4, .6, d) * d;
}

// this distance function is a remnant from noodleswoops, and isn't actually used in smallwalk
float dist_segment_growshrink(vec3 p, vec3 a, vec3 b) {
	float t = sin(TIME * 5. * rand(a.x * 47.62)) / 2. + .5 ;
	if (t < .5) return dist_line_segment(p, a, mix(a, b, t * 2.));
	else return dist_line_segment(p, mix(b, a, 1. - (t-.5) * 2.), b);
}

float dist_triprism(vec3 p, vec2 h){
  vec3 q = abs(p);
  return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

float dist_torus(vec3 p, vec2 t)
{
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

// compare the distances between two dcols, ignoring the color
vec4 dcol_min(vec4 a, vec4 b) {
	return a.x < b.x ? a : b;
}

// also taken from Quilez's article, this function repeats a block of space within a given area of space
vec3 replim(vec3 p, float c, vec3 l) {
	return p-c*clamp(round(p/c),-l,l);
}

// main distance estimator function
vec4 get_dist_and_col(vec3 p, float total) {
	float base = p.y; // the starting/default minimum distance (i.e. the distance to the ground)
	
	// this creates the color for the ground, including the path
	vec4 dcol = vec4(base, abs(p.x) > 3. ? vec3(1, (p.z-TRANSFORM.z) * 0.5/MAX_DIST - total * 0.01 , (p.z - TRANSFORM.z)*2./MAX_DIST - total/MAX_DIST) : sin(vec3((abs(p.x) *.5), (abs(p.z) * .3), .4 * TIME)) + 1. / 2.);
	
	float mul = 1.;
	
	//box zone at the start of the game
	dcol = dcol_min(dcol, vec4(dist_box(rot_y(replim(p - vec3(3, 5, 10), 10., vec3(3, 6, 3)), TIME), vec3(1, 2, 1)), 0, abs(sin(p.x + TIME)), fract(p.y)));

	//sphere zone (it ends up looking like circles since there's no lighting)
	for(float i = 1.; i < 20.; ++i) {
		dcol = dcol_min(dcol, vec4(dist_sphere(replim(p - vec3(0, 15, 130) - vec3(sin(TIME*3. + cos(1.5 * TIME*2./i)), cos(TIME*2.+i), sin(TIME)) * 10., 20., vec3(1, 0, 1)), 1), vec3(i/20., (20. - i)/20., 0)));
	}

	//prism zone where it transitions to black and white w/ the storms
	for(float i = 1.; i < 10.; ++i) {
		float t = sin(TIME + i );
		dcol = dcol_min(dcol, vec4(dist_triprism(abs_fold(rot_axis(abs_fold(p - vec3(0, 10, 250), (vec3(.5,t - i, t/2.))) , normalize(vec3(0,1,t-i)), t*i), vec3(0,-t-i, -t-i)), vec2(1, 5)), vec3(0,1,0)));
		dcol = dcol_min(dcol, vec4(dist_triprism(abs_fold(rot_axis(abs_fold(p - vec3(0, 10, 250), -(vec3(.5,t - i, t/2.))), normalize(vec3(0,1,t-i)), t*i), vec3(0,-t-i, -t-i)), vec2(1, 5)), vec3(0,1,0)));
	}
	
	//torus zone (the big stormy shape that the friend walks into at the end. the randomness added to the color creates the static-y noise in the visual.)
	for(float i = 1.; i < 10.; ++i) {
		vec3 q = p - vec3(sin(i) * 3., 10, 350);
		dcol = dcol_min(dcol, vec4(dist_torus(abs_fold(rot_z(rot_x(abs_fold(q, vec3(1,1,1)), sin(TIME / i * 2. + total)), TIME + i), vec3(-1, 0.5, -sin(total))), vec2(10, 3. + sin(TIME) * 2.)) * 1.2 + rand(fract(TIME + p.z)) * 0.5));
	}

	// this accounts for the color scheme transition between areas in the game, excluding the path
	if (dcol.x != base || dcol.x == base && abs(p.x) > 3.) {
		switch(MODE) {
				// mode 1 isn't used in smallwalk, just in noodleswoops
				case 1:
					dcol.gba = vec3(smoothstep(.1, .8, total/50.));
					break;
				// fade from full color to greyscale, with brightness inversely correlated with distance
				// for some reason i hardcoded the fade distance to be 50 instead of using the maximum distance. weird
				case 2:
					dcol.gba = mix(dcol.gba, vec3(1.-smoothstep(.1, .8, total/50.)), clamp((TRANSFORM.z - 220.) / 20., 0., 1.));
					break;
				default:
					break;
			}
	}
	// makes sure the path is still visible when in mode 2, averaging the 2 color channels to make greyscale instead of using distance
	else if (MODE == 2) {
		dcol.gba = mix(dcol.gba, vec3((dcol.g + dcol.b + dcol.a) / 3.), clamp((TRANSFORM.z - 220.) / 20., 0., 1.));
	}

	
	//shape friend (gets drawn after the mode related stuff in order to not be affected)
	for(float i = 0.; i < 5.; ++i) {
		// position is set via a uniform, but moves up and down over time for more naturalism. i could have done that in the gdscript code but i didnt for some reason lmao
		// i also could have put this definition in an enclosing scope instead of it being redefined every loop step but ig this is easier to look at?
		vec3 q = p - FRIEND_POS - vec3(-3, sin(TIME * 2.5) * .15, 4.5); 
		dcol = dcol_min(dcol, vec4(dist_box(rot_axis(q, normalize(vec3(1, 1, TAU * i / 5.)), TIME + TAU * i / 5.), vec3(.5, .5, .5)), vec3(0,(sin(i) + 1.) / 2., 1)));
	}
	
	// this is the behavior when a ray doesn't hit anything
	if(dcol.x >= SURF_DIST) {
		if(TRANSFORM.z > 100.)
		// after walking 100 down the path, it defaults to the most recent color that was *closest* to the ray (without hitting it), which creates the cool wavy voronoi-type effect
		{
			vec3 new_col;
			switch(MODE) {
				case 0:
					new_col = dcol.gba * MAX_DIST/(p.z - TRANSFORM.z);
					break;
				case 1:
					new_col = vec3(smoothstep(.1, .8, total/50.));
					break;
				case 2:
					new_col = mix(dcol.gba, vec3(1.-smoothstep(.1, .8, total/50.)), clamp((TRANSFORM.z - 220.) / 20., 0., 1.));
					break;
			}
			dcol.gba = mix(vec3(0), new_col, clamp((TRANSFORM.z - 100.)/20., 0., 1.));
		}
		else 
		// before that it defaults to black tho
		{
			dcol.gba = vec3(0);
		}
	}
	return dcol;
}


// these 3 functions were for lighting, which i experimented with, but didnt actually use in smallwalk or noodleswoops
float get_dist(vec3 p) {
	return get_dist_and_col(p, 0).x;
}

vec3 get_normal(vec3 p) {
	vec2 e = vec2(.01, 0);
	float d = get_dist(p);
	vec3 n = d - vec3(
		get_dist(p-e.xyy),
		get_dist(p-e.yxy),
		get_dist(p-e.yyx)
	);
	return normalize(n);
}

float get_light(vec3 p, vec3 light_pos) {
	vec3 l = normalize(light_pos - p);
	vec3 n = get_normal(p);

	return smoothstep(.5, .9, .5 * (dot(n, l) + 1.));
}

// the actual raymarching loop. pretty much directly lifted from this video https://www.youtube.com/watch?v=PGtv-dBi2wEhttps://www.youtube.com/watch?v=PGtv-dBi2wEa, but adapted for my coloring system, with some modifications
vec4 ray_march(vec3 ro, vec3 rd) {
	vec4 dO = vec4(0);
	float min_dist = MAX_DIST;
	int count = 0;
	for(int i = 0; i<MAX_STEPS; i++) {
		vec3 p = ro + rd * dO.x;
		vec4 dS = get_dist_and_col(p,dO.x);
		dO.x += dS.x;
		count += int(min_dist < dS.x);
		min_dist = min(dS.x, min_dist);
		dO.yzw = dS.yzw;
		// the MAX_INCREASES here makes the raymarcher give up if the ray keeps getting further from a shape. i originally put it here to help with optimization, which it didn't really help much with, but it works real good to fuck with the way the voronoi patterns look when that's enabled
		if(dO.x > MAX_DIST || count > MAX_INCREASES || dS.x < SURF_DIST) break;
	}
	return dO;
}

// most of my main fragment function is also lifted from that video but w/ the coloring adaptations
void fragment() {
	vec2 uv = SCREEN_UV - .5;
	uv.x *= SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x;
	
// residual lighting code	
//	vec3 light_pos = vec3(0, 5, 6) + vec3(cos(TIME), 0, sin(TIME)) * 2.;
    
    vec3 ro = TRANSFORM;
    float zoom = 1.;
    vec3 lookAt = ro + lookDir;
    vec3 f = normalize(lookAt-ro);
    vec3 r = cross(vec3(0., 1., 0.), f);
    vec3 u = cross(f,r);
    vec3 c = ro + f * zoom;
    vec3 i = c + uv.x * r + uv.y * u;
    vec3 rd = i-ro;

    
    vec4 dcol = ray_march(ro, rd);
	float d = dcol.x;
	vec3 col = dcol.yzw;
	
// even more residual lighting code	
//	vec3 p = ro + rd * d;
	
//	float dif = get_light(p, light_pos);
//	col += vec3(dif);

	COLOR = vec4(col, 1);
	
}
