import 'dart:math';

import 'package:flutter/material.dart';

/// 主页面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final List<_FireworkBurst> _bursts;
  final Stopwatch _stopwatch = Stopwatch();
  final List<_InteractiveBurst> _interactiveBursts = [];
  int _lastMoveBurstMs = 0;
  final Random _random = Random();
  bool _isSleeping = false;

  static const _interactiveBurstDuration = 0.55;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _stopwatch.start();
    _bursts = _buildBursts();
    _syncWithCurrentLifecycle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _wakeFireworks();
      return;
    }
    _sleepFireworks();
  }

  void _syncWithCurrentLifecycle() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.resumed || state == null) {
      _wakeFireworks();
      return;
    }
    _sleepFireworks();
  }

  void _sleepFireworks() {
    if (_isSleeping) {
      return;
    }
    _isSleeping = true;
    _controller.stop(canceled: false);
    _stopwatch.stop();
    _interactiveBursts.clear();
  }

  void _wakeFireworks() {
    if (!_isSleeping && _controller.isAnimating) {
      return;
    }
    _isSleeping = false;
    _controller.repeat();
    _stopwatch.start();
  }

  List<_FireworkBurst> _buildBursts() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.deepOrange,
      Colors.pink,
      Colors.indigo,
    ];

    return List.generate(10, (index) {
      final center = Offset(
        0.12 + _random.nextDouble() * 0.76,
        0.18 + _random.nextDouble() * 0.42,
      );
      final particleCount = 28 + _random.nextInt(18);
      final particles = List.generate(particleCount, (_) {
        final angle = _random.nextDouble() * pi * 2;
        final velocity = 70 + _random.nextDouble() * 130;
        final size = 1.6 + _random.nextDouble() * 1.7;
        return _Particle(angle: angle, velocity: velocity, size: size);
      });

      return _FireworkBurst(
        start: _random.nextDouble() * 0.95,
        duration: 0.28 + _random.nextDouble() * 0.22,
        center: center,
        color: colors[index % colors.length],
        particles: particles,
      );
    });
  }

  void _spawnInteractiveBurst(Offset localPosition, {bool subtle = false}) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.deepOrange,
      Colors.pink,
      Colors.indigo,
    ];
    final count = subtle ? 12 + _random.nextInt(8) : 26 + _random.nextInt(12);
    final particles = List.generate(count, (_) {
      final angle = _random.nextDouble() * pi * 2;
      final velocity = subtle
          ? 40 + _random.nextDouble() * 70
          : 60 + _random.nextDouble() * 120;
      final size = subtle
          ? 1.2 + _random.nextDouble() * 1.2
          : 1.6 + _random.nextDouble() * 1.8;
      return _Particle(angle: angle, velocity: velocity, size: size);
    });

    final now = _stopwatch.elapsedMilliseconds / 1000;
    _interactiveBursts.add(
      _InteractiveBurst(
        startTime: now,
        duration: _interactiveBurstDuration,
        center: localPosition,
        color: colors[_random.nextInt(colors.length)],
        particles: particles,
      ),
    );

    _interactiveBursts.removeWhere(
      (burst) => now - burst.startTime > _interactiveBurstDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: Colors.white,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            setState(() {
              _spawnInteractiveBurst(event.localPosition);
            });
          },
          onPointerMove: (event) {
            final nowMs = _stopwatch.elapsedMilliseconds;
            if (nowMs - _lastMoveBurstMs < 70) {
              return;
            }
            _lastMoveBurstMs = nowMs;
            setState(() {
              _spawnInteractiveBurst(event.localPosition, subtle: true);
            });
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final now = _stopwatch.elapsedMilliseconds / 1000;
              return CustomPaint(
                painter: _FireworksPainter(
                  progress: _controller.value,
                  bursts: _bursts,
                  interactiveBursts: _interactiveBursts,
                  nowSeconds: now,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FireworksPainter extends CustomPainter {
  final double progress;
  final List<_FireworkBurst> bursts;
  final List<_InteractiveBurst> interactiveBursts;
  final double nowSeconds;

  _FireworksPainter({
    required this.progress,
    required this.bursts,
    required this.interactiveBursts,
    required this.nowSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rocketPaint = Paint()..style = PaintingStyle.fill;
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (final burst in bursts) {
      var t = (progress - burst.start) / burst.duration;
      if (t < 0) {
        t += 1;
      }
      if (t < 0 || t > 1) {
        continue;
      }

      final center = Offset(
        size.width * burst.center.dx,
        size.height * burst.center.dy,
      );
      const launchPart = 0.18;

      if (t < launchPart) {
        final launchT = t / launchPart;
        final launchStart = Offset(center.dx, size.height + 20);
        final current = Offset.lerp(launchStart, center, launchT)!;
        rocketPaint.color = burst.color.withValues(alpha: 0.9 - launchT * 0.25);
        canvas.drawCircle(current, 2.4, rocketPaint);
        continue;
      }

      final explodeT = ((t - launchPart) / (1 - launchPart)).clamp(0.0, 1.0);
      final alpha = (1 - explodeT).clamp(0.0, 1.0);

      for (final particle in burst.particles) {
        final distance = particle.velocity * explodeT;
        final gravity = 58 * explodeT * explodeT;
        final offset = Offset(
          cos(particle.angle) * distance,
          sin(particle.angle) * distance + gravity,
        );

        particlePaint.color = burst.color.withValues(alpha: alpha);
        canvas.drawCircle(center + offset, particle.size, particlePaint);
      }
    }

    for (final burst in interactiveBursts) {
      final t = (nowSeconds - burst.startTime) / burst.duration;
      if (t < 0 || t > 1) {
        continue;
      }
      final alpha = (1 - t).clamp(0.0, 1.0);
      for (final particle in burst.particles) {
        final distance = particle.velocity * t;
        final gravity = 55 * t * t;
        final offset = Offset(
          cos(particle.angle) * distance,
          sin(particle.angle) * distance + gravity,
        );
        particlePaint.color = burst.color.withValues(alpha: alpha);
        canvas.drawCircle(burst.center + offset, particle.size, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bursts != bursts ||
        oldDelegate.interactiveBursts != interactiveBursts ||
        oldDelegate.nowSeconds != nowSeconds;
  }
}

class _FireworkBurst {
  final double start;
  final double duration;
  final Offset center;
  final Color color;
  final List<_Particle> particles;

  const _FireworkBurst({
    required this.start,
    required this.duration,
    required this.center,
    required this.color,
    required this.particles,
  });
}

class _Particle {
  final double angle;
  final double velocity;
  final double size;

  const _Particle({
    required this.angle,
    required this.velocity,
    required this.size,
  });
}

class _InteractiveBurst {
  final double startTime;
  final double duration;
  final Offset center;
  final Color color;
  final List<_Particle> particles;

  const _InteractiveBurst({
    required this.startTime,
    required this.duration,
    required this.center,
    required this.color,
    required this.particles,
  });
}
