import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bet_model.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';

/// The chips (2, 5, 10, 50, 100) in one horizontal row, for the tablet control
/// panel. The phone shows the same chips in a column (`_VerticalChips`).
///
/// Behaviour is the same: tapping a chip calls `game.selectChip(chip)`, and the
/// row ignores touches while betting is locked (`countdown <= 5` or spinning).
/// The selected chip is drawn bigger with a gold glow.
///
/// Sizes are in the panel's design units (the tablet layout draws the panel
/// enlarged): each chip is as big as the row's width allows, between
/// [_minChipSize] and [_maxChipSize], and the selected chip is
/// [_selectedExtra] bigger.
class TabletChipRow extends StatelessWidget {
  const TabletChipRow({super.key});

  static const List<ChipValue> _chips = ChipValue.values;

  static const double _minChipSize = 34.0;
  static const double _maxChipSize = 44.0;
  static const double _selectedExtra = 8.0;
  // Width kept free for the gaps between chips and the selected chip's glow.
  static const double _horizontalReserve = 14.0;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final isLocked = game.countdown <= 5 || game.isSpinning;
        return IgnorePointer(
          ignoring: isLocked,
          child: LayoutBuilder(
            builder: (_, constraints) {
              final chipSize = ((constraints.maxWidth - _selectedExtra - _horizontalReserve) /
                      _chips.length)
                  .clamp(_minChipSize, _maxChipSize);
              final selectedSize = chipSize + _selectedExtra;
              return SizedBox(
                height: selectedSize + 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _chips.map((chip) {
                    final isSelected = game.activeChip == chip;
                    final amount = chip.amount;
                    return GestureDetector(
                      onTap: () => game.selectChip(chip),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isSelected ? selectedSize : chipSize,
                        height: isSelected ? selectedSize : chipSize,
                        decoration: isSelected
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.goldBright, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.goldBright,
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              )
                            : const BoxDecoration(shape: BoxShape.circle),
                        child: Image.asset(
                          'assets/images/chip_$amount.webp',
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
