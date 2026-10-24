import 'package:flutter/material.dart';

/// The exit (X) button in the top-right corner of the wheel area on the
/// Triple Chance screen. It used to sit in the right panel's header.
///
/// Behaviour is identical to that old button: a tap calls
/// `Navigator.maybePop(context)`, which the game screen's `PopScope` turns into
/// the "Exit game" confirmation. No sound and nothing else happens here.
///
/// It looks like a raised glossy red key (a solid edge and drop shadow under it,
/// a shine band, a gold rim) and sinks 2px while held. The visible button is
/// 30x30; the tappable area is 40x40 (5px of invisible padding on every side).
class ExitCornerButton extends StatefulWidget {
  /// Whether the button has its thin gold rim. True everywhere except the
  /// desktop top bar, whose elements have no borders.
  final bool bordered;
  const ExitCornerButton({super.key, this.bordered = true});

  @override
  State<ExitCornerButton> createState() => _ExitCornerButtonState();
}

class _ExitCornerButtonState extends State<ExitCornerButton> {
  // True while a finger is down on the button (drives the press-down look only).
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Exit game',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.maybePop(context),
        child: Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Transform.translate(
              offset: Offset(0, _pressed ? 2 : 0),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7D8F), Color(0xFFE0304C), Color(0xFFB01A34), Color(0xFF6A0818)],
                    stops: [0.0, 0.46, 0.54, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: widget.bordered
                      ? Border.all(color: const Color(0xFFFFE27A), width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3A0610),
                      offset: Offset(0, _pressed ? 1 : 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: _pressed ? 3 : 8,
                      offset: Offset(0, _pressed ? 2 : 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Soft dark band along the bottom (the key curving away).
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Shine band across the upper part of the face.
                      Positioned(
                        top: 2, left: 3, right: 3,
                        height: 11,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                              bottom: Radius.circular(10),
                            ),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.5),
                                Colors.white.withValues(alpha: 0.06),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 17,
                          shadows: [
                            Shadow(color: Color(0x99000000), offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ],
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
