import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

/// A drop-in mesh distortion / warp effect for any Flutter widget.
///
/// Wrap any [child] with [MeshTransform] and flip [active] to animate the
/// warp between 0 and 1 using a critically-tunable spring simulation. The
/// distortion itself is rendered by a fragment shader bundled with this
/// package.
///
/// ```dart
/// MeshTransform(
///   active: isOpen,
///   child: YourWidget(),
/// )
/// ```
class MeshTransform extends StatefulWidget {
  const MeshTransform({
    super.key,
    required this.active,
    required this.child,
    this.xSpread = 2.1,
    this.yFalloff = 3.0,
    this.yTravel = 1.1,
    this.response = 0.85,
    this.dampingRatio = 0.75,
    this.maxBlur = 20.0,
    this.padding = const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    this.shaderAsset = 'packages/flutter_mesh_transform/shaders/distortion.frag',
  });

  /// When this flips, the warp animates between 0 (off) and 1 (fully warped).
  final bool active;

  /// The widget to warp.
  final Widget child;

  /// Horizontal warp width. Higher values spread the distortion further.
  final double xSpread;

  /// How quickly the warp falls off vertically. Higher = tighter falloff.
  final double yFalloff;

  /// Vertical displacement at peak warp.
  final double yTravel;

  /// Spring response in seconds. Lower values are snappier. Takes effect on the next change of [active].
  final double response;

  /// Spring damping ratio. 1.0 is critical damping; below 1.0 overshoots. Takes effect on the next change
  /// of [active].
  final double dampingRatio;

  /// Peak blur sigma applied at `active == true`. Set to `0` to disable blur.
  final double maxBlur;

  /// Empty space around the child captured by the shader so the warp can
  /// extend past the child's bounds without clipping.
  final EdgeInsets padding;

  /// Asset path of the fragment shader to use. Defaults to the bundled
  /// distortion shader.
  final String shaderAsset;

  @override
  State<MeshTransform> createState() => _MeshTransformState();
}

class _MeshTransformState extends State<MeshTransform> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.FragmentShader? _shader;
  final Paint _paint = Paint();

  static final Map<String, Future<ui.FragmentProgram>> _programCache = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: widget.active ? 1 : 0);
    _loadShader();
  }

  @override
  void didUpdateWidget(MeshTransform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      _animateTo(widget.active ? 1 : 0);
    }
    if (widget.shaderAsset != oldWidget.shaderAsset) {
      _loadShader();
    }
  }

  Future<void> _loadShader() async {
    final asset = widget.shaderAsset;
    try {
      final program = await _programCache.putIfAbsent(asset, () => ui.FragmentProgram.fromAsset(asset));
      // A newer shaderAsset superseded this request while it was loading.
      if (!mounted || widget.shaderAsset != asset) return;
      final previous = _shader;
      setState(() => _shader = program.fragmentShader());
      previous?.dispose();
    } catch (error) {
      // Shader asset missing or failed to compile — fall through and render
      // the child without distortion rather than crashing the host app.
      _programCache.remove(asset);
      assert(() {
        debugPrint('MeshTransform: failed to load shader "$asset": $error');
        return true;
      }());
      // The failed request is still the current one: don't keep rendering with the previous asset's shader.
      if (mounted && widget.shaderAsset == asset && _shader != null) {
        final previous = _shader;
        setState(() => _shader = null);
        previous?.dispose();
      }
    }
  }

  void _animateTo(double target) {
    final stiffness = math.pow(2 * math.pi / widget.response, 2).toDouble();
    final damping = 4 * math.pi * widget.dampingRatio / widget.response;
    final spring = SpringDescription(mass: 1, stiffness: stiffness, damping: damping);
    _controller.animateWith(SpringSimulation(spring, _controller.value, target, _controller.velocity, snapToEnd: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Padding(padding: widget.padding, child: widget.child),
      builder: (context, child) {
        final t = _controller.value;
        final shader = _shader;

        final atRest = t == 0;
        // Without a shader the fallback is the blurred, undistorted child, which is never fully hidden.
        final hidden = shader != null && _isFullyWarpedAway(t, widget.yTravel);
        final blur = atRest || hidden ? 0.0 : (t * widget.maxBlur).clamp(0.0, double.infinity);

        // The wrapper structure is identical every frame (only the flags change) so the child's element subtree and
        // State are never rebuilt. Opacity 0 skips painting but keeps hit-testing, as the invisible child had before.
        return Opacity(
          opacity: hidden ? 0 : 1,
          child: ImageFiltered(
            enabled: blur > 0,
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: AnimatedSampler(enabled: shader != null && !atRest && !hidden, (image, size, canvas) {
              if (shader == null) return;
              shader
                ..setFloat(0, size.width)
                ..setFloat(1, size.height)
                ..setFloat(2, t)
                ..setFloat(3, widget.xSpread)
                ..setFloat(4, widget.yFalloff)
                ..setFloat(5, widget.yTravel)
                ..setImageSampler(0, image);
              canvas.drawRect(Offset.zero & size, _paint..shader = shader);
            }, child: child!),
          ),
        );
      },
    );
  }
}

/// True when every fragment of shaders/distortion.frag samples outside [0, 1] and outputs transparent.
///
/// The shader samples `uv.y = (pos.y + H * yTravel * t) / H` with `pos.y / H` in [0, 1], so once
/// `|yTravel * t| > 1` no sample can land inside the texture. Keep in sync with distortion.frag.
bool _isFullyWarpedAway(double t, double yTravel) => (yTravel * t).abs() > 1.0;
