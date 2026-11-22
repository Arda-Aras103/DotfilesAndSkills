#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    float spinAmount;
    float contrast;
};

#define PIXEL_SIZE_FAC 700.0
#define SPIN_EASE 0.5

void main() {
    vec2 res = max(iResolution, vec2(1.0));
    vec2 fragCoord = qt_TexCoord0 * res;

    float pixel_size = length(res) / PIXEL_SIZE_FAC;
    vec2 uv = (floor(fragCoord / pixel_size) * pixel_size - 0.5 * res) / length(res) - vec2(0.12, 0.0);
    float uv_len = length(uv);

    float speed = iTime * SPIN_EASE * 0.2 + 302.2;
    float new_pixel_angle = atan(uv.y, uv.x) + speed - SPIN_EASE * 20.0 * (1.0 * spinAmount * uv_len + (1.0 - 1.0 * spinAmount));
    vec2 mid = (res / length(res)) * 0.5;
    uv = vec2(uv_len * cos(new_pixel_angle) + mid.x, uv_len * sin(new_pixel_angle) + mid.y) - mid;

    uv *= 30.0;
    float anim = iTime * 2.0;
    vec2 uv2 = vec2(uv.x + uv.y);

    for (int i = 0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + anim * 0.131121), sin(uv2.x - 0.113 * anim));
        uv -= 1.0 * cos(uv.x + uv.y) - 1.0 * sin(uv.x * 0.711 - uv.y);
    }

    float contrast_mod = 0.25 * contrast + 0.5 * spinAmount + 1.2;
    float paint_res = min(2.0, max(0.0, length(uv) * 0.035 * contrast_mod));
    float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
    float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
    float c3p = 1.0 - min(1.0, c1p + c2p);

    vec4 col1 = vec4(0.871, 0.267, 0.231, 1.0); // #DE443B Balatro Crimson
    vec4 col2 = vec4(0.000, 0.420, 0.706, 1.0); // #006BB4 Balatro Cobalt
    vec4 col3 = vec4(0.086, 0.137, 0.145, 1.0); // #162325 Deep Obsidian

    vec4 ret_col = (0.3 / contrast) * col1
                 + (1.0 - 0.3 / contrast) * (col1 * c1p + col2 * c2p + vec4(c3p * col3.rgb, c3p * col1.a));

    // Subtle CRT scanline + dark vignette for HUD contrast
    float scan = 0.94 + 0.06 * sin(fragCoord.y * 1.5);
    float vig = 1.0 - 0.28 * dot(qt_TexCoord0 - 0.5, qt_TexCoord0 - 0.5) * 2.2;
    fragColor = vec4(ret_col.rgb * scan * vig, 1.0) * qt_Opacity;
}
