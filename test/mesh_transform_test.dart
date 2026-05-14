import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mesh_transform/flutter_mesh_transform.dart';

void main() {
  testWidgets('MeshTransform renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MeshTransform(
            active: false,
            child: Text('hello'),
          ),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('MeshTransform accepts active toggling without throwing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MeshTransform(active: false, child: Text('x')),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MeshTransform(active: true, child: Text('x')),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('x'), findsOneWidget);
  });
}
