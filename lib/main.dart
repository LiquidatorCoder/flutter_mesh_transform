import 'package:flutter/material.dart';

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

class MeshTransformView extends StatelessWidget {
  const MeshTransformView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundBlue,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
      ),
    );
  }
}
