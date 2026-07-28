import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

class ResultOverlay extends StatefulWidget {
  const ResultOverlay({super.key});

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay> {
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final result = context.read<GameProvider>().lastResult;
      if (result?.won == true) {
        _confetti.play();
      }
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final result = game.lastResult;
        if (result == null) return const SizedBox.shrink();

        return Stack(
          fit: StackFit.expand,
          children: [
            // Blurred backdrop
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.80)),
            ),

            // Confetti
            if (result.won)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.08,
                  numberOfParticles: 20,
                  gravity: 0.3,
                  colors: const [
                    AppColors.goldBright, Colors.white, AppColors.casinoRed,
                    AppColors.successGreen, Colors.blue, Colors.purple,
                  ],
                ),
              ),

            // Result card — constrained to screen height so button never clips
            LayoutBuilder(
              builder: (_, constraints) => Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: constraints.maxHeight * 0.96,
                  ),
                  child: _buildCard(result).animate()
                    .scale(begin: const Offset(0.5, 0.5),
                      curve: Curves.elasticOut, duration: 500.ms)
                    .fadeIn(duration: 300.ms),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(result) {
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
                fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
