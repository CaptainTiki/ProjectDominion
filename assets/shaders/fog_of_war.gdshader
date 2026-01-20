shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque, depth_test_default;

// RG mask texture:
//   R = explored (ever seen)
//   G = currently visible (active vision)
//   B/A unused
uniform sampler2D fog_tex : filter_nearest, repeat_disable;

// Visual tuning
uniform vec4 unseen_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 explored_color : source_color = vec4(0.0, 0.05, 0.09, 1.0);
uniform float unseen_alpha : hint_range(0.0, 1.0) = 0.95;
uniform float explored_alpha : hint_range(0.0, 1.0) = 0.65;

// Subtle movement so fog doesn't feel like a dead sticker.
uniform float noise_strength : hint_range(0.0, 0.5) = 0.08;
uniform float noise_speed : hint_range(0.0, 5.0) = 0.35;
uniform float noise_scale : hint_range(1.0, 200.0) = 48.0;

float hash21(vec2 p) {
    // Simple deterministic hash (cheap).
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

void fragment() {
    vec4 m = texture(fog_tex, UV);
    float explored = m.r;
    float visible = m.g;

    // Determine base alpha.
    float a = 0.0;
    vec3 col = unseen_color.rgb;

    if (visible > 0.5) {
        a = 0.0;
    } else if (explored > 0.5) {
        a = explored_alpha;
        col = explored_color.rgb;
    } else {
        a = unseen_alpha;
        col = unseen_color.rgb;
    }

    // Animated noise (only where fog exists).
    if (a > 0.001) {
        float n = hash21(UV * noise_scale + vec2(TIME * noise_speed, TIME * noise_speed * 0.73));
        float jitter = (n - 0.5) * 2.0;
        a = clamp(a + jitter * noise_strength, 0.0, 1.0);
    }

    ALBEDO = col;
    ALPHA = a;
}
