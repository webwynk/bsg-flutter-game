// The pieces every Spin2Win dialog is made of, as the reference design's "Records popup" draws
// them: the gold frame around a deep blue card with a thin cyan line inside, the red round close
// button, and the page that shows a dialog at the same scale as the game behind it.
//
// Belongs to Spin2Win only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'spin2win_layout.dart';
import 'spin2win_palette.dart';

/// Shows [child] (drawn at the phone design's size) as a dialog over the game, scaled exactly as
/// the game is, with the design's pop-in (`wpPop`: 0.45 s, a little overshoot).
Future<T?> spin2WinShowDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String label = 'Dialog',
  bool barrierDismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: label,
    barrierColor: const Color(0xA6000000),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, _, __) => Spin2WinDialogPage(child: Builder(builder: builder)),
    transitionBuilder: (context, animation, _, child) {
      final pop = CurvedAnimation(parent: animation, curve: const Cubic(.2, 1.4, .4, 1), reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.4)),
        child: ScaleTransition(scale: Tween<double>(begin: 0.6, end: 1).animate(pop), child: child),
      );
    },
  );
}

/// A whole-screen dialog page: the child in the middle, at the game's own scale (enlarged as the
/// design enlarges popups on a tablet or desktop), and the phone's font-size setting ignored
/// inside, as in the game.
class Spin2WinDialogPage extends StatelessWidget {
  const Spin2WinDialogPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      // Edge to edge from side to side, as the game behind it.
      child: SafeArea(
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screen = constraints.biggest;
            // On the tablet and desktop boards the design enlarges its popups as it does the top
            // bar: the dialog is laid out in the board's space shrunk by that much.
            final board = Spin2WinLayout.forScreen(screen);
            final design = board.designSizeFor(screen) / board.popupZoom;
            final scale = math.min(screen.width / design.width, screen.height / design.height);
            // Laid out in the design's own space and scaled as one, like the game behind it.
            return Center(
              child: SizedBox(
                width: design.width * scale,
                height: design.height * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox.fromSize(
                    size: design,
                    // The game's own text style, inside the Material (which would otherwise set the
                    // app theme's).
                    child: Center(
                      child: Material(
                        type: MaterialType.transparency,
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            fontFamily: kSpin2WinFont,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFFFFF),
                          ),
                          child: child,
                        ),
                      ),
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

/// The design's dialog card: a 4 dp gold frame with a dark rim under it and a warm glow, and inside
/// it the deep blue card with a thin cyan line around its edge.
class Spin2WinDialogCard extends StatelessWidget {
  const Spin2WinDialogCard({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  });

  final double width;
  final double? height;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF0C0), Color(0xFFFFB52E), Color(0xFFD98300), Color(0xFFFFD45A)],
          stops: [0, .35, .7, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF5A3500), offset: Offset(0, 7)),
          BoxShadow(color: Color(0xB3000000), offset: Offset(0, 16), blurRadius: 32),
          BoxShadow(color: Color(0x73FFB52E), blurRadius: 36),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1),
              radius: 1.1,
              colors: [Color(0xFF3A1F96), Color(0xFF1C2370), Color(0xFF102650), Color(0xFF07132E)],
              stops: [0, .4, .7, 1],
            ),
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x8000E5FF), width: 2),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// The red round close button with a white X (34 dp, inside a 48 dp tap area).
class Spin2WinCloseButton extends StatelessWidget {
  const Spin2WinCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFC2CC), width: 2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF7A8E), Color(0xFFFF3155), Color(0xFFC8102E)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF5E0716), offset: Offset(0, 3)),
                  BoxShadow(color: Color(0x80000000), offset: Offset(0, 5), blurRadius: 8),
                ],
              ),
              child: const CustomPaint(painter: _CrossPainter()),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const h = 5.0;
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(-h, -h), c + const Offset(h, h), paint);
    canvas.drawLine(c + const Offset(h, -h), c + const Offset(-h, h), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => false;
}

/// A big 3D button in one of the design's colours (the exit question's NO and YES).
class Spin2WinDialogButton extends StatelessWidget {
  const Spin2WinDialogButton({
    super.key,
    required this.label,
    required this.colors,
    required this.edge,
    required this.under,
    required this.onTap,
  });

  final String label;
  final List<Color> colors;
  final Color edge;
  final Color under;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: edge, width: 2),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            boxShadow: [
              BoxShadow(color: under, offset: const Offset(0, 4)),
              const BoxShadow(color: Color(0x80000000), offset: Offset(0, 6), blurRadius: 8),
            ],
          ),
          child: Spin2WinOutlinedText(label, size: 18, height: 1, stroke: under, letterSpacing: 1.5),
        ),
      ),
    );
  }
}
