import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/spin_result_model.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// The win popup: a blurred, dimmed backdrop with the result card on top.
///
/// Mounted by `game_screen.dart` only when `GameProvider.lastResult` is a
/// win, and unmounted when the provider clears it — so this widget's whole
/// lifetime is the popup's on-screen duration. It holds no state of its own:
/// everything it draws comes from the provider, and its entrance animation is
/// driven by `flutter_animate`, not by a controller this class owns.
///
/// Issue #104: was a `StatefulWidget` purely to own a `ConfettiController`
/// (created in `initState`, played from a post-frame callback, disposed in
/// `dispose`). With the confetti removed, that controller was the only thing
/// the `State` existed for, so the `State` went with it.
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final result = game.lastResult;
        // Defensive, not dead: this widget and its mount site in
        // game_screen.dart each have their own Consumer, so this one can
        // rebuild with a null result in the frame where the provider clears
        // it, before the parent has unmounted us.
        if (result == null) return const SizedBox.shrink();

        return Stack(
          fit: StackFit.expand,
          children: [
            // Blurred backdrop
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.80)),
            ),

            // Result card — constrained to screen height so button never clips
            LayoutBuilder(
              builder: (_, constraints) => Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: constraints.maxHeight * 0.96,
                  ),
                  child: _buildCard(context, result).animate()
                    .scale(begin: const Offset(0.5, 0.5),
                      curve: Curves.easeOutCubic, duration: 400.ms)
                    .fadeIn(duration: 300.ms),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the popup card itself. Takes [context] explicitly because this is
  /// now a StatelessWidget — there is no `State.context` to reach for, and
  /// `MediaQuery` below needs one. The context passed is `build`'s own, which
  /// is the same element context the old `State` used.
  ///
  /// Issue #116: [result] is typed. It used to be an implicit `dynamic`, so a
  /// misspelt field (`result.winAmont`) would have compiled and then thrown
  /// `NoSuchMethodError` on screen, in the one widget whose job is to show the
  /// player what they just won. It is always `GameProvider.lastResult`, a
  /// `SpinResult`, by the time this is reached (the caller null-checks it).
  Widget _buildCard(BuildContext context, SpinResult result) {
    return Container(
      decoration: AppDecorations.resultCard.copyWith(
        image: const DecorationImage(
          image: AssetImage('assets/images/win-popup.webp'),
          fit: BoxFit.fill,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // 1. Win Title: win-text.webp (70% width of maximum popup)
          Image.asset(
            'assets/images/win-text.webp',
            width: (MediaQuery.of(context).size.width * 0.45).clamp(180.0, 294.0),
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 14),

          // 2. Central green 3D button type displaying box with total winning points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF99FF99), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              '${result.winAmount}',
              style: const TextStyle(
                fontFamily: 'Oswald',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Bottom Row: Single, Double, Triple breakdowns
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _breakdownText('Single', result.singleWinAmount),
              _breakdownText('Double', result.doubleWinAmount),
              _breakdownText('Triple', result.tripleWinAmount),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _breakdownText(String label, int amount) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.goldBright,
              letterSpacing: 0.5,
            ),
          ),
          TextSpan(
            text: '$amount',
            style: const TextStyle(
              fontFamily: 'Oswald',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
