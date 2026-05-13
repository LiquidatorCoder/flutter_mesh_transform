# flutter_mesh_transform

A drop-in mesh distortion / warp effect for any Flutter widget. Driven by a spring simulation and a fragment shader — flip a `bool` and the wrapped widget warps in or out.

## Install

```yaml
dependencies:
  flutter_mesh_transform: ^0.1.0
```

## Usage

```dart
import 'package:flutter_mesh_transform/flutter_mesh_transform.dart';

MeshTransform(
  active: isOpen,
  child: YourWidget(),
)
```

The widget owns its spring controller and caches the compiled shader program across instances, so it's safe to mount many of them.

### Parameters

| Param | Default | What it does |
| --- | --- | --- |
| `active` | required | When this flips, the warp animates between 0 and 1. |
| `child` | required | The widget to warp. |
| `xSpread` | `2.1` | Horizontal warp width. |
| `yFalloff` | `3.0` | How quickly the warp falls off vertically. |
| `yTravel` | `1.1` | Vertical displacement. |
| `response` | `0.85` | Spring response (seconds). Lower = snappier. |
| `dampingRatio` | `0.75` | Spring damping. 1.0 = critical. |
| `maxBlur` | `20.0` | Peak blur sigma at `active = true`. Set to `0` to disable. |
| `padding` | `EdgeInsets.symmetric(vertical: 40, horizontal: 24)` | Empty space around the child captured by the shader so the warp doesn't clip. |

## Example

See [`example/`](example/) for the demo app with interactive sliders for every parameter.
