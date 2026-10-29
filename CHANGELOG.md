# Changelog

## Unreleased

- Fix: the child's `State` is no longer recreated every time `active` changes (the blur and shader wrappers used to be
  inserted and removed, rebuilding the subtree).
- Fix: the spring now settles exactly on its target, so a resting widget is no longer left ~1px warped and blurred.
- Fix: changing `shaderAsset` together with `active` now loads the new shader; a slower stale load can no longer
  overwrite a newer one; a replacement that fails to load falls back to the plain child instead of keeping the old
  shader; shaders are disposed.
- Perf: no offscreen pass at rest or once the warp has moved every pixel out of bounds. A resting instance paints its
  child directly (pixel-identical to the plain child) instead of holding a full-resolution snapshot texture.
- Debug builds print why the shader failed to load instead of failing silently.

## 0.1.1

- Use absolute GitHub raw URLs for demo GIFs in README so they render on pub.dev.

## 0.1.0

- Initial release.
- `MeshTransform` widget: spring-driven mesh distortion for any child widget via a fragment shader.
- Tunables: `xSpread`, `yFalloff`, `yTravel`, `response`, `dampingRatio`, `maxBlur`, `padding`.
- Example app with interactive sliders for every parameter.
