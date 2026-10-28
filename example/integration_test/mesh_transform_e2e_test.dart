// End-to-end and performance checks for the example app, run on a real
// device or simulator:
//
//   cd example
//   flutter drive -d <device> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/mesh_transform_e2e_test.dart
//
// Every scenario records frame timings, tap-to-first-frame latency and settle
// time into the driver's response data (build/e2e/e2e_perf.json). Numbers from
// a debug build on a simulator are only comparable with each other, not with a
// profile build on hardware.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_mesh_transform/flutter_mesh_transform.dart';
import 'package:flutter_mesh_transform_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _shaderAsset = 'packages/flutter_mesh_transform/shaders/distortion.frag';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final report = binding.reportData ??= <String, dynamic>{};

  /// Runs [action] (which must start with the tap that triggers an animation)
  /// and records frame timings, tap-to-first-frame latency and the time until
  /// no more frames are scheduled.
  Future<void> measure(
    WidgetTester tester,
    String key,
    Future<void> Function() tap, {
    Duration settleAtLeast = Duration.zero,
  }) async {
    // FrameTimings are batched by the engine; let any earlier ones flush.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final timings = <ui.FrameTiming>[];
    void onTimings(List<ui.FrameTiming> t) => timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(onTimings);

    final clock = Stopwatch()..start();
    await tap();
    await SchedulerBinding.instance.endOfFrame;
    final firstFrameMs = clock.elapsedMicroseconds / 1000;
    if (settleAtLeast > Duration.zero) {
      await Future<void>.delayed(settleAtLeast);
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    final settleMs = clock.elapsedMicroseconds / 1000;

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    SchedulerBinding.instance.removeTimingsCallback(onTimings);

    final summary = timings.isEmpty ? <String, dynamic>{'frame_count': 0} : FrameTimingSummarizer(timings).summary;
    final frames = summary['frame_count'] as int;
    report[key] = <String, dynamic>{
      'tap_to_first_frame_ms': firstFrameMs,
      'tap_to_settled_ms': settleMs,
      'frame_count': frames,
      for (final k in const [
        'average_frame_build_time_millis',
        '90th_percentile_frame_build_time_millis',
        'worst_frame_build_time_millis',
        'average_frame_rasterizer_time_millis',
        '90th_percentile_frame_rasterizer_time_millis',
        '99th_percentile_frame_rasterizer_time_millis',
        'worst_frame_rasterizer_time_millis',
        'missed_frame_build_budget_count',
        'missed_frame_rasterizer_budget_count',
      ])
        if (summary.containsKey(k)) k: summary[k],
    };
    debugPrint('E2E_PERF $key ${report[key]}');
  }

  /// Records frame timings for a fixed window, for scenes that never settle.
  Future<void> measureFor(String key, Duration window) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final timings = <ui.FrameTiming>[];
    void onTimings(List<ui.FrameTiming> t) => timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    await Future<void>.delayed(window);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    final summary = FrameTimingSummarizer(timings).summary;
    report[key] = {
      for (final k in const [
        'frame_count',
        'average_frame_build_time_millis',
        'average_frame_rasterizer_time_millis',
        '90th_percentile_frame_rasterizer_time_millis',
        '99th_percentile_frame_rasterizer_time_millis',
        'worst_frame_rasterizer_time_millis',
        'missed_frame_rasterizer_budget_count',
      ])
        k: summary[k],
    };
    debugPrint('E2E_PERF $key ${report[key]}');
  }

  /// Layers that cost an offscreen pass: the shader sampler and image filters.
  List<String> offscreenLayers() {
    final found = <String>[];
    void visit(Layer? layer) {
      if (layer == null) return;
      final name = layer.runtimeType.toString();
      if (layer is ImageFilterLayer || name.contains('ShaderSampler')) {
        found.add(name);
      }
      if (layer is ContainerLayer) {
        for (var child = layer.firstChild; child != null; child = child.nextSibling) {
          visit(child);
        }
      }
    }

    for (final view in RendererBinding.instance.renderViews) {
      visit(view.debugLayer);
    }
    return found;
  }

  MeshTransform meshAround(WidgetTester tester, Finder content) =>
      tester.widget<MeshTransform>(find.ancestor(of: content, matching: find.byType(MeshTransform)).first);

  testWidgets('shader loads on device', (tester) async {
    final clock = Stopwatch()..start();
    final program = await ui.FragmentProgram.fromAsset(_shaderAsset);
    report['shader_cold_load_ms'] = clock.elapsedMicroseconds / 1000;
    program.fragmentShader().dispose();
    debugPrint('E2E_PERF shader_cold_load_ms ${report['shader_cold_load_ms']}');
  });

  testWidgets('card: warps away, returns, and rests without offscreen passes', (tester) async {
    await tester.pumpWidget(const MeshTransformApp());
    await tester.pumpAndSettle();
    final card = find.text('Abhay Maurya');
    expect(card, findsOneWidget);
    report['card_rest_layers_initial'] = offscreenLayers();

    await measure(tester, 'card_send', () => tester.tap(card));
    expect(meshAround(tester, card).active, isTrue);
    final warpedLayers = offscreenLayers();
    report['card_warped_layers'] = warpedLayers;
    expect(warpedLayers, isEmpty, reason: 'a card warped fully out of bounds should not render offscreen');

    await measure(tester, 'card_return', () => tester.tap(card, warnIfMissed: false));
    expect(meshAround(tester, card).active, isFalse);

    final layers = offscreenLayers();
    report['card_rest_layers_after_cycle'] = layers;
    expect(layers, isEmpty, reason: 'a resting MeshTransform should paint its child directly');
  });

  testWidgets('pay: send and return', (tester) async {
    await tester.pumpWidget(const MeshTransformApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('pay'));
    await tester.pumpAndSettle();
    final amount = find.text('\$889');

    await measure(tester, 'pay_send', () => tester.tap(amount), settleAtLeast: const Duration(milliseconds: 1300));
    expect(meshAround(tester, amount).active, isTrue);

    await measure(
      tester,
      'pay_return',
      () => tester.tap(amount, warnIfMissed: false),
      settleAtLeast: const Duration(milliseconds: 1300),
    );
    expect(meshAround(tester, amount).active, isFalse);
  });

  testWidgets('grid: staggered warp across six instances', (tester) async {
    await tester.pumpWidget(const MeshTransformApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('grid'));
    await tester.pumpAndSettle();
    expect(find.byType(MeshTransform), findsNWidgets(6));

    await measure(
      tester,
      'grid_stagger',
      () => tester.tap(find.text('1')),
      settleAtLeast: const Duration(milliseconds: 2400),
    );
    for (final m in tester.widgetList<MeshTransform>(find.byType(MeshTransform))) {
      expect(m.active, isFalse);
    }
  });

  testWidgets('controls: every slider drives the live widget', (tester) async {
    await tester.pumpWidget(const MeshTransformApp());
    await tester.pumpAndSettle();
    final before = meshAround(tester, find.text('Abhay Maurya'));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      await tester.drag(sliders.at(i), const Offset(-40, 0));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final after = meshAround(tester, find.text('Abhay Maurya'));
    expect(after.xSpread, isNot(before.xSpread));
    expect(after.yFalloff, isNot(before.yFalloff));
    expect(after.yTravel, isNot(before.yTravel));
    expect(after.response, isNot(before.response));
    expect(after.dampingRatio, isNot(before.dampingRatio));
  });

  testWidgets('scroll: a list of resting instances costs no offscreen passes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          itemCount: 40,
          itemBuilder: (context, i) => MeshTransform(
            active: false,
            padding: const EdgeInsets.all(8),
            child: Container(
              height: 120,
              color: Colors.primaries[i % Colors.primaries.length],
              alignment: Alignment.center,
              child: Text('row $i'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await measure(
      tester,
      'scroll_resting_list',
      () => tester.fling(find.byType(ListView), const Offset(0, -3000), 4000),
    );
  });

  testWidgets('resting instances with an animating child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GridView.count(
            crossAxisCount: 2,
            children: [
              for (var i = 0; i < 6; i++)
                MeshTransform(
                  active: false,
                  padding: const EdgeInsets.all(12),
                  child: ColoredBox(
                    color: Colors.primaries[i],
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    report['animating_child_rest_layers'] = offscreenLayers().length;
    await measureFor('animating_child_at_rest', const Duration(seconds: 3));
  });

  testWidgets('a fully warped child is not painted but still receives taps', (tester) async {
    var taps = 0;
    Widget app(bool active) => MaterialApp(
      home: Center(
        child: MeshTransform(
          active: active,
          child: GestureDetector(
            onTap: () => taps++,
            child: const SizedBox(
              key: Key('target'),
              width: 200,
              height: 200,
              child: ColoredBox(color: Colors.teal),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Opacity>(find.descendant(of: find.byType(MeshTransform), matching: find.byType(Opacity))).opacity,
      0,
    );
    expect(offscreenLayers(), isEmpty);
    await tester.tap(find.byKey(const Key('target')), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('a shaderAsset that fails to load falls back to the plain child', (tester) async {
    Widget app(String asset) => MaterialApp(
      home: Center(
        child: MeshTransform(
          active: true,
          shaderAsset: asset,
          child: const SizedBox(width: 200, height: 200, child: ColoredBox(color: Colors.teal)),
        ),
      ),
    );
    Opacity opacity() =>
        tester.widget<Opacity>(find.descendant(of: find.byType(MeshTransform), matching: find.byType(Opacity)));

    await tester.pumpWidget(app(_shaderAsset));
    await tester.pumpAndSettle();
    expect(opacity().opacity, 0, reason: 'with the real shader a fully warped child is hidden');

    await tester.pumpWidget(app('packages/flutter_mesh_transform/shaders/missing.frag'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(opacity().opacity, 1, reason: 'the previous shader must not outlive a failed replacement');
    expect(offscreenLayers().where((l) => l.contains('ShaderSampler')), isEmpty);
  });

  testWidgets('child state survives a full warp cycle with the shader loaded', (tester) async {
    var inits = 0;
    Widget app(bool active) => MaterialApp(
      home: Center(
        child: MeshTransform(
          active: active,
          child: _InitCounter(onInit: () => inits++),
        ),
      ),
    );

    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    report['child_init_count_after_cycle'] = inits;
    expect(inits, 1, reason: 'toggling the warp must not rebuild the child from scratch');
  });
}

class _InitCounter extends StatefulWidget {
  const _InitCounter({required this.onInit});
  final VoidCallback onInit;

  @override
  State<_InitCounter> createState() => _InitCounterState();
}

class _InitCounterState extends State<_InitCounter> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 200, height: 200, child: ColoredBox(color: Colors.teal));
}
