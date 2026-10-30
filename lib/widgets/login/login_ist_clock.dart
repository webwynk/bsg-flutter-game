import 'dart:async';
import 'package:flutter/material.dart';

/// The wall-clock time in India for the instant [now], whatever time zone the
/// device is set to. India has one zone, UTC+5:30, and no daylight saving. The
/// result is a UTC DateTime whose fields read as the Indian time.
DateTime istFrom(DateTime now) => now.toUtc().add(const Duration(hours: 5, minutes: 30));

/// The text pieces of an Indian time, in 12-hour form with a leading zero.
class IstClockText {
  final String hours;
  final String minutes;
  final String seconds;
  final String amPm;
  final String date;

  const IstClockText({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.amPm,
    required this.date,
  });

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Builds the pieces for the instant [now]. Midnight and noon read 12, never 00.
  factory IstClockText.of(DateTime now) {
    final ist = istFrom(now);
    final hour12 = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    String two(int n) => n.toString().padLeft(2, '0');
    return IstClockText(
      hours: two(hour12),
      minutes: two(ist.minute),
      seconds: two(ist.second),
      amPm: ist.hour < 12 ? 'AM' : 'PM',
      date: '${_weekdays[ist.weekday - 1]}, ${ist.day} ${_months[ist.month - 1]} ${ist.year}',
    );
  }
}

/// The gold plaque on the left of the tablet and desktop login: the label, the
/// live Indian time in raised gold numbers, a line and the date. Sizes are the
/// design's at 1180 x 820; the login layout scales the whole screen.
class LoginIstClock extends StatefulWidget {
  /// Where the current instant comes from; tests pass a fixed one.
  final DateTime Function() clock;

  const LoginIstClock({super.key, this.clock = DateTime.now});

  @override
  State<LoginIstClock> createState() => _LoginIstClockState();
}

class _LoginIstClockState extends State<LoginIstClock> {
  static const _gold = Color(0xFFD4AF37);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Twice a second so the colon blinks once a second and the seconds never
    // skip a number when the timer drifts against the real clock.
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final text = IstClockText.of(now);
    final colonLit = now.millisecond < 500;
    return RepaintBoundary(
      child: Container(
        key: const ValueKey('login-clock-plaque'),
        width: 520,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _gold.withValues(alpha: 0.75), width: 2),
          // CSS 160deg: from just left of the top to just right of the bottom.
          gradient: const LinearGradient(
            begin: Alignment(-0.342, -0.94),
            end: Alignment(0.342, 0.94),
            colors: [Color(0xD12A0800), Color(0xE0100000)],
          ),
          boxShadow: [
            BoxShadow(color: _gold.withValues(alpha: 0.25), blurRadius: 40),
            const BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 14)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _label(),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _GoldNumber(text.hours, size: 132),
                Opacity(opacity: colonLit ? 1 : 0.25, child: const _GoldNumber(':', size: 132)),
                _GoldNumber(text.minutes, size: 132),
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GoldNumber(text.amPm, size: 40),
                    const SizedBox(height: 6),
                    _GoldNumber(text.seconds, size: 30),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x00D4AF37), _gold, Color(0x00D4AF37)]),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              text.date,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Oswald',
                fontWeight: FontWeight.w500,
                fontSize: 30,
                letterSpacing: 1.5,
                color: Color(0xFFF5E6C4),
                shadows: [Shadow(color: Color(0xCC000000), offset: Offset(0, 2), blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label() {
    Widget line() => Container(width: 46, height: 1, color: _gold);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        line(),
        const SizedBox(width: 12),
        const Text(
          'INDIA STANDARD TIME',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 3,
            color: _gold,
          ),
        ),
        const SizedBox(width: 12),
        line(),
      ],
    );
  }
}

/// A raised gold number: a dark back layer with stacked brown shadows gives the
/// depth, and a front layer filled with a vertical gold gradient sits on top.
class _GoldNumber extends StatelessWidget {
  final String text;
  final double size;

  const _GoldNumber(this.text, {required this.size});

  static const _depth = [
    Color(0xFF8A5D0E),
    Color(0xFF7A520C),
    Color(0xFF6E490A),
    Color(0xFF634109),
    Color(0xFF573908),
    Color(0xFF4B3107),
    Color(0xFF3F2906),
  ];

  static const _face = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFBE0),
      Color(0xFFFFE680),
      Color(0xFFFFD700),
      Color(0xFFE0B83A),
      Color(0xFFB8901F),
      Color(0xFF7A5A10),
    ],
  );

  @override
  Widget build(BuildContext context) {
    TextStyle style(Color color, [List<Shadow>? shadows]) => TextStyle(
          fontFamily: 'Oswald',
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1.1,
          color: color,
          shadows: shadows,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Stack(
      children: [
        Text(
          text,
          style: style(const Color(0xFF5A3A06), [
            for (var i = 0; i < _depth.length; i++) Shadow(color: _depth[i], offset: Offset(0, i + 1.0)),
            const Shadow(color: Color(0xB3000000), offset: Offset(0, 9), blurRadius: 2),
            const Shadow(color: Color(0x80000000), offset: Offset(0, 14), blurRadius: 24),
          ]),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => _face.createShader(bounds),
          child: Text(text, style: style(Colors.white)),
        ),
      ],
    );
  }
}
