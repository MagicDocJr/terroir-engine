// Sky (time-lapse and visuals design §3): a physically based atmosphere (single scattering, Rayleigh + Mie, after
// Nishita / the Scratchapixel formulation) lit by the true sun, a cloud dome drawn from fbm noise and lit from the sun,
// and stars at night. The expensive part runs in the half-resolution pass; the full-resolution pass adds the sun disc
// and the stars. vineyard.gd drives everything from the sun position (_solar) and the day's weather (look only).
shader_type sky;
render_mode use_half_res_pass;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);      // towards the sun (world)
uniform float sun_intensity = 22.0;
uniform vec3 sun_disc_col = vec3(1.0, 0.95, 0.85);
uniform float night = 0.0;                        // 0 day … 1 full night (stars)
uniform float cloud_cover = 0.3;                  // 0 clear … 1 overcast
uniform float cloud_dark = 0.0;                   // rain clouds: darker, greyer bases
uniform vec2 cloud_offset = vec2(0.0);            // where the day's clouds start
uniform vec2 cloud_drift = vec2(0.0);             // drift per second (wind); animated with TIME so no uniform changes per frame
uniform float haze = 0.0;                         // mist / fog: pale lower sky
uniform vec3 night_col = vec3(0.018, 0.026, 0.055);
uniform float radiance_clamp = 3.0;

const float R_E = 6360e3;
const float R_A = 6420e3;
const vec3 BETA_R = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const float BETA_M = 21e-6;
const float H_R = 7994.0;
const float H_M = 1200.0;
const float G_M = 0.76;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float hash13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p; a *= 0.5; }
	return s;
}

vec2 ray_sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float h = b * b - c;
	if (h < 0.0) return vec2(-1.0);
	h = sqrt(h);
	return vec2(-b - h, -b + h);
}

// single-scattered sky radiance along rd for the sun in direction sd
vec3 atmosphere(vec3 rd, vec3 sd) {
	vec3 ro = vec3(0.0, R_E + 2.0, 0.0);
	float t1 = ray_sphere(ro, rd, R_A).y;
	const int N = 8;
	const int NL = 4;
	float seg = t1 / float(N);
	float odR = 0.0, odM = 0.0;
	vec3 sumR = vec3(0.0), sumM = vec3(0.0);
	for (int i = 0; i < N; i++) {
		vec3 p = ro + rd * (seg * (float(i) + 0.5));
		float h = length(p) - R_E;
		float hr = exp(-h / H_R) * seg;
		float hm = exp(-h / H_M) * seg;
		odR += hr; odM += hm;
		float tl = ray_sphere(p, sd, R_A).y;
		float segl = tl / float(NL);
		float odRl = 0.0, odMl = 0.0;
		bool lit = true;
		for (int j = 0; j < NL; j++) {
			vec3 q = p + sd * (segl * (float(j) + 0.5));
			float hl = length(q) - R_E;
			if (hl < 0.0) { lit = false; break; }
			odRl += exp(-hl / H_R) * segl;
			odMl += exp(-hl / H_M) * segl;
		}
		if (lit) {
			vec3 tau = BETA_R * (odR + odRl) + BETA_M * 1.1 * (odM + odMl);
			vec3 att = exp(-tau);
			sumR += att * hr;
			sumM += att * hm;
		}
	}
	float mu = dot(rd, sd);
	float pR = 3.0 / (16.0 * PI) * (1.0 + mu * mu);
	float pM = 3.0 / (8.0 * PI) * ((1.0 - G_M * G_M) * (1.0 + mu * mu)) / ((2.0 + G_M * G_M) * pow(1.0 + G_M * G_M - 2.0 * G_M * mu, 1.5));
	return sun_intensity * (sumR * BETA_R * pR + sumM * BETA_M * pM);
}

vec4 sky_and_clouds(vec3 rd) {
	vec3 d = rd;
	d.y = max(d.y, 0.035);                        // 8 samples can't integrate the grazing horizon path: no false dusk band
	d = normalize(d);
	vec3 col = atmosphere(d, sun_dir);
	// multiple scattering (not in the single-scattering model) whitens the daytime horizon: approximate it
	float hz = pow(1.0 - d.y, 10.0) * smoothstep(-0.05, 0.25, sun_dir.y);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))) * vec3(0.93, 0.97, 1.05) * 1.15, hz * 0.75);
	col += night_col * night;
	// clouds on a dome: project onto a plane, warp the fbm, light it from the sun (self-shadow sample + forward glow)
	float a = 0.0;
	if (rd.y > 0.0) {
		float t = 1.0 / (rd.y + 0.06);
		vec2 uv = rd.xz * t * 0.55 + cloud_offset + (AT_CUBEMAP_PASS ? vec2(0.0) : cloud_drift * TIME);
		vec2 w = vec2(fbm(uv * 0.7 + 3.1), fbm(uv * 0.7 + 7.3));
		float n = fbm(uv + (w - 0.5) * 1.3);
		float lo = 0.70 - cloud_cover * 0.52;       // fair-weather cumulus even on sunny days
		float dens = smoothstep(lo - 0.08, lo + 0.32, n);
		dens *= smoothstep(0.0, 0.12, rd.y);
		if (dens > 0.001) {
			float n2 = fbm(uv + (w - 0.5) * 1.3 + sun_dir.xz * 0.18);
			float shade = mix(1.0, 0.42, smoothstep(lo, lo + 0.4, n2));
			float mu = dot(rd, sun_dir);
			float fwd = pow(max(mu, 0.0), 8.0) * 2.2;
			vec3 sun_light = sun_disc_col * clamp(sun_dir.y * 4.0 + 0.25, 0.0, 1.0);
			// ambient from the sky just behind the cloud (a desaturated, brighter copy): no second atmosphere pass
			vec3 amb = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), 0.45) * 1.6 + night_col * night * 3.0;
			vec3 lit = sun_light * shade * (0.55 + fwd) * 0.6 + amb;
			vec3 grey = vec3(dot(lit, vec3(0.3, 0.59, 0.11)));
			lit = mix(lit, grey * 0.45, cloud_dark);
			col = mix(col, lit, dens * 0.95);
			a = dens;
		}
	}
	// mist and haze: pale lower sky
	if (haze > 0.001) {
		vec3 haze_col = vec3(dot(col, vec3(0.3, 0.59, 0.11))) * 1.25 + night_col * night;
		col = mix(col, haze_col, haze * pow(1.0 - clamp(rd.y, 0.0, 1.0), 3.0));
	}
	return vec4(col, a);
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = min(sky_and_clouds(EYEDIR).rgb, vec3(radiance_clamp));
	} else if (AT_HALF_RES_PASS) {
		vec4 c = sky_and_clouds(EYEDIR);
		COLOR = c.rgb;
		ALPHA = c.a;
	} else {
		vec3 col = HALF_RES_COLOR.rgb;
		float cloud = HALF_RES_COLOR.a;
		vec3 rd = EYEDIR;
		// sun disc (limb-darkened), hidden by clouds and by the horizon
		float mu = dot(rd, sun_dir);
		float disc = smoothstep(0.99996, 0.99999, mu);
		col += sun_disc_col * disc * 60.0 * (1.0 - cloud) * step(0.0, rd.y) * (1.0 - night);
		// stars and a faint Milky Way at night
		if (night > 0.01 && rd.y > 0.0) {
			vec3 p = rd * 260.0;
			vec3 c = floor(p);
			float h = hash13(c);
			float star = step(0.9975, h) * smoothstep(0.55, 0.0, length(fract(p) - 0.5));
			vec3 axis = normalize(vec3(0.35, 0.55, -0.76));
			float band = exp(-pow(dot(rd, axis) / 0.16, 2.0)) * (0.5 + 0.5 * fbm(rd.xz * 9.0 + rd.y * 4.0));
			vec3 sc = vec3(star * (0.5 + 2.5 * hash13(c + 7.0))) + vec3(0.55, 0.6, 0.8) * band * 0.035;
			col += sc * night * (1.0 - cloud) * smoothstep(0.0, 0.15, rd.y);
		}
		COLOR = col;
	}
}
