import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/app_domain.dart';
import '../theme/app_theme.dart';

/// 3D domain picker: five station icons ride a translucent wireframe sphere.
/// Drag to rotate (with fling + snap), tap a front-facing icon to select.
class DomainSphereSelector extends StatefulWidget {
  const DomainSphereSelector({
    required this.selected,
    required this.onDomainSelected,
    this.onFrontDomainChanged,
    this.size = 300,
    super.key,
  });

  final AppDomainId selected;
  final ValueChanged<AppDomainId> onDomainSelected;
  final ValueChanged<AppDomainId>? onFrontDomainChanged;
  final double size;

  @override
  State<DomainSphereSelector> createState() => _DomainSphereSelectorState();
}

class _Projected {
  const _Projected({
    required this.domain,
    required this.position,
    required this.east,
    required this.north,
  });

  final DomainPolicy domain;
  final (double, double, double) position;
  final (double, double, double) east;
  final (double, double, double) north;

  double get x => position.$1;
  double get y => position.$2;
  double get z => position.$3;
}

const double _kPerspective = 0.22;

double _persp(double z) => 1 / (1 - z * _kPerspective);

String domainShortLine(AppDomainId id) => switch (id) {
  AppDomainId.marriage => 'Find a life partner',
  AppDomainId.jobs => 'Find work',
  AppDomainId.rooms => 'Find a room',
  AppDomainId.bikes => 'Rent a bike',
  AppDomainId.homeHelp => 'Get help at home',
};

/// Post / offer side — what the user can put up (not browse).
String domainPostLine(AppDomainId id, [AppLocalizations? l10n]) {
  final key = switch (id) {
    AppDomainId.marriage => 'postMarriage',
    AppDomainId.jobs => 'postJobs',
    AppDomainId.rooms => 'postRooms',
    AppDomainId.bikes => 'postBikes',
    AppDomainId.homeHelp => 'postHomeHelp',
  };
  if (l10n != null) return l10n.text(key);
  return const AppLocalizations(Locale('en')).text(key);
}

class _DomainSphereSelectorState extends State<DomainSphereSelector>
    with TickerProviderStateMixin {
  static const _dragFactor = 0.01;
  static const _idleYawSpeed = 0.18;
  static const _pitchLimit = 1.1;
  static const _snapSpeed = 3.2;
  static const _velocityFloor = 0.35;

  late final Ticker _ticker;
  late final AnimationController _enter;
  late final AnimationController _pulse;
  Duration _lastTick = Duration.zero;

  double _yaw = 0;
  double _pitch = -0.25;
  double _yawVelocity = 0;
  double _pitchVelocity = 0;
  bool _dragging = false;
  bool _allowSnap = false;
  AppDomainId? _lastFront;

  static const _icons = <AppDomainId, IconData>{
    AppDomainId.marriage: Icons.favorite,
    AppDomainId.jobs: Icons.work,
    AppDomainId.rooms: Icons.hotel,
    AppDomainId.bikes: Icons.pedal_bike,
    AppDomainId.homeHelp: Icons.cleaning_services,
  };

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.1 || _dragging) return;

    final speed = math.sqrt(
      _yawVelocity * _yawVelocity + _pitchVelocity * _pitchVelocity,
    );
    final damping = math.exp(-2.2 * dt);
    _yawVelocity *= damping;
    _pitchVelocity *= damping;

    setState(() {
      if (speed > _velocityFloor) {
        _yaw += (_yawVelocity + _idleYawSpeed) * dt;
        _pitch = (_pitch + _pitchVelocity * dt).clamp(
          -_pitchLimit,
          _pitchLimit,
        );
      } else if (_allowSnap) {
        _yawVelocity = 0;
        _pitchVelocity = 0;
        _snapTowardFront(dt);
        _yaw += _idleYawSpeed * dt * 0.35;
      } else {
        _yaw += (_yawVelocity + _idleYawSpeed) * dt;
        _pitch = (_pitch + _pitchVelocity * dt).clamp(
          -_pitchLimit,
          _pitchLimit,
        );
      }
    });
  }

  void _snapTowardFront(double dt) {
    final projected = _allProjected();
    if (projected.isEmpty) return;
    projected.sort((a, b) => a.z.compareTo(b.z));
    final front = projected.last;
    final x = front.x;
    final y = front.y;
    final z = front.z;
    final yawFix = math.atan2(x, z);
    final horiz = math.sqrt(x * x + z * z);
    final pitchFix = math.atan2(y, horiz <= 1e-6 ? 1e-6 : horiz);
    final t = math.min(1.0, _snapSpeed * dt);
    _yaw -= yawFix * t;
    _pitch = (_pitch - pitchFix * t).clamp(-_pitchLimit, _pitchLimit);
  }

  (double, double, double) _rotate(double x, double y, double z) {
    final cy = math.cos(_yaw);
    final sy = math.sin(_yaw);
    final x1 = x * cy + z * sy;
    final z1 = -x * sy + z * cy;

    final cp = math.cos(_pitch);
    final sp = math.sin(_pitch);
    final y2 = y * cp - z1 * sp;
    final z2 = y * sp + z1 * cp;
    return (x1, y2, z2);
  }

  _Projected _project(int index, int count, DomainPolicy domain) {
    final phi = math.acos(1 - 2 * (index + 0.5) / count);
    final theta = math.pi * (1 + math.sqrt(5)) * index;
    final x0 = math.sin(phi) * math.cos(theta);
    final y0 = math.cos(phi);
    final z0 = math.sin(phi) * math.sin(theta);

    final horizontal = math.sqrt(x0 * x0 + z0 * z0);
    final ex = z0 / horizontal;
    final ez = -x0 / horizontal;
    final nx = -x0 * y0 / horizontal;
    final ny = horizontal;
    final nz = -z0 * y0 / horizontal;

    return _Projected(
      domain: domain,
      position: _rotate(x0, y0, z0),
      east: _rotate(ex, 0, ez),
      north: _rotate(nx, ny, nz),
    );
  }

  List<_Projected> _allProjected() {
    final domains = AppDomains.all;
    return [
      for (var i = 0; i < domains.length; i++)
        _project(i, domains.length, domains[i]),
    ];
  }

  void _notifyFront(DomainPolicy front) {
    if (_lastFront == front.id) return;
    _lastFront = front.id;
    widget.onFrontDomainChanged?.call(front.id);
  }

  void _select(AppDomainId id) {
    unawaited(HapticFeedback.selectionClick());
    widget.onDomainSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final center = size / 2;
    final orbit = size * 0.38;
    const iconExtent = 64.0;

    final projected = _allProjected()..sort((a, b) => a.z.compareTo(b.z));
    final front = projected.last.domain;
    _notifyFront(front);

    final backStations = projected.where((p) => p.z <= 0);
    final frontStations = projected.where((p) => p.z > 0);

    Widget station(_Projected p) => _buildStation(
      p,
      left: center + p.x * orbit * _persp(p.z) - iconExtent / 2,
      top: center - p.y * orbit * _persp(p.z) - iconExtent / 2,
      extent: iconExtent,
    );

    final enter = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack);

    return GestureDetector(
      onPanStart: (_) {
        _dragging = true;
        _yawVelocity = 0;
        _pitchVelocity = 0;
      },
      onPanUpdate: (details) => setState(() {
        _yaw += details.delta.dx * _dragFactor;
        _pitch = (_pitch + details.delta.dy * _dragFactor).clamp(
          -_pitchLimit,
          _pitchLimit,
        );
      }),
      onPanEnd: (details) {
        _dragging = false;
        _allowSnap = true;
        _yawVelocity = details.velocity.pixelsPerSecond.dx * _dragFactor;
        _pitchVelocity = details.velocity.pixelsPerSecond.dy * _dragFactor;
      },
      onPanCancel: () {
        _dragging = false;
        _allowSnap = true;
      },
      child: FadeTransition(
        opacity: enter,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1).animate(enter),
          child: SizedBox(
            width: size,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Soft outer glow wash
                      Container(
                        width: orbit * 2.55,
                        height: orbit * 2.55,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              front.color.withValues(alpha: .28),
                              front.color.withValues(alpha: .08),
                              Colors.transparent,
                            ],
                            stops: const [0.35, 0.7, 1],
                          ),
                        ),
                      ),
                      // Atmosphere dust
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: _AtmospherePainter(color: front.color),
                        ),
                      ),
                      // Sphere shell
                      Container(
                        width: orbit * 2,
                        height: orbit * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.35, -0.45),
                            colors: [
                              Colors.white.withValues(alpha: .22),
                              front.color.withValues(alpha: .18),
                              front.color.withValues(alpha: .32),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .35),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: front.color.withValues(alpha: .35),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      ...backStations.map(station),
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: _SphereGridPainter(
                            yaw: _yaw,
                            pitch: _pitch,
                            radius: orbit,
                            color: front.color,
                          ),
                        ),
                      ),
                      ...frontStations.map(station),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: front.color,
                        fontWeight: FontWeight.w700,
                      ) ??
                      TextStyle(color: front.color, fontSize: 24),
                  child: Text(front.label),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    domainShortLine(front.id),
                    key: ValueKey(front.id),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Turn · tap',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted.withValues(alpha: .8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStation(
    _Projected p, {
    required double left,
    required double top,
    required double extent,
  }) {
    final depth = (p.z + 1) / 2;
    final scale = _persp(p.z);
    final opacity = (0.22 + 0.78 * depth).clamp(0.0, 1.0);
    final isFrontFacing = p.z > 0;
    final isSelected = p.domain.id == widget.selected;
    final isFrontMost = p.z > 0.55;

    final (ex, ey, ez) = p.east;
    final (nx, ny, nz) = p.north;
    final (rx, ry, rz) = p.position;
    final tilt = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..multiply(
        Matrix4(
          ex,
          -ey,
          -ez,
          0,
          -nx,
          ny,
          nz,
          0,
          rx,
          -ry,
          -rz,
          0,
          0,
          0,
          0,
          1,
        ),
      );

    final pulse = isSelected || isFrontMost ? 1 + 0.06 * _pulse.value : 1.0;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        ignoring: !isFrontFacing,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale * pulse,
            child: Transform(
              transform: tilt,
              alignment: Alignment.center,
              child: Semantics(
                button: true,
                label: '${p.domain.label}${isSelected ? ', selected' : ''}',
                child: GestureDetector(
                  key: Key('sphere_domain_${p.domain.id.name}'),
                  onTap: p.domain.enabled ? () => _select(p.domain.id) : null,
                  child: Container(
                    width: extent,
                    height: extent,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.domain.color.withValues(
                        alpha: isFrontFacing ? 1 : .5,
                      ),
                      border: Border.all(
                        color: isSelected || isFrontMost
                            ? Colors.white
                            : Colors.white.withValues(alpha: .3),
                        width: isSelected || isFrontMost ? 3 : 1.2,
                      ),
                      boxShadow: isFrontFacing
                          ? [
                              BoxShadow(
                                color: p.domain.color.withValues(alpha: .55),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .12),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _icons[p.domain.id],
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = color.withValues(alpha: .35);
    final center = size.center(Offset.zero);
    for (var i = 0; i < 28; i++) {
      final angle = rnd.nextDouble() * math.pi * 2;
      final dist = size.width * (0.18 + rnd.nextDouble() * 0.32);
      final r = 1.0 + rnd.nextDouble() * 2.2;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * dist,
          center.dy + math.sin(angle) * dist,
        ),
        r,
        paint..color = color.withValues(alpha: 0.12 + rnd.nextDouble() * 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SphereGridPainter extends CustomPainter {
  const _SphereGridPainter({
    required this.yaw,
    required this.pitch,
    required this.radius,
    required this.color,
  });

  final double yaw;
  final double pitch;
  final double radius;
  final Color color;

  static const _samples = 64;
  static const _latitudes = <double>[-60, -30, 0, 30, 60];
  static const _meridians = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final frontPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: .45);
    final backPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = color.withValues(alpha: .12);

    for (final latDeg in _latitudes) {
      final lat = latDeg * math.pi / 180;
      final ringRadius = math.cos(lat);
      final y = math.sin(lat);
      _drawCurve(
        canvas,
        center,
        frontPaint,
        backPaint,
        (t) => (ringRadius * math.cos(t), y, ringRadius * math.sin(t)),
      );
    }

    for (var i = 0; i < _meridians; i++) {
      final lon = i * math.pi / _meridians;
      _drawCurve(
        canvas,
        center,
        frontPaint,
        backPaint,
        (t) => (
          math.sin(t) * math.cos(lon),
          math.cos(t),
          math.sin(t) * math.sin(lon),
        ),
      );
    }
  }

  void _drawCurve(
    Canvas canvas,
    Offset center,
    Paint frontPaint,
    Paint backPaint,
    (double, double, double) Function(double t) curve,
  ) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    Offset? prev;
    double prevZ = 0;
    for (var i = 0; i <= _samples; i++) {
      final t = 2 * math.pi * i / _samples;
      final (x0, y0, z0) = curve(t);

      final x1 = x0 * cy + z0 * sy;
      final z1 = -x0 * sy + z0 * cy;
      final y2 = y0 * cp - z1 * sp;
      final z2 = y0 * sp + z1 * cp;

      final persp = _persp(z2);
      final point = Offset(
        center.dx + x1 * radius * persp,
        center.dy - y2 * radius * persp,
      );
      if (prev != null) {
        final isFront = (prevZ + z2) / 2 > 0;
        canvas.drawLine(prev, point, isFront ? frontPaint : backPaint);
      }
      prev = point;
      prevZ = z2;
    }
  }

  @override
  bool shouldRepaint(_SphereGridPainter oldDelegate) =>
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.radius != radius ||
      oldDelegate.color != color;
}
