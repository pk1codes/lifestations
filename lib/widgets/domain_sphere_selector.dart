import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/app_domain.dart';

/// 3D domain picker: five station icons ride a translucent wireframe sphere.
/// Drag to rotate (with fling momentum), tap a front-facing icon to select.
///
/// Pure math — no 3D engine. Base positions come from a Fibonacci lattice,
/// then rigid yaw/pitch rotation matrices are applied, projected to 2D with
/// mild perspective, and painted back-to-front. Each icon is additionally
/// tilted onto the sphere's tangent plane so it appears stuck to the surface
/// (foreshortening toward the limb) instead of billboarding at the camera.
class DomainSphereSelector extends StatefulWidget {
  const DomainSphereSelector({
    required this.selected,
    required this.onDomainSelected,
    this.size = 300,
    super.key,
  });

  final AppDomainId selected;
  final ValueChanged<AppDomainId> onDomainSelected;
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

  /// Rotated unit position and tangent basis vectors, world space
  /// (x right, y up, z toward viewer).
  final (double, double, double) position;
  final (double, double, double) east;
  final (double, double, double) north;

  double get x => position.$1;
  double get y => position.$2;
  double get z => position.$3;
}

/// Perspective factor shared by grid and icons so icons sit on the grid.
const double _kPerspective = 0.22;

double _persp(double z) => 1 / (1 - z * _kPerspective);

class _DomainSphereSelectorState extends State<DomainSphereSelector>
    with SingleTickerProviderStateMixin {
  static const _dragFactor = 0.01;
  static const _idleYawSpeed = 0.25; // rad/s gentle spin while untouched
  static const _pitchLimit = 1.1;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  double _yaw = 0;
  double _pitch = -0.25;
  double _yawVelocity = 0;
  double _pitchVelocity = 0;
  bool _dragging = false;

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
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.1 || _dragging) return;
    final damping = math.exp(-2.4 * dt);
    _yawVelocity *= damping;
    _pitchVelocity *= damping;
    setState(() {
      _yaw += (_yawVelocity + _idleYawSpeed) * dt;
      _pitch = (_pitch + _pitchVelocity * dt).clamp(-_pitchLimit, _pitchLimit);
    });
  }

  /// Applies the sphere's rigid Y-axis (yaw) then X-axis (pitch) rotation.
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

  /// Fibonacci lattice base position (unit sphere) plus its tangent basis
  /// (east/north), all rotated by the same sphere rotation so icons share
  /// the surface's coordinate frame exactly.
  _Projected _project(int index, int count, DomainPolicy domain) {
    final phi = math.acos(1 - 2 * (index + 0.5) / count);
    final theta = math.pi * (1 + math.sqrt(5)) * index;
    final x0 = math.sin(phi) * math.cos(theta);
    final y0 = math.cos(phi);
    final z0 = math.sin(phi) * math.sin(theta);

    // Tangent basis at the base point: east = up × p, north = p × east.
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

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final center = size / 2;
    final orbit = size * 0.36;
    const iconExtent = 56.0;

    final domains = AppDomains.all;
    final projected = [
      for (var i = 0; i < domains.length; i++)
        _project(i, domains.length, domains[i]),
    ]..sort((a, b) => a.z.compareTo(b.z)); // back first, front painted last

    final front = projected.last.domain;
    // Grid lines must paint above back-hemisphere icons but below front ones.
    final backStations = projected.where((p) => p.z <= 0);
    final frontStations = projected.where((p) => p.z > 0);

    Widget station(_Projected p) => _buildStation(
      p,
      left: center + p.x * orbit * _persp(p.z) - iconExtent / 2,
      top: center - p.y * orbit * _persp(p.z) - iconExtent / 2,
      extent: iconExtent,
    );

    return GestureDetector(
      onPanStart: (_) => _dragging = true,
      onPanUpdate: (details) => setState(() {
        _yaw += details.delta.dx * _dragFactor;
        _pitch = (_pitch + details.delta.dy * _dragFactor).clamp(
          -_pitchLimit,
          _pitchLimit,
        );
      }),
      onPanEnd: (details) {
        _dragging = false;
        _yawVelocity = details.velocity.pixelsPerSecond.dx * _dragFactor;
        _pitchVelocity = details.velocity.pixelsPerSecond.dy * _dragFactor;
      },
      onPanCancel: () => _dragging = false,
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
                  // Translucent sphere shell
                  Container(
                    width: orbit * 2,
                    height: orbit * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [
                          front.color.withValues(alpha: .05),
                          front.color.withValues(alpha: .16),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                      ),
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
            const SizedBox(height: 4),
            Text(
              front.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: front.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Drag the sphere · tap a station',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
    final depth = (p.z + 1) / 2; // 0 back … 1 front
    // Scale by the same perspective factor as the grid so icon size tracks
    // the surface exactly; the tangent tilt supplies the foreshortening.
    final scale = _persp(p.z);
    final opacity = (0.25 + 0.75 * depth).clamp(0.0, 1.0);
    final isFrontFacing = p.z > 0;
    final isSelected = p.domain.id == widget.selected;

    // Map the icon plane directly onto the sphere's rotated tangent frame:
    // local +x → surface east, local +y (screen down) → surface south, so the
    // icon co-rotates with the surface like a sticker on a globe. World
    // vectors (y up, z toward viewer) convert to Flutter transform space
    // (y down, z into screen) by negating y and z. The perspective entry is
    // pre-multiplied so out-of-plane depth foreshortens near the limb.
    final (ex, ey, ez) = p.east;
    final (nx, ny, nz) = p.north;
    final (rx, ry, rz) = p.position;
    final tilt = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..multiply(
        Matrix4(
          // column 0: image of local +x
          ex,
          -ey,
          -ez,
          0,
          // column 1: image of local +y (down) → -north
          -nx,
          ny,
          nz,
          0,
          // column 2: image of local +z → radial normal
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

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        // Back-hemisphere icons must never steal taps from front ones.
        ignoring: !isFrontFacing,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Transform(
              transform: tilt,
              alignment: Alignment.center,
              child: Semantics(
                button: true,
                label: '${p.domain.label}${isSelected ? ', selected' : ''}',
                child: GestureDetector(
                  key: Key('sphere_domain_${p.domain.id.name}'),
                  onTap: p.domain.enabled
                      ? () => widget.onDomainSelected(p.domain.id)
                      : null,
                  child: Container(
                    width: extent,
                    height: extent,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.domain.color.withValues(
                        alpha: isFrontFacing ? .95 : .55,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: .25),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isFrontFacing
                          ? [
                              BoxShadow(
                                color: p.domain.color.withValues(alpha: .4),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _icons[p.domain.id],
                      size: 26,
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

/// Latitude/longitude wireframe rotated by the same yaw/pitch as the icons.
/// Front-facing segments are brighter; back-facing ones show faintly through
/// the translucent shell.
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
  static const _meridians = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final frontPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: .35);
    final backPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = color.withValues(alpha: .09);

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
