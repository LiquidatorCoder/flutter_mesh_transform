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
import 'dart:math' as math;
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

  testWidgets('pay: send and return, and a double tap toggles once', (tester) async {
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

    // A second tap while the send is still pending must not cancel it.
    await tester.tap(amount);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await tester.tap(amount, warnIfMissed: false);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    final afterDoubleTap = meshAround(tester, amount).active;
    report['pay_double_tap_sent'] = afterDoubleTap;
    expect(afterDoubleTap, isTrue, reason: 'a double tap should behave like one tap');
  });

  testWidgets('tab bar stays clear of the home indicator', (tester) async {
    await tester.pumpWidget(const MeshTransformApp());
    await tester.pumpAndSettle();
    final view = tester.view;
    final screenBottom = view.physicalSize.height / view.devicePixelRatio;
    final safeBottom = view.padding.bottom / view.devicePixelRatio;
    final tabBar = tester.getRect(find.byType(TabBar));
    report['tab_bar_bottom_gap'] = screenBottom - tabBar.bottom;
    expect(tabBar.bottom, lessThanOrEqualTo(screenBottom - safeBottom + 0.5));
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
    final view = tester.view;
    final visibleBottom = (view.physicalSize.height - view.padding.bottom) / view.devicePixelRatio;
    report['sheet_last_slider_bottom_gap'] = visibleBottom - tester.getRect(sliders.last).bottom;
    expect(tester.getRect(sliders.last).bottom, lessThanOrEqualTo(visibleBottom), reason: 'the sheet must not clip');
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

    // Replay runs the visible demo while the sheet stays open, and reset restores the defaults.
    await tester.tap(find.byKey(const Key('replay')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(meshAround(tester, find.text('Abhay Maurya')).active, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(meshAround(tester, find.text('Abhay Maurya')).active, isFalse);
    expect(find.byType(Slider), findsNWidgets(5), reason: 'replay must not close the sheet');

    await tester.tap(find.byKey(const Key('reset')));
    await tester.pumpAndSettle();
    final reset = meshAround(tester, find.text('Abhay Maurya'));
    expect(reset.xSpread, before.xSpread);
    expect(reset.yFalloff, before.yFalloff);
    expect(reset.yTravel, before.yTravel);
    expect(reset.response, before.response);
    expect(reset.dampingRatio, before.dampingRatio);
  });

  testWidgets('controls: replay from the warped state plays back and out again', (tester) async {
    await tester.pumpWidget(const MeshTransformApp());
    await tester.pumpAndSettle();
    final card = find.text('Abhay Maurya');
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(meshAround(tester, card).active, isTrue);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replay')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(meshAround(tester, card).active, isFalse, reason: 'replay starts by leaving the current state');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(meshAround(tester, card).active, isTrue, reason: 'replay ends back in the state it started from');
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

  // The Dart side writes the shader's uniforms by index only, so a reordered or swapped uniform compiles, passes every
  // structural check and silently draws the wrong warp. This renders a child whose colour encodes its own coordinates
  // (red = x / width, green = y / height) and checks that each output pixel sampled the position distortion.frag's
  // formula predicts for the values passed to MeshTransform.
  testWidgets('rendered pixels follow distortion.frag for the given parameters', (tester) async {
    const xSpread = 0.7, yFalloff = 2.0, yTravel = 0.25, size = 200.0;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundary,
            child: const MeshTransform(
              active: true,
              maxBlur: 0,
              padding: EdgeInsets.zero,
              xSpread: xSpread,
              yFalloff: yFalloff,
              yTravel: yTravel,
              child: SizedBox.square(
                dimension: size,
                child: CustomPaint(painter: _CoordinatePainter()),
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = (await image.toByteData())!;
    expect(image.width, size.toInt());

    var checked = 0;
    var worst = 0.0;
    for (var gy = 0; gy < 12; gy++) {
      for (var gx = 0; gx < 12; gx++) {
        final px = 8 + gx * 16, py = 8 + gy * 16;
        // distortion.frag at uProgress = 1, in the widget's own coordinates.
        final x = px + 0.5, y = py + 0.5;
        final nx = x / size, ny = y / size;
        var xOffset = (nx - 0.5) * 2 * xSpread;
        xOffset *= math.pow(math.max(1.0 - ny, 0.0), yFalloff);
        final u = (x + xOffset * size) / size, v = (y + size * yTravel) / size;

        final i = (py * image.width + px) * 4;
        final r = bytes.getUint8(i) / 255, g = bytes.getUint8(i + 1) / 255, a = bytes.getUint8(i + 3) / 255;
        if (u < -0.02 || u > 1.02 || v < -0.02 || v > 1.02) {
          expect(a, lessThan(0.05), reason: 'pixel ($px, $py) samples outside the child and must be transparent');
        } else if (u > 0.04 && u < 0.96 && v > 0.04 && v < 0.96) {
          worst = math.max(worst, math.max((r - u).abs(), (g - v).abs()));
          checked++;
        }
      }
    }
    report['shader_pixel_check'] = {'points': checked, 'worst_error': worst};
    debugPrint('E2E_PERF shader_pixel_check points=$checked worst=$worst');
    expect(checked, greaterThan(40));
    expect(worst, lessThan(0.04), reason: 'the warp does not match distortion.frag for these uniforms');
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

/// Paints red = x / width and green = y / height, so a pixel's colour says where in the child it came from.
class _CoordinatePainter extends CustomPainter {
  const _CoordinatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = const LinearGradient(colors: [Color(0xFF000000), Color(0xFFFF0000)]).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000000), Color(0xFF00FF00)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CoordinatePainter oldDelegate) => false;
}
