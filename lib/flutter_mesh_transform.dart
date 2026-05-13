import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

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

  final bool active;
  final Widget child;

  final double xSpread;
  final double yFalloff;
  final double yTravel;

  final double response;
  final double dampingRatio;

  final double maxBlur;

  /// Empty space around the child captured by the shader so the warp can
  /// extend past the child's bounds without clipping.
  final EdgeInsets padding;

  final String shaderAsset;

  @override
  State<MeshTransform> createState() => _MeshTransformState();
}

class _MeshTransformState extends State<MeshTransform> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.FragmentShader? _shader;

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
    } else if (widget.shaderAsset != oldWidget.shaderAsset) {
      _loadShader();
    }
  }

  Future<void> _loadShader() async {
    final program = await _programCache.putIfAbsent(
      widget.shaderAsset,
      () => ui.FragmentProgram.fromAsset(widget.shaderAsset),
    );
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  void _animateTo(double target) {
    final stiffness = math.pow(2 * math.pi / widget.response, 2).toDouble();
    final damping = 4 * math.pi * widget.dampingRatio / widget.response;
    final spring = SpringDescription(mass: 1, stiffness: stiffness, damping: damping);
    _controller.animateWith(SpringSimulation(spring, _controller.value, target, _controller.velocity));
  }

  @override
  void dispose() {
    _controller.dispose();
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

        Widget content = child!;

        if (shader != null) {
          content = AnimatedSampler((image, size, canvas) {
            shader
              ..setFloat(0, size.width)
              ..setFloat(1, size.height)
              ..setFloat(2, t)
              ..setFloat(3, widget.xSpread)
              ..setFloat(4, widget.yFalloff)
              ..setFloat(5, widget.yTravel)
              ..setImageSampler(0, image);
            canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
          }, child: content);
        }

        if (widget.maxBlur > 0) {
          final blur = (t * widget.maxBlur).clamp(0.0, double.infinity);
          if (blur > 0) {
            content = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            );
          }
        }

        return content;
      },
    );
  }
}
