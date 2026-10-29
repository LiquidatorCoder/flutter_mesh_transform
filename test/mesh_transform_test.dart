import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mesh_transform/flutter_mesh_transform.dart';

void main() {
  testWidgets('MeshTransform renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MeshTransform(active: false, child: Text('hello'))),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('MeshTransform accepts active toggling without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MeshTransform(active: false, child: Text('x'))),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MeshTransform(active: true, child: Text('x'))),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('x'), findsOneWidget);
  });

  _runtimeTests();
}

class _CountingChild extends StatefulWidget {
  const _CountingChild({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_CountingChild> createState() => _CountingChildState();
}

class _CountingChildState extends State<_CountingChild> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 100, height: 100);
}

Widget _host({required bool active, required Widget child, double maxBlur = 20.0}) {
  return MaterialApp(
    home: Scaffold(
      body: MeshTransform(active: active, maxBlur: maxBlur, child: child),
    ),
  );
}

Finder _inMesh(Type type) => find.descendant(of: find.byType(MeshTransform), matching: find.byType(type));

bool _hasImageFilterLayer(Layer? layer) {
  if (layer is ImageFilterLayer) return true;
  if (layer is ContainerLayer) {
    Layer? child = layer.firstChild;
    while (child != null) {
      if (_hasImageFilterLayer(child)) return true;
      child = child.nextSibling;
    }
  }
  return false;
}

void _runtimeTests() {
  testWidgets('child State survives a full on/off cycle', (tester) async {
    var inits = 0;
    final child = _CountingChild(onInit: () => inits++);
    await tester.pumpWidget(_host(active: false, child: child));
    await tester.pumpWidget(_host(active: true, child: child));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(active: false, child: child));
    await tester.pumpAndSettle();

    expect(inits, 1);
  });

  testWidgets('at rest after a full cycle the blur is disabled and no filter layer exists', (tester) async {
    await tester.pumpWidget(_host(active: false, child: const Text('x')));
    await tester.pumpWidget(_host(active: true, child: const Text('x')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(active: false, child: const Text('x')));
    await tester.pumpAndSettle();

    expect(tester.widget<ImageFiltered>(_inMesh(ImageFiltered)).enabled, isFalse);
    expect(_hasImageFilterLayer(tester.binding.renderViews.first.debugLayer), isFalse);
  });

  testWidgets('blur is enabled mid-animation', (tester) async {
    await tester.pumpWidget(_host(active: false, child: const Text('x')));
    await tester.pumpWidget(_host(active: true, child: const Text('x')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.widget<ImageFiltered>(_inMesh(ImageFiltered)).enabled, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('maxBlur 0 never enables blur', (tester) async {
    await tester.pumpWidget(_host(active: false, maxBlur: 0, child: const Text('x')));
    await tester.pumpWidget(_host(active: true, maxBlur: 0, child: const Text('x')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<ImageFiltered>(_inMesh(ImageFiltered)).enabled, isFalse);
    }
    await tester.pumpAndSettle();
  });

  // The fully-warped "paint nothing" shortcut needs the shader, which never loads under flutter_test; the e2e suite in
  // example/integration_test covers it on a device. Without a shader the blurred child must stay visible.
  testWidgets('without a shader a fully warped child stays painted and receives taps', (tester) async {
    var taps = 0;
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => taps++,
      child: const SizedBox(key: Key('target'), width: 100, height: 100),
    );
    await tester.pumpWidget(_host(active: false, child: child));
    await tester.pumpWidget(_host(active: true, child: child));
    await tester.pumpAndSettle();

    expect(tester.widget<Opacity>(_inMesh(Opacity)).opacity, 1);
    await tester.tap(find.byKey(const Key('target')), warnIfMissed: false);
    expect(taps, 1);
  });
}
