import 'package:flutter/material.dart';

import 'package:flutter_mesh_transform/flutter_mesh_transform.dart';

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

class MeshTransformView extends StatefulWidget {
  const MeshTransformView({super.key});

  @override
  State<MeshTransformView> createState() => _MeshTransformViewState();
}

class _MeshTransformViewState extends State<MeshTransformView> {
  bool _active = true;

  // Warp shape
  double _xSpread = 2.1;
  double _yFalloff = 3.0;
  double _yTravel = 1.1;

  // Warp feel (spring)
  double _response = 0.85;
  double _dampingRatio = 0.75;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundBlue,
      body: _buildAnimation(),
      floatingActionButton: FloatingActionButton(onPressed: _openControls, child: const Icon(Icons.tune)),
    );
  }

  void _openControls() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void update(VoidCallback fn) {
              setSheetState(fn);
              setState(fn);
            }

            return _buildControls(update);
          },
        );
      },
    );
  }

  Widget _buildAnimation() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _active = !_active),
      child: Center(
        child: AspectRatio(
          aspectRatio: (1356 / 1943),
          child: MeshTransform(
            active: _active,
            xSpread: _xSpread,
            yFalloff: _yFalloff,
            yTravel: _yTravel,
            response: _response,
            dampingRatio: _dampingRatio,
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
      ),
    );
  }

  Widget _buildControls(void Function(VoidCallback) update) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('warp shape', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          _slider('x-spread', _xSpread, 0, 3, (v) => update(() => _xSpread = v)),
          _slider('y-falloff', _yFalloff, 0.1, 4, (v) => update(() => _yFalloff = v)),
          _slider('y-travel', _yTravel, 0, 3, (v) => update(() => _yTravel = v)),
          const SizedBox(height: 4),
          const Text('warp feel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          _slider('response', _response, 0.1, 2, (v) => update(() => _response = v)),
          _slider('damping', _dampingRatio, 0.1, 1.5, (v) => update(() => _dampingRatio = v)),
        ],
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
