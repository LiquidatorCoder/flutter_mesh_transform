#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;          // logical widget size (matches FlutterFragCoord units)
uniform float uProgress;     // 0..1 animation progress
uniform float uXSpread;      // horizontal spread strength (Swift literal: 1.0)
uniform float uYFalloff;     // exponent on (1 - p.y) — 1.0 = linear, >1 sharper
uniform float uYTravel;      // vertical travel multiplier (Swift literal: 1.3)
uniform sampler2D uTexture;  // child snapshot

out vec4 fragColor;

float mapRange(float v, float inMin, float inMax, float outMin, float outMax) {
    return ((v - inMin) * (outMax - outMin) / (inMax - inMin) + outMin);
}

void main() {
    vec2 position = FlutterFragCoord().xy;
    vec2 p = position / uSize;

    float xOffset = mapRange(p.x - 0.5, -0.5, 0.5, -uXSpread, uXSpread);
    xOffset *= pow(max(1.0 - p.y, 0.0), uYFalloff);
    float xOffsetDenorm = xOffset * uSize.x * uProgress;
    float yOffsetDenorm = uSize.y * uYTravel * uProgress;

    vec2 srcPos = vec2(position.x + xOffsetDenorm, position.y + yOffsetDenorm);
    vec2 uv = srcPos / uSize;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    fragColor = texture(uTexture, uv);
}
