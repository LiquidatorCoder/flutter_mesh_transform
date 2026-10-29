<h1 align="center">Flutter Mesh Transform 🌊</h1>

<p align="center">A drop-in mesh distortion / warp effect for any Flutter widget.</p>

<p align="center">
Driven by a spring simulation and a fragment shader — flip a <code>bool</code> and the wrapped widget warps in or out.
</p>

<p align="center">
  <img src="https://img.shields.io/pub/v/flutter_mesh_transform.svg?label=pub&color=blue" alt="pub" />
  <img src="https://img.shields.io/badge/Platform-Flutter-blue?logo=flutter" alt="Platform" />
  <img src="https://img.shields.io/badge/license-BSD--3-orange" alt="license" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/LiquidatorCoder/flutter_mesh_transform/main/demo/1.gif" alt="Mesh transform demo 1" width="30%" />
  <img src="https://raw.githubusercontent.com/LiquidatorCoder/flutter_mesh_transform/main/demo/2.gif" alt="Mesh transform demo 2" width="30%" />
  <img src="https://raw.githubusercontent.com/LiquidatorCoder/flutter_mesh_transform/main/demo/3.gif" alt="Mesh transform demo 3" width="30%" />
</p>

---

```yaml
dependencies:
  flutter_mesh_transform: ^0.1.2
```

```dart
import 'package:flutter_mesh_transform/flutter_mesh_transform.dart';

MeshTransform(
  active: isOpen,
  child: YourWidget(),
);
```

The widget owns its spring controller and caches the compiled shader program across instances, so it's safe to mount many of them:

- **At rest it costs nothing extra.** A resting `MeshTransform` paints its child directly — no offscreen pass, no
  snapshot texture — and once the warp has carried every pixel out of bounds it stops drawing (the child still
  receives taps, as before).
- **The child keeps its state.** Warping in and out never rebuilds the child, so text fields, scroll positions and
  running animations survive.

## 🎚️ API

`MeshTransform` parameters:

| Parameter      | Default                                                | Notes                                                                  |
| -------------- | ------------------------------------------------------ | ---------------------------------------------------------------------- |
| `active`       | required                                               | When this flips, the warp animates between 0 and 1.                    |
| `child`        | required                                               | The widget to warp.                                                    |
| `xSpread`      | `2.1`                                                  | Horizontal warp width.                                                 |
| `yFalloff`     | `3.0`                                                  | How quickly the warp falls off vertically.                             |
| `yTravel`      | `1.1`                                                  | Vertical displacement.                                                 |
| `response`     | `0.85`                                                 | Spring response (seconds). Lower = snappier.                           |
| `dampingRatio` | `0.75`                                                 | Spring damping. 1.0 = critical.                                        |
| `maxBlur`      | `20.0`                                                 | Peak blur sigma at `active = true`. Set to `0` to disable.             |
| `padding`      | `EdgeInsets.symmetric(vertical: 40, horizontal: 24)`   | Empty space around the child captured by the shader so it doesn't clip. |
| `shaderAsset`  | `'packages/flutter_mesh_transform/shaders/distortion.frag'` | Fragment shader to use. The at-rest and fully-warped shortcuts apply only to the bundled shader. |

## 📱 Platforms

Tested on **Android** and **iOS**; every change is checked by an on-device end-to-end suite on an iOS simulator in CI. Should work anywhere Flutter's fragment shader pipeline is supported, but other platforms are unverified.

## 🚀 Example

A runnable demo app with interactive sliders for every parameter — plus **replay** and **reset** — lives in [`example/`](example/):

```bash
cd example
flutter run
```

## 📄 License

BSD 3-Clause. See [LICENSE](LICENSE).
