import 'package:flutter/material.dart';
import 'package:flutter_mesh_transform/flutter_mesh_transform.dart';

void main() => runApp(const MeshTransformApp());

const _backgroundDark = Color(0xFF0E1116);
const _surfaceDark = Color(0xFF1C1F26);
const _accentBlue = Color(0xFF7C8CFF);
// kept for the card-demo drop shadow tint
const _shadowBlue = Color.fromARGB(255, 51, 71, 157);

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
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _backgroundDark,
        colorScheme: const ColorScheme.dark(surface: _surfaceDark, primary: _accentBlue, secondary: _accentBlue),
        useMaterial3: true,
      ),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _backgroundDark,
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _CardDemo(settings: _settings),
            _PaymentDemo(settings: _settings),
            _GridDemo(settings: _settings),
          ],
        ),
        floatingActionButton: FloatingActionButton(onPressed: _openControls, child: const Icon(Icons.tune)),
        bottomNavigationBar: Material(
          color: Colors.transparent,
          child: TabBar(
            labelColor: _accentBlue,
            unselectedLabelColor: Colors.white12,
            dividerColor: Colors.transparent,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: 'card', icon: Icon(Icons.image_outlined)),
              Tab(text: 'pay', icon: Icon(Icons.send_outlined)),
              Tab(text: 'grid', icon: Icon(Icons.grid_view_outlined)),
            ],
          ),
        ),
      ),
    );
  }

  void _openControls() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void apply(WarpSettings next) {
              setSheetState(() => _settings = next);
              setState(() => _settings = next);
            }

            return _ControlsSheet(settings: _settings, onChanged: apply);
          },
        );
      },
    );
  }
}

class _ControlsSheet extends StatelessWidget {
  const _ControlsSheet({required this.settings, required this.onChanged});

  final WarpSettings settings;
  final ValueChanged<WarpSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
  const _CardDemo({required this.settings});
  final WarpSettings settings;

  @override
  State<_CardDemo> createState() => _CardDemoState();
}

class _CardDemoState extends State<_CardDemo> {
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _active = !_active),
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
          child: AspectRatio(
            aspectRatio: 1356 / 1943,
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
}

// ─── Tab 2: payment send ──────────────────────────────────────────────

class _PaymentDemo extends StatefulWidget {
  const _PaymentDemo({required this.settings});
  final WarpSettings settings;

  @override
  State<_PaymentDemo> createState() => _PaymentDemoState();
}

class _PaymentDemoState extends State<_PaymentDemo> {
  bool _sent = false;

  static const _cashGreen = Color(0xFFB5F265);

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _sent = !_sent),
        child: Align(
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
      ),
    );
  }
}

// ─── Tab 3: grid of independent instances ─────────────────────────────

class _GridDemo extends StatefulWidget {
  const _GridDemo({required this.settings});
  final WarpSettings settings;

  @override
  State<_GridDemo> createState() => _GridDemoState();
}

class _GridDemoState extends State<_GridDemo> {
  final Set<int> _active = {};

  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: _colors.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
          ),
          itemBuilder: (context, i) {
            final isOn = _active.contains(i);
            return GestureDetector(
              onTap: () => setState(() {
                if (isOn) {
                  _active.remove(i);
                } else {
                  _active.add(i);
                }
              }),
              child: MeshTransform(
                active: isOn,
                xSpread: s.xSpread,
                yFalloff: s.yFalloff,
                yTravel: s.yTravel,
                response: s.response,
                dampingRatio: s.dampingRatio,
                padding: const EdgeInsets.all(28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _colors[i],
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: _colors[i].withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
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
            );
          },
        ),
      ),
    );
  }
}
