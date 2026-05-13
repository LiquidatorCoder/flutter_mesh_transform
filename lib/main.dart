import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

void main() => runApp(const MeshTransformApp());

class MeshTransformApp extends StatelessWidget {
  const MeshTransformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: MeshTransformView());
  }
}

// SwiftUI: Color(hue: 0.63, saturation: 0.071, brightness: 0.94)
const _backgroundBlue = Color.fromARGB(255, 222, 226, 240);
// SwiftUI: Color(hue: 0.635, saturation: 0.674, brightness: 0.614)
const _shadowBlue = Color.fromARGB(255, 51, 71, 157);

SpringDescription _springFrom({required double response, required double ratio}) {
  // Wave's spring: stiffness = (2π/response)², damping = 4π·ratio/response.
  final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
  final damping = 4 * math.pi * ratio / response;
  return SpringDescription(mass: 1, stiffness: stiffness, damping: damping);
}

class MeshTransformView extends StatefulWidget {
  const MeshTransformView({super.key});

  @override
  State<MeshTransformView> createState() => _MeshTransformViewState();
}

class _MeshTransformViewState extends State<MeshTransformView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _target = 1;
  ui.FragmentShader? _shader;

  // Warp shape
  double _xSpread = 2.1;
  double _yFalloff = 3.0;
  double _yTravel = 1.1;

  // Warp feel (spring)
  double _response = 0.85;
  double _dampingRatio = 0.75;

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
    final sim = SpringSimulation(_springFrom(response: _response, ratio: _dampingRatio), _controller.value, target, 0);
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
      body: Stack(
        children: [
          Positioned.fill(child: _buildAnimation()),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildControls()),
        ],
      ),
    );
  }

  Widget _buildAnimation() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
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
                      BoxShadow(color: _shadowBlue.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 8)),
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
            content = AnimatedSampler((image, size, canvas) {
              shader
                ..setFloat(0, size.width)
                ..setFloat(1, size.height)
                ..setFloat(2, _controller.value)
                ..setFloat(3, _xSpread)
                ..setFloat(4, _yFalloff)
                ..setFloat(5, _yTravel)
                ..setImageSampler(0, image);
              canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
            }, child: SizedBox.expand(child: padded));
          }

          return ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('warp shape', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            _slider('x-spread', _xSpread, 0, 3, (v) => setState(() => _xSpread = v)),
            _slider('y-falloff', _yFalloff, 0.1, 4, (v) => setState(() => _yFalloff = v)),
            _slider('y-travel', _yTravel, 0, 3, (v) => setState(() => _yTravel = v)),
            const SizedBox(height: 4),
            const Text('warp feel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            _slider('response', _response, 0.1, 2, (v) => setState(() => _response = v)),
            _slider('damping', _dampingRatio, 0.1, 1.5, (v) => setState(() => _dampingRatio = v)),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
