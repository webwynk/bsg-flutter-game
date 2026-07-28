import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ResultLens extends StatelessWidget {
  const ResultLens({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final r = game.lastResult;
        return Container(
          width: 38,
          height: 82,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.blueLens, AppColors.blueLensDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: const Color(0xFF5577ff), width: 1.5),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(color: Color(0x551a3f99), blurRadius: 12),
            ],
          ),
          child: Column(
            children: [
              _slot(r?.red,   const Color(0xFFff9999)),
              Container(height: 0.7, color: const Color(0xFF5577ff)),
              _slot(r?.green, const Color(0xFF99ffbb)),
              Container(height: 0.7, color: const Color(0xFF5577ff)),
              _slot(r?.black, Colors.white),
            ],
          ),
        );
      },
    );
  }

  Widget _slot(int? digit, Color color) {
    return Expanded(
      child: Center(
        child: Text(
          digit == null ? '—' : '$digit',
          style: AppTextStyles.number(size: 20, color: color),
        ),
      ),
    );
  }
}
