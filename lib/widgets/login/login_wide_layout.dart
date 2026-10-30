import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'login_ist_clock.dart';

/// The horizontal login for tablets and desktops: the Indian time plaque on the
/// left, a gold divider down the middle, and on the right the login card with
/// the 18+ banner under it. It goes on top of the login screen's background.
///
/// Laid out at the design size of 1180 x 820 and scaled as a whole to the
/// screen, stretching the design canvas along the longer side, so a 1920 x 1080
/// desktop comes out about 1.3 times the tablet size.
///
/// The login screen's Scaffold does not shrink for the on-screen keyboard here,
/// because that would shrink the whole design. Instead the right side alone
/// gets shorter and scrolls, and it brings the bottom of the card into view
/// whenever the keyboard or the error text changes, so the field being typed
/// in and the LOGIN button stay on screen.
class LoginWideLayout extends StatefulWidget {
  /// The login card; this layout gives it its width.
  final Widget form;

  /// Where the clock reads the current instant; tests pass a fixed one.
  final DateTime Function() clock;

  const LoginWideLayout({super.key, required this.form, this.clock = DateTime.now});

  static const Size designSize = Size(1180, 820);
  static const double cardWidth = 380;
  static const double bannerWidth = 340;
  static const double cardToBannerGap = 26;

  /// How much the design is enlarged or reduced to fit [screen].
  static double scaleFor(Size screen) =>
      math.min(screen.width / designSize.width, screen.height / designSize.height);

  @override
  State<LoginWideLayout> createState() => _LoginWideLayoutState();
}

class _LoginWideLayoutState extends State<LoginWideLayout> {
  final _cardKey = GlobalKey();
  double _lastKeyboard = 0;
  String? _lastError;

  /// With the keyboard up, scrolls so the card's bottom sits at the bottom of
  /// the space left above the keyboard.
  void _keepCardVisibleIfChanged(double keyboard, String? error) {
    final changed = keyboard != _lastKeyboard || error != _lastError;
    _lastKeyboard = keyboard;
    _lastError = error;
    if (!changed || keyboard <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _cardKey.currentContext;
      if (card != null && card.mounted) {
        Scrollable.ensureVisible(card, alignment: 1.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = LoginWideLayout.scaleFor(media.size);
    final keyboard = media.viewInsets.bottom / scale;
    final canvas = media.size / scale;
    _keepCardVisibleIfChanged(keyboard, context.select<AuthProvider, String?>((a) => a.error));

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: canvas.width,
        height: canvas.height,
        child: Row(
          children: [
            Expanded(child: Center(child: LoginIstClock(clock: widget.clock))),
            _divider(),
            Expanded(child: _rightSide(keyboard)),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      key: const ValueKey('login-divider'),
      width: 2,
      margin: const EdgeInsets.symmetric(vertical: 60),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00D4AF37), Color(0xFFD4AF37), Color(0x00D4AF37)],
        ),
      ),
    );
  }

  Widget _rightSide(double keyboard) {
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  key: _cardKey,
                  width: LoginWideLayout.cardWidth,
                  child: widget.form,
                ),
                const SizedBox(height: LoginWideLayout.cardToBannerGap),
                SizedBox(
                  width: LoginWideLayout.bannerWidth,
                  child: Image.asset(
                    'assets/images/warning_18.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
