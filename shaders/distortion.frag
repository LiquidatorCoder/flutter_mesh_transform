#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;          // logical widget size (matches FlutterFragCoord units)
uniform float uProgress;     // 0..1 animation progress
uniform sampler2D uTexture;  // child snapshot

out vec4 fragColor;

float mapRange(float v, float inMin, float inMax, float outMin, float outMax) {
    return ((v - inMin) * (outMax - outMin) / (inMax - inMin) + outMin);
}

void main() {
    vec2 position = FlutterFragCoord().xy;
    vec2 p = position / uSize;

    // Mirror of Shader.metal:
    float xOffset = mapRange(p.x - 0.5, -0.5, 0.5, -1.0, 1.0);
    xOffset *= (1.0 - p.y);
    float xOffsetDenorm = xOffset * uSize.x * uProgress;
    float yOffsetDenorm = uSize.y * 1.3 * uProgress;

    vec2 srcPos = vec2(position.x + xOffsetDenorm, position.y + yOffsetDenorm);
    vec2 uv = srcPos / uSize; // 0..1 in widget space

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    fragColor = texture(uTexture, uv);
}
