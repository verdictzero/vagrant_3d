shader_type spatial;
render_mode unshaded, cull_back;
// A matcap: the surface is lit by looking up a sphere image by its view-space
// normal. No lights, no shadows, the same look from every angle of the camera.

uniform sampler2D matcap : source_color, filter_linear_mipmap;
uniform float tint : hint_range(0.0, 2.0) = 1.0;

varying vec3 v_normal;

void vertex() {
	// The normal matrix, not the model-view: a scaled object keeps its shading.
	v_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(v_normal);
	vec2 uv = n.xy * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	ALBEDO = texture(matcap, uv).rgb * tint;
}
