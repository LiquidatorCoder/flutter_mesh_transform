import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_mesh_transform/flutter_mesh_transform.dart';

void main() => runApp(const MeshTransformApp());

class WarpSettings {
  const WarpSettings({
    this.xSpread = 2.1,
    this.yFalloff = 3.0,
    this.yTravel = 1.1,
    this.response = 0.85,
    this.dampingRatio = 0.75,
  });

  final double xSpread;
  final double yFalloff;
  final double yTravel;
  final double response;
  final double dampingRatio;

  WarpSettings copyWith({double? xSpread, double? yFalloff, double? yTravel, double? response, double? dampingRatio}) =>
      WarpSettings(
        xSpread: xSpread ?? this.xSpread,
        yFalloff: yFalloff ?? this.yFalloff,
        yTravel: yTravel ?? this.yTravel,
        response: response ?? this.response,
        dampingRatio: dampingRatio ?? this.dampingRatio,
      );
}

class MeshTransformApp extends StatelessWidget {
  const MeshTransformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const _MeshTransformHome(),
    );
  }
}

class _MeshTransformHome extends StatefulWidget {
  const _MeshTransformHome();

  @override
  State<_MeshTransformHome> createState() => _MeshTransformHomeState();
}

class _MeshTransformHomeState extends State<_MeshTransformHome> {
  WarpSettings _settings = const WarpSettings();
  final ValueNotifier<int> _replay = ValueNotifier<int>(0);

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _CardDemo(settings: _settings, replay: _replay),
            _PaymentDemo(settings: _settings, replay: _replay),
            _GridDemo(settings: _settings, replay: _replay),
          ],
        ),
        floatingActionButton: FloatingActionButton(onPressed: _openControls, child: const Icon(Icons.tune)),
        bottomNavigationBar: Material(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: TabBar(
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.6),
              dividerColor: Colors.transparent,
              indicatorColor: scheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'card'),
                Tab(text: 'pay'),
                Tab(text: 'grid'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openControls() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void apply(WarpSettings next) {
              setSheetState(() => _settings = next);
              setState(() => _settings = next);
            }

            return _ControlsSheet(
              settings: _settings,
              onChanged: apply,
              onReplay: () => _replay.value++,
              onReset: () => apply(const WarpSettings()),
            );
          },
        );
      },
    );
  }
}

class _ControlsSheet extends StatelessWidget {
  const _ControlsSheet({
    required this.settings,
    required this.onChanged,
    required this.onReplay,
    required this.onReset,
  });

  final WarpSettings settings;
  final ValueChanged<WarpSettings> onChanged;
  final VoidCallback onReplay;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('replay'),
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay),
                  label: const Text('replay'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('reset'),
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('reset'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'warp shape',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white70),
          ),
          _slider('x-spread', settings.xSpread, 0, 3, (v) => onChanged(settings.copyWith(xSpread: v))),
          _slider('y-falloff', settings.yFalloff, 0.1, 4, (v) => onChanged(settings.copyWith(yFalloff: v))),
          _slider('y-travel', settings.yTravel, 0, 3, (v) => onChanged(settings.copyWith(yTravel: v))),
          const SizedBox(height: 4),
          const Text(
            'warp feel',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white70),
          ),
          _slider('response', settings.response, 0.1, 2, (v) => onChanged(settings.copyWith(response: v))),
          _slider('damping', settings.dampingRatio, 0.1, 1.5, (v) => onChanged(settings.copyWith(dampingRatio: v))),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ),
        Expanded(
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontSize: 11, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ─── Tab 1: card ──────────────────────────────────────────────────────

class _CardDemo extends StatefulWidget {
  const _CardDemo({required this.settings, required this.replay});
  final WarpSettings settings;
  final ValueNotifier<int> replay;

  @override
  State<_CardDemo> createState() => _CardDemoState();
}

class _CardDemoState extends State<_CardDemo> {
  bool _active = false;
  Timer? _replayTimer;

  @override
  void initState() {
    super.initState();
    widget.replay.addListener(_play);
  }

  @override
  void didUpdateWidget(covariant _CardDemo old) {
    super.didUpdateWidget(old);
    if (old.replay != widget.replay) {
      old.replay.removeListener(_play);
      widget.replay.addListener(_play);
    }
  }

  @override
  void dispose() {
    widget.replay.removeListener(_play);
    _replayTimer?.cancel();
    super.dispose();
  }

  void _play() {
    _replayTimer?.cancel();
    final original = _active;
    setState(() => _active = !original);
    _replayTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _active = original);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _replayTimer?.cancel();
        setState(() => _active = !_active);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: MeshTransform(
          active: _active,
          xSpread: s.xSpread,
          yFalloff: s.yFalloff,
          yTravel: s.yTravel,
          response: s.response,
          dampingRatio: s.dampingRatio,
          padding: const EdgeInsets.fromLTRB(24, 160, 24, 40),
          child: AspectRatio(aspectRatio: 1356 / 1943, child: const _MeshCard()),
        ),
      ),
    );
  }
}

class _MeshCard extends StatelessWidget {
  const _MeshCard();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.onPrimary,
                  child: CustomPaint(painter: _CardArtPainter()),
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Abhay Maurya',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'MESH TRANSFORM',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _CardArtPainter extends CustomPainter {
  const _CardArtPainter();

  // Triangles in normalized [0..1] coords, painted in order with given alpha.
  static const _tris = <(double, double, double, double, double, double, double)>[
    // (x1,y1,x2,y2,x3,y3, alpha)
    (0.00, 0.00, 0.55, 0.95, 0.32, 0.00, 0.25),
    (1.00, 0.00, 0.45, 1.00, 0.70, 0.00, 0.22),
    (0.00, 0.55, 0.62, 1.00, 0.00, 1.00, 0.18),
    (1.00, 0.45, 1.00, 1.00, 0.55, 1.00, 0.20),
    (0.20, 0.40, 0.80, 0.45, 0.50, 0.80, 0.30),
    (0.00, 0.05, 0.25, 0.55, 0.05, 0.65, 0.18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final t in _tris) {
      final path = Path()
        ..moveTo(t.$1 * w, t.$2 * h)
        ..lineTo(t.$3 * w, t.$4 * h)
        ..lineTo(t.$5 * w, t.$6 * h)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: t.$7));
    }
  }

  @override
  bool shouldRepaint(covariant _CardArtPainter old) => false;
}

// ─── Tab 2: payment send ──────────────────────────────────────────────

class _PaymentDemo extends StatefulWidget {
  const _PaymentDemo({required this.settings, required this.replay});
  final WarpSettings settings;
  final ValueNotifier<int> replay;

  @override
  State<_PaymentDemo> createState() => _PaymentDemoState();
}

class _PaymentDemoState extends State<_PaymentDemo> with SingleTickerProviderStateMixin {
  bool _sent = false;
  bool _streaksReverse = false;
  late final AnimationController _streaks;
  late final List<_Streak> _streakSeeds;
  Timer? _pending;
  Timer? _replayTimer;

  static const _cashGreen = Color(0xFFB5F265);

  @override
  void initState() {
    super.initState();
    _streaks = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _streakSeeds = List.generate(18, (i) => _Streak.seed(i));
    widget.replay.addListener(_play);
  }

  @override
  void didUpdateWidget(covariant _PaymentDemo old) {
    super.didUpdateWidget(old);
    if (old.replay != widget.replay) {
      old.replay.removeListener(_play);
      widget.replay.addListener(_play);
    }
  }

  @override
  void dispose() {
    widget.replay.removeListener(_play);
    _pending?.cancel();
    _replayTimer?.cancel();
    _streaks.dispose();
    super.dispose();
  }

  void _toggle() {
    // Ignore taps while a transition is pending: a double tap acts as one tap.
    if (_pending?.isActive ?? false) return;
    _streaksReverse = _sent; // tapping while sent → card returns, streaks fall
    _streaks.forward(from: 0);
    final delay = _streaks.duration! * 0.6;
    _pending = Timer(delay, () {
      if (!mounted) return;
      setState(() => _sent = !_sent);
    });
  }

  // One full out-and-back cycle from the current state.
  void _play() {
    // Ignore while a transition or a replay cycle is in flight (same as the tap debounce).
    if ((_pending?.isActive ?? false) || (_replayTimer?.isActive ?? false)) return;
    _toggle();
    _replayTimer = Timer(_streaks.duration! * 0.6 + const Duration(milliseconds: 900), _toggle);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _streaks,
                  builder: (context, _) => CustomPaint(
                    painter: _StreakPainter(
                      t: _streaks.value,
                      seeds: _streakSeeds,
                      color: _cashGreen,
                      reverse: _streaksReverse,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: MeshTransform(
                active: _sent,
                xSpread: s.xSpread,
                yFalloff: s.yFalloff,
                yTravel: s.yTravel,
                response: s.response,
                dampingRatio: s.dampingRatio,
                padding: const EdgeInsets.fromLTRB(32, 220, 32, 80),
                child: Container(
                  width: 280,
                  height: 320,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                  decoration: BoxDecoration(color: _cashGreen, borderRadius: BorderRadius.circular(28)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x11000000), Color(0x22000000)],
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'K',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 22),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Kristen Anderson',
                            style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Text(
                        '\$889',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 68,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Background streak particles for the payment-send animation.
class _Streak {
  _Streak.seed(int i)
    : xFraction = ((i * 37 + 11) % 100) / 100,
      speed = 0.6 + ((i * 53) % 100) / 100 * 0.8,
      length = 24.0 + ((i * 17) % 80),
      startDelay = ((i * 13) % 100) / 100 * 0.35,
      thickness = 1.2 + ((i * 7) % 10) / 10;

  final double xFraction;
  final double speed;
  final double length;
  final double startDelay;
  final double thickness;
}

class _StreakPainter extends CustomPainter {
  _StreakPainter({required this.t, required this.seeds, required this.color, this.reverse = false});
  final double t;
  final List<_Streak> seeds;
  final Color color;
  final bool reverse;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    for (final s in seeds) {
      final local = (t - s.startDelay) / (1.0 - s.startDelay);
      if (local <= 0 || local >= 1) continue;

      final travel = size.height + s.length + 80;
      final x = s.xFraction * size.width;
      // Forward: streak head moves bottom → top. Reverse: top → bottom.
      // The streak's gradient always trails behind the head (head bright, tail fades).
      final double headY;
      final double tailY;
      if (reverse) {
        headY = -s.length + local * travel * s.speed;
        tailY = headY - s.length; // tail above the head as it descends
      } else {
        headY = size.height + s.length - local * travel * s.speed;
        tailY = headY + s.length; // tail below the head as it rises
      }

      double alpha;
      if (local < 0.1) {
        alpha = local / 0.2;
      } else if (local > 0.7) {
        alpha = (1 - local) / 0.3;
      } else {
        alpha = 1.0;
      }
      alpha = alpha.clamp(0.0, 1.0) * 0.55;

      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s.thickness
        ..shader = ui.Gradient.linear(Offset(x, headY), Offset(x, tailY), [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ]);
      canvas.drawLine(Offset(x, headY), Offset(x, tailY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StreakPainter old) => old.t != t || old.reverse != reverse;
}

// ─── Tab 3: grid of independent instances ─────────────────────────────

class _GridDemo extends StatefulWidget {
  const _GridDemo({required this.settings, required this.replay});
  final WarpSettings settings;
  final ValueNotifier<int> replay;

  @override
  State<_GridDemo> createState() => _GridDemoState();
}

class _GridDemoState extends State<_GridDemo> {
  final Set<int> _active = {};
  final List<Timer> _timers = [];

  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  static const _stagger = Duration(milliseconds: 200);
  static const _hold = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    widget.replay.addListener(_playStagger);
  }

  @override
  void didUpdateWidget(covariant _GridDemo old) {
    super.didUpdateWidget(old);
    if (old.replay != widget.replay) {
      old.replay.removeListener(_playStagger);
      widget.replay.addListener(_playStagger);
    }
  }

  @override
  void dispose() {
    widget.replay.removeListener(_playStagger);
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _playStagger() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    setState(_active.clear);

    for (var i = 0; i < _colors.length; i++) {
      final idx = i;
      _timers.add(
        Timer(_stagger * i, () {
          if (!mounted) return;
          setState(() => _active.add(idx));
        }),
      );
      _timers.add(
        Timer(_stagger * i + _hold, () {
          if (!mounted) return;
          setState(() => _active.remove(idx));
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    const spacing = 24.0;
    const cols = 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            final tileH = tileW;

            return Stack(
              children: [
                for (var i = _colors.length - 1; i >= 0; i--)
                  Positioned(
                    left: (i % cols) * (tileW + spacing),
                    top: 0,
                    width: tileW,
                    height: (tileH + (i ~/ cols) * (tileH + spacing)) + MediaQuery.paddingOf(context).top + 16,
                    child: GestureDetector(
                      onTap: _playStagger,
                      child: MeshTransform(
                        active: _active.contains(i),
                        xSpread: s.xSpread,
                        yFalloff: s.yFalloff,
                        yTravel: s.yTravel,
                        response: s.response,
                        dampingRatio: s.dampingRatio,
                        padding: EdgeInsets.fromLTRB(
                          28,
                          ((i ~/ cols) * (tileH + spacing)) + MediaQuery.paddingOf(context).top + 16,
                          28,
                          28,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _colors[i],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _colors[i].withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
