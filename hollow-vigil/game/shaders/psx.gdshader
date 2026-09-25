// PS1-style material: vertex snapping, nearest-filtered noise texture, tinted albedo.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float uv_scale = 1.0;
uniform float tex_strength = 0.55;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float snap_res = 160.0;
uniform bool world_uv = true;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(snap_res * 16.0 / 9.0, snap_res);
	clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	if (world_uv) {
		vec3 an = abs(wnorm);
		if (an.y > an.x && an.y > an.z) uv = wpos.xz;
		else if (an.x > an.z) uv = wpos.zy;
		else uv = wpos.xy;
		uv *= uv_scale * 0.25;
	}
	vec3 t = texture(tex, uv).rgb;
	ALBEDO = albedo.rgb * mix(vec3(1.0), t * 1.6, tex_strength);
	EMISSION = emission.rgb * emission_energy;
}
