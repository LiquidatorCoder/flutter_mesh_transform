import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

void main() => runApp(const MeshTransformApp());

class MeshTransformApp extends StatelessWidget {
  const MeshTransformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MeshTransformView(),
    );
  }
}

// SwiftUI: Color(hue: 0.63, saturation: 0.071, brightness: 0.94)
const _backgroundBlue = Color.fromARGB(255, 222, 226, 240);
// SwiftUI: Color(hue: 0.635, saturation: 0.674, brightness: 0.614)
const _shadowBlue = Color.fromARGB(255, 51, 71, 157);

// Wave SpringAnimator(dampingRatio: 0.75, response: 0.8)
final _spring = SpringDescription(
  mass: 1,
  stiffness: 61.685, // (2π / 0.8)^2
  damping: 11.78, // 2 * 0.75 * sqrt(61.685)
);

class MeshTransformView extends StatefulWidget {
  const MeshTransformView({super.key});

  @override
  State<MeshTransformView> createState() => _MeshTransformViewState();
}

class _MeshTransformViewState extends State<MeshTransformView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _target = 1;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0);
    _animateTo(_target);
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset('shaders/distortion.frag');
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  void _animateTo(double target) {
    final sim = SpringSimulation(_spring, _controller.value, target, 0);
    _controller.animateWith(sim);
  }

  void _toggle() {
    _target = _target == 0 ? 1 : 0;
    _animateTo(_target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mirror of SwiftUI ContentView:
    //   Image -> clip -> shadow -> padding(24) -> distortionEffect -> blur
    // In Flutter that maps to:
    //   ImageFiltered(blur, AnimatedSampler(shader, Padding(card with shadow+clip)))
    // The sampler's child fills the screen so the warp's "boundingRect" is the
    // screen, the shadow has room, and content can slide off-bottom.
    return Scaffold(
      backgroundColor: _backgroundBlue,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Swift uses unclamped spring value — overshoot drives blur past
            // its nominal max. Only clamp the floor so sigma stays >= 0.
            final blur = (_controller.value * 20.0).clamp(0.0, double.infinity);
            final shader = _shader;

            final padded = Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _shadowBlue.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset('assets/card.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            );

            Widget content = SizedBox.expand(child: padded);

            if (shader != null) {
              content = AnimatedSampler(
                (image, size, canvas) {
                  shader
                    ..setFloat(0, size.width)
                    ..setFloat(1, size.height)
                    ..setFloat(2, _controller.value)
                    ..setImageSampler(0, image);
                  canvas.drawRect(
                    Offset.zero & size,
                    Paint()..shader = shader,
                  );
                },
                child: SizedBox.expand(child: padded),
              );
            }

            return ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            );
          },
        ),
      ),
    );
  }
}
