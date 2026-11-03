import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CityRushApp());
}

const Color ink = Color(0xFF10252B);
const Color paper = Color(0xFFF4F1E8);
const Color coral = Color(0xFFFF684A);
const Color mint = Color(0xFF7BE0BD);

class CityRushApp extends StatelessWidget {
  const CityRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'City Rush: Double Dash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: coral,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RushScreen(),
    );
  }
}

enum ObstacleKind { coin, barrier, overhead }

class TrackObject {
  TrackObject(this.kind, this.lane);

  final ObstacleKind kind;
  final int lane;
  double position = -0.06;
  bool resolved = false;
}

class RunnerData {
  RunnerData(this.name, this.accent, int seed) : random = math.Random(seed);

  final String name;
  final Color accent;
  final math.Random random;
  final List<TrackObject> objects = [];
  int lane = 1;
  int coins = 0;
  double distance = 0;
  double actionTime = 0;
  double slideClock = 0;
  double spawnClock = 0;
  bool jumping = false;
  bool sliding = false;
  bool alive = true;

  int get score => (distance * 10).floor() + coins * 25;

  void reset() {
    objects.clear();
    lane = 1;
    coins = 0;
    distance = 0;
    actionTime = 0;
    slideClock = 0;
    spawnClock = 0;
    jumping = false;
    sliding = false;
    alive = true;
  }
}

class RushScreen extends StatefulWidget {
  const RushScreen({super.key});

  @override
  State<RushScreen> createState() => _RushScreenState();
}

class _RushScreenState extends State<RushScreen> {
  late final RunnerData _runnerOne;
  late final RunnerData _runnerTwo;
  Timer? _timer;
  DateTime? _lastTick;
  bool _running = false;
  bool _paused = false;
  bool _gameOver = false;
  double _worldPhase = 0;

  @override
  void initState() {
    super.initState();
    _runnerOne = RunnerData('PLAYER 1', coral, 17);
    _runnerTwo = RunnerData('PLAYER 2', mint, 41);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _timer?.cancel();
    _runnerOne.reset();
    _runnerTwo.reset();
    setState(() {
      _running = true;
      _paused = false;
      _gameOver = false;
      _worldPhase = 0;
    });
    _lastTick = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 32), _tick);
  }

  void _togglePause() {
    if (_gameOver) return;
    if (_paused) {
      setState(() => _paused = false);
      _lastTick = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 32), _tick);
    } else if (_running) {
      _timer?.cancel();
      setState(() => _paused = true);
    }
  }

  void _tick(Timer timer) {
    final DateTime now = DateTime.now();
    final double delta = math.min(
      0.06,
      now.difference(_lastTick!).inMicroseconds / 1000000,
    ).toDouble();
    _lastTick = now;

    setState(() {
      _worldPhase = (_worldPhase + delta * 0.55) % 1;
      _advanceRunner(_runnerOne, delta);
      _advanceRunner(_runnerTwo, delta);
      if (!_runnerOne.alive && !_runnerTwo.alive) {
        _running = false;
        _gameOver = true;
        timer.cancel();
      }
    });
  }

  void _advanceRunner(RunnerData runner, double delta) {
    if (!runner.alive) return;

    runner.distance += delta * (5.5 + math.min(4, runner.distance * 0.018));
    runner.actionTime = math.max(0, runner.actionTime - delta).toDouble();
    runner.slideClock = math.max(0, runner.slideClock - delta).toDouble();
    runner.jumping = runner.actionTime > 0 && !runner.sliding;
    runner.sliding = runner.slideClock > 0;

    final double speed =
        0.43 + math.min(0.35, runner.distance * 0.0015).toDouble();
    runner.spawnClock += delta;
    final double spawnEvery =
        math.max(0.58, 1.05 - runner.distance * 0.0018).toDouble();
    if (runner.spawnClock >= spawnEvery) {
      runner.spawnClock -= spawnEvery;
      final int lane = runner.random.nextInt(3);
      final double choice = runner.random.nextDouble();
      final ObstacleKind kind = choice < 0.48
          ? ObstacleKind.coin
          : choice < 0.77
          ? ObstacleKind.barrier
          : ObstacleKind.overhead;
      runner.objects.add(TrackObject(kind, lane));
    }

    for (final TrackObject object in runner.objects) {
      object.position += delta * speed;
      if (object.resolved || object.position < 0.78 || object.position > 0.91) {
        continue;
      }
      if (object.lane != runner.lane) continue;

      object.resolved = true;
      if (object.kind == ObstacleKind.coin) {
        runner.coins++;
      } else if (object.kind == ObstacleKind.barrier && !runner.jumping) {
        runner.alive = false;
      } else if (object.kind == ObstacleKind.overhead && !runner.sliding) {
        runner.alive = false;
      }
    }
    runner.objects.removeWhere(
      (TrackObject object) => object.position > 1.08 || object.resolved,
    );
  }

  void _moveLane(RunnerData runner, int direction) {
    if (!_running || !runner.alive) return;
    setState(() => runner.lane = (runner.lane + direction).clamp(0, 2).toInt());
  }

  void _jump(RunnerData runner) {
    if (!_running || !runner.alive || runner.sliding) return;
    setState(() {
      runner.actionTime = 0.68;
      runner.jumping = true;
    });
  }

  void _slide(RunnerData runner) {
    if (!_running || !runner.alive) return;
    setState(() {
      runner.slideClock = 0.72;
      runner.sliding = true;
      runner.jumping = false;
    });
  }

  String get _resultTitle {
    if (_runnerOne.score == _runnerTwo.score) return 'PHOTO FINISH';
    return _runnerOne.score > _runnerTwo.score
        ? 'PLAYER 1 WINS'
        : 'PLAYER 2 WINS';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool landscape =
                        constraints.maxWidth > constraints.maxHeight;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Flex(
                          direction: landscape ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildRunnerPane(_runnerOne)),
                            Container(
                              width: landscape ? 2 : null,
                              height: landscape ? null : 2,
                              color: const Color(0xFF496168),
                            ),
                            Expanded(child: _buildRunnerPane(_runnerTwo)),
                          ],
                        ),
                        if (!_running) _buildOverlay(),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 9),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: coral,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.bolt_rounded, color: ink, size: 28),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CITY RUSH',
                style: TextStyle(
                  color: paper,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'DOUBLE DASH',
                style: TextStyle(
                  color: mint,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
        if (_running || _paused)
          IconButton.filledTonal(
            onPressed: _togglePause,
            tooltip: _paused ? 'Resume' : 'Pause',
            icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF233B41),
              foregroundColor: paper,
            ),
          ),
      ],
    );
  }

  Widget _buildRunnerPane(RunnerData runner) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: RunnerPainter(runner: runner, worldPhase: _worldPhase),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                _tag(runner.name, runner.accent),
                const Spacer(),
                _tag('${runner.score}  /  ${runner.coins} COINS', paper),
              ],
            ),
          ),
          if (!runner.alive)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x990B171B),
                child: Center(
                  child: Text(
                    'WIPEOUT\n${runner.score} PTS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: runner.accent,
                      height: 1.35,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          if (_running && runner.alive)
            Positioned(
              bottom: 9,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  runner.sliding ? 'SLIDE!' : runner.jumping ? 'AIR TIME' : 'RUN!',
                  style: TextStyle(
                    color: runner.accent.withValues(alpha: 0.95),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          if (runner.alive)
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (DragEndDetails details) {
                final double velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() > 100) {
                  _moveLane(runner, velocity < 0 ? -1 : 1);
                }
              },
              onVerticalDragEnd: (DragEndDetails details) {
                final double velocity = details.primaryVelocity ?? 0;
                if (velocity < -100) _jump(runner);
                if (velocity > 100) _slide(runner);
              },
              onTap: () => _jump(runner),
            ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD914252B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final String title = _paused
        ? 'TAKE A BREATHER'
        : _gameOver
        ? _resultTitle
        : 'READY TO RUN?';
    final String subtitle = _paused
        ? 'The city can wait.'
        : _gameOver
        ? 'P1  ${_runnerOne.score}   ·   P2  ${_runnerTwo.score}'
        : 'Two runners. One city. How far can you go?';
    final String buttonLabel = _paused
        ? 'BACK TO THE RUN'
        : _gameOver
        ? 'RUN IT BACK'
        : 'START THE RUN';

    return ColoredBox(
      color: const Color(0xAA0B171B),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_run_rounded, size: 36, color: coral),
                const SizedBox(height: 9),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: paper,
                    fontSize: 23,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD0D8D5), fontSize: 12),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _paused ? _togglePause : _startGame,
                  icon: Icon(
                    _paused ? Icons.play_arrow_rounded : Icons.bolt_rounded,
                  ),
                  label: Text(buttonLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: coral,
                    foregroundColor: ink,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        const Icon(Icons.swipe_rounded, color: mint, size: 18),
        const SizedBox(width: 7),
        const Expanded(
          child: Text(
            'SWIPE TO MOVE  ·  UP JUMP  ·  DOWN SLIDE',
            style: TextStyle(
              color: Color(0xFFB4C4C1),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Text(
          _running ? 'LIVE' : 'P1  VS  P2',
          style: const TextStyle(
            color: coral,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class RunnerPainter extends CustomPainter {
  const RunnerPainter({required this.runner, required this.worldPhase});

  final RunnerData runner;
  final double worldPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Paint paint = Paint()..isAntiAlias = true;
    paint.shader = const LinearGradient(
      colors: [Color(0xFF315F67), Color(0xFF8DAA91), Color(0xFFE7AA72)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(bounds);
    canvas.drawRect(bounds, paint);
    paint.shader = null;

    _drawCity(canvas, size, paint);
    _drawTrack(canvas, size, paint);
    _drawObjects(canvas, size, paint);
    if (runner.alive) _drawRunner(canvas, size, paint);
  }

  void _drawCity(Canvas canvas, Size size, Paint paint) {
    paint.color = const Color(0xFF24464C).withValues(alpha: 0.78);
    for (int index = 0; index < 12; index++) {
      final double width = size.width / 8.5;
      final double center = (index * 0.39 + 0.08) % 1.12;
      final double x = center * size.width - width / 2;
      final double height = size.height * (0.13 + (index * 17 % 13) / 100);
      final Rect building = Rect.fromLTWH(
        x,
        size.height * 0.32 - height,
        width,
        height,
      );
      canvas.drawRect(building, paint);
      paint.color = const Color(0xFFFFD89B).withValues(alpha: 0.62);
      for (int row = 0; row < 3; row++) {
        for (int column = 0; column < 2; column++) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + width * (0.2 + column * 0.42),
              building.top + 7 + row * 11,
              3,
              4,
            ),
            paint,
          );
        }
      }
      paint.color = const Color(0xFF24464C).withValues(alpha: 0.78);
    }
    paint.color = const Color(0xFF17383F).withValues(alpha: 0.55);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.31, size.width, size.height * 0.05),
      paint,
    );
  }

  void _drawTrack(Canvas canvas, Size size, Paint paint) {
    final Path track = Path()
      ..moveTo(size.width * 0.42, size.height * 0.22)
      ..lineTo(size.width * 0.58, size.height * 0.22)
      ..lineTo(size.width * 0.97, size.height)
      ..lineTo(size.width * 0.03, size.height)
      ..close();
    paint.color = const Color(0xFF334348);
    canvas.drawPath(track, paint);

    paint.color = const Color(0xFFB9C1AD).withValues(alpha: 0.76);
    paint.strokeWidth = 2;
    for (final double edge in [0.42, 0.47, 0.53, 0.58]) {
      canvas.drawLine(
        Offset(size.width * edge, size.height * 0.22),
        Offset(
          size.width * (0.03 + (edge - 0.42) / 0.16 * 0.94),
          size.height,
        ),
        paint,
      );
    }

    for (int index = 0; index < 14; index++) {
      final double progress = (index / 14 + worldPhase) % 1;
      final double y = size.height * (0.24 + progress * 0.82);
      final double spread = size.width * (0.08 + progress * 0.46);
      paint
        ..color = const Color(0xFFB7A58B).withValues(alpha: 0.3 + progress * 0.3)
        ..strokeWidth = 0.8 + progress * 3;
      canvas.drawLine(
        Offset(size.width / 2 - spread, y),
        Offset(size.width / 2 + spread, y),
        paint,
      );
    }
    paint.strokeWidth = 1;
  }

  double _laneX(Size size, int lane, double progress) {
    final double top = size.width * (0.44 + lane * 0.06);
    final double bottom = size.width * (0.25 + lane * 0.25);
    return top + (bottom - top) * progress;
  }

  void _drawObjects(Canvas canvas, Size size, Paint paint) {
    for (final TrackObject object in runner.objects) {
      if (object.resolved || object.position < 0 || object.position > 1.05) {
        continue;
      }
      final double progress = object.position.clamp(0.0, 1.0).toDouble();
      final double x = _laneX(size, object.lane, progress);
      final double y = size.height * (0.22 + progress * 0.78);
      final double scale = 0.45 + progress * 0.75;
      if (object.kind == ObstacleKind.coin) {
        paint
          ..color = const Color(0xFFFFD45E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * scale;
        canvas.drawCircle(Offset(x, y), 7 * scale, paint);
        paint
          ..color = const Color(0xFFFFEBA7)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 3 * scale, paint);
      } else if (object.kind == ObstacleKind.barrier) {
        final Rect barrier = Rect.fromCenter(
          center: Offset(x, y),
          width: size.width * 0.085 * scale,
          height: size.height * 0.034 * scale,
        );
        paint.color = const Color(0xFFF35F46);
        canvas.drawRRect(
          RRect.fromRectAndRadius(barrier, Radius.circular(3 * scale)),
          paint,
        );
        paint
          ..color = const Color(0xFFFFD17C)
          ..strokeWidth = 1.4 * scale;
        canvas.drawLine(
          Offset(barrier.left + barrier.width * 0.3, barrier.top),
          Offset(barrier.left + barrier.width * 0.55, barrier.bottom),
          paint,
        );
      } else {
        final double beamWidth = size.width * 0.11 * scale;
        final Rect beam = Rect.fromCenter(
          center: Offset(x, y - size.height * 0.025 * scale),
          width: beamWidth,
          height: size.height * 0.022 * scale,
        );
        paint.color = const Color(0xFFDBD4BB);
        canvas.drawRect(beam, paint);
        paint
          ..color = const Color(0xFFFF684A)
          ..strokeWidth = 2 * scale;
        canvas.drawLine(
          Offset(beam.left, beam.bottom),
          Offset(beam.left, y + size.height * 0.018 * scale),
          paint,
        );
        canvas.drawLine(
          Offset(beam.right, beam.bottom),
          Offset(beam.right, y + size.height * 0.018 * scale),
          paint,
        );
      }
    }
    paint.style = PaintingStyle.fill;
  }

  void _drawRunner(Canvas canvas, Size size, Paint paint) {
    final double baseY = size.height * 0.87;
    final double jumpLift = runner.jumping
        ? math.sin((runner.actionTime / 0.68) * math.pi) * size.height * 0.12
        : 0;
    final double x = _laneX(size, runner.lane, 0.83);
    final double scale = size.width * 0.0045;
    final double y = baseY - jumpLift;

    paint.color = const Color(0x550B1518);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, baseY + 9 * scale),
        width: 39 * scale,
        height: 10 * scale,
      ),
      paint,
    );

    if (runner.sliding) {
      paint.color = runner.accent;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y + 7 * scale),
            width: 42 * scale,
            height: 17 * scale,
          ),
          Radius.circular(9 * scale),
        ),
        paint,
      );
      paint.color = const Color(0xFFFFD5AC);
      canvas.drawCircle(Offset(x + 13 * scale, y + scale), 8 * scale, paint);
      return;
    }

    paint.color = runner.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, y + 13 * scale),
          width: 19 * scale,
          height: 28 * scale,
        ),
        Radius.circular(6 * scale),
      ),
      paint,
    );
    paint.color = const Color(0xFFFFD5AC);
    canvas.drawCircle(Offset(x, y - 9 * scale), 10 * scale, paint);
    paint
      ..color = const Color(0xFF17272B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * scale;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(x, y - 11 * scale), radius: 10 * scale),
      math.pi,
      math.pi,
      false,
      paint,
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFD5AC);
    canvas.drawLine(
      Offset(x - 7 * scale, y + 7 * scale),
      Offset(x - 15 * scale, y + 18 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(x + 7 * scale, y + 7 * scale),
      Offset(x + 15 * scale, y + 16 * scale),
      paint,
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * scale
      ..color = const Color(0xFF17272B);
    canvas.drawLine(
      Offset(x - 5 * scale, y + 25 * scale),
      Offset(x - 10 * scale, y + 38 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(x + 5 * scale, y + 25 * scale),
      Offset(x + 11 * scale, y + 37 * scale),
      paint,
    );
    paint
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  @override
  bool shouldRepaint(covariant RunnerPainter oldDelegate) => true;
}