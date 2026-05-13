import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

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
// stiffness k = (2π/response)² ; damping c = 2·ζ·√k (with mass = 1)
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0);
    _animateTo(_target);
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
    return Scaffold(
      backgroundColor: _backgroundBlue,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value;
              final blur = progress.clamp(0.0, 1.0) * 8.0;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                    ),
                    // Placeholder transform until the shader lands.
                    child: Transform.translate(
                      offset: Offset(0, progress * 200),
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
                          child: Image.asset(
                            'assets/card.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
