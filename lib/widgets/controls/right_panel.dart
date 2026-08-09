import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bet_model.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_decorations.dart';
import '../../services/sound_service.dart';
import '../overlays/info_dialog.dart';

class RightControlPanel extends StatelessWidget {
  final VoidCallback onSpin;
  const RightControlPanel({super.key, required this.onSpin});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.rightPanel,
      child: Column(
        children: [
          _PanelHeader(),
          _StatsPanel(),
          _HistoryGrid(),
          _ControlArea(onSpin: onSpin),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatefulWidget {
  @override
  State<_PanelHeader> createState() => _PanelHeaderState();
}

class _PanelHeaderState extends State<_PanelHeader> with SingleTickerProviderStateMixin {
  late AnimationController _flashCtrl;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
    _colorAnim = ColorTween(
      begin: AppColors.goldBright,
      end: AppColors.dangerRed,
    ).animate(_flashCtrl);
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B0000), Color(0xFF2A0000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: AppColors.goldPrimary, width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Spacer(),
          Consumer<GameProvider>(
            builder: (_, game, __) {
              if (game.countdown <= 5 && !game.isSpinning && game.countdown > 0) {
                return AnimatedBuilder(
                  animation: _colorAnim,
                  builder: (_, __) => Text(
                    'No More Play',
                    style: AppTextStyles.label(size: 10, color: _colorAnim.value)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                );
              }
              return Text(
                'Place your chips',
                style: AppTextStyles.label(size: 10, color: AppColors.goldBright)
                    .copyWith(fontWeight: FontWeight.w800),
              );
            },
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: AppColors.casinoRed,
                border: Border.all(color: AppColors.goldPrimary, width: 1.0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<GameProvider, AuthProvider>(
      builder: (_, game, auth, __) {
        final lastWin = game.lastWinBoxResult?.won == true ? game.lastWinBoxResult!.winAmount : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E0800), Color(0xFF150200)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.goldPrimary, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldPrimary.withValues(alpha: 0.15),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Row(
              children: [
                // Left Column: Play & Win
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatRow('PLAY:', '${game.totalBet}', Colors.white),
                        const SizedBox(height: 4),
                        _buildStatRow('WIN:', '+$lastWin', AppColors.successGreen),
                      ],
                    ),
                  ),
                ),
                // Vertical divider line
                Container(
                  width: 1.2,
                  height: 38,
                  color: AppColors.goldPrimary.withValues(alpha: 0.3),
                ),
                // Right Column: Balance
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'BALANCE',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontWeight: FontWeight.w700,
                            fontSize: 9.5,
                            color: AppColors.textGoldLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${auth.coinBalance}',
                            style: AppTextStyles.number(size: 15, color: AppColors.goldBright),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, Color valColor) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontWeight: FontWeight.w700,
            fontSize: 9.5,
            color: AppColors.textGoldLight,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Oswald',
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: valColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final hist = game.globalHistory;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.historyStart, AppColors.historyEnd],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: AppColors.goldPrimary.withValues(alpha: 0.5), 
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: List.generate(10, (col) {
                  // Index 0 of spinHistory is the most recent.
                  // We display the last 10 spins: newest on the left (col 0), oldest on the right.
                  final hasSpin = col < hist.length;
                  final spin = hasSpin ? hist[col] : null;
                  return Expanded(
                    child: Column(
                      children: [
                        _DigitCell(spin?.red, const Color(0xFFffbbbb)),
                        const SizedBox(height: 1),
                        _DigitCell(spin?.green, const Color(0xFFaaffcc)),
                        const SizedBox(height: 1),
                        _DigitCell(spin?.black, Colors.white),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DigitCell extends StatelessWidget {
  final int? digit;
  final Color textColor;
  const _DigitCell(this.digit, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: digit != null ? const Color(0xFF1E0400) : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        digit != null ? '$digit' : '-',
        style: TextStyle(
          fontFamily: 'Oswald',
          fontWeight: FontWeight.bold,
          fontSize: 8.5,
          color: digit != null ? textColor : Colors.white24,
        ),
      ),
    );
  }
}

class _ControlArea extends StatelessWidget {
  final VoidCallback onSpin;
  const _ControlArea({required this.onSpin});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Column: Chips
            _VerticalChips(),
            const SizedBox(width: 8),
            // Right Column: Action Buttons & Countdown
            Expanded(
              child: _ActionColumn(onSpin: onSpin),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalChips extends StatelessWidget {
  static const List<ChipValue> _chips = ChipValue.values;

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameProvider, AuthProvider>(
      builder: (_, game, auth, __) {
        final isLocked = game.countdown <= 5 || game.isSpinning;
        return Opacity(
          opacity: 1.0,
          child: IgnorePointer(
            ignoring: isLocked,
            child: SizedBox(
              width: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _chips.map((chip) {
                  final isSelected = game.activeChip == chip;
                  final amount = chip.amount;
                  return GestureDetector(
                    onTap: () => game.selectChip(chip),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: isSelected ? 44 : 36,
                      height: isSelected ? 44 : 36,
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
                        : const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                      child: Image.asset(
                        'assets/images/chip_$amount.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionColumn extends StatelessWidget {
  final VoidCallback onSpin;
  const _ActionColumn({required this.onSpin});

  static const _btns = [
    ('INFO',   [Color(0xFF4169E1), Color(0xFF000080)], Colors.white, Color(0xFF7B9BFF)),
    ('DOUBLE', [Color(0xFFFFD700), Color(0xFF8B6914)], Color(0xFF350000), AppColors.goldBright),
    ('CLEAR',  [Color(0xFF8B0000), Color(0xFF3E0000)], Colors.white, Color(0xFFFF6666)),
    ('REMOVE', [Color(0xFF8B0000), Color(0xFF3E0000)], Colors.white, Color(0xFFFF6666)),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameProvider, AuthProvider>(
      builder: (_, game, auth, __) {
        final hasBets = game.board.total > 0;
        final showRebet = game.canRebet;
        // Checked separately from showRebet so an unaffordable rebet still
        // shows the REBET label (just disabled) instead of silently
        // swapping to DOUBLE -- the board is empty whenever showRebet is
        // true, so DOUBLE would show up correctly disabled too, but as the
        // wrong button entirely.
        final canAffordRebet = showRebet && game.canAffordRebet(auth);

        final isButtonsLocked = game.countdown <= 5 || game.isSpinning;

        // REBET uses a distinct purple/violet color to stand out
        const rebetBtn = (
          'REBET',
          [Color(0xFF6A0DAD), Color(0xFF3A0060)],
          Colors.white,
          Color(0xFFCC88FF),
        );

        return Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // INFO — disabled when countdown ≤ 5 or spinning, but not dim
                  _ActionBtn(_btns[0],
                      isEnabled: !isButtonsLocked,
                      dimWhenDisabled: false,
                      onTap: () => _showInfo(context, game)),
                  // DOUBLE / REBET — toggles based on game state. REBET stays
                  // labeled REBET even when unaffordable -- only its enabled
                  // state depends on balance, never which button shows.
                  showRebet
                      ? _ActionBtn(rebetBtn, isEnabled: !isButtonsLocked && canAffordRebet,
                          onTap: () => game.rebet(auth))
                      : _ActionBtn(_btns[1], isEnabled: hasBets && !isButtonsLocked,
                          onTap: () => game.doDouble(auth)),
                  // CLEAR — only when board has bets
                  _ActionBtn(_btns[2], isEnabled: hasBets && !isButtonsLocked,
                      onTap: () => game.clearBets(auth)),
                  // REMOVE — only when board has bets; deselects the chip to enter remove mode
                  _ActionBtn(_btns[3], isEnabled: hasBets && !isButtonsLocked,
                      onTap: () => game.deselectChip()),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _CountdownBox(onSpin: onSpin),
          ],
        );
      },
    );
  }

  void _showInfo(BuildContext context, GameProvider game) {
    InfoDialog.show(context);
  }
}

class _ActionBtn extends StatelessWidget {
  final (String, List<Color>, Color, Color) data;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool dimWhenDisabled;
  const _ActionBtn(this.data, {required this.onTap, this.isEnabled = true, this.dimWhenDisabled = true});

  @override
  Widget build(BuildContext context) {
    // Disabled = same color but faded to 40% opacity. Taps blocked via IgnorePointer.
    return Expanded(
      child: Opacity(
        opacity: isEnabled ? 1.0 : (dimWhenDisabled ? 0.40 : 1.0),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          child: GestureDetector(
            onTap: isEnabled
                ? () {
                    SoundService().playButtonClick();
                    onTap();
                  }
                : null,
            child: Container(
              decoration: AppDecorations.actionButton(data.$2).copyWith(
                border: Border.all(color: data.$4, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 1, left: 1, right: 1,
                    height: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      data.$1,
                      style: AppTextStyles.button(size: 10, color: data.$3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownBox extends StatefulWidget {
  final VoidCallback onSpin;
  const _CountdownBox({required this.onSpin});

  @override
  State<_CountdownBox> createState() => _CountdownBoxState();
}

class _CountdownBoxState extends State<_CountdownBox> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final isLow = game.countdown <= 8;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E0800), Color(0xFF150200)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.goldPrimary,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: (isLow && game.board.total > 0) ? _pulseAnim.value : 1.0,
                  child: child,
                ),
                child: Text(
                  game.isSpinning ? '00' : game.countdown.toString().padLeft(2, '0'),
                  style: GoogleFonts.oswald(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: isLow ? AppColors.dangerRed : AppColors.goldBright,
                  ),
                ),
              ),
              const Text(
                'SECONDS LEFT',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  fontSize: 8.0,
                  height: 1.0,
                  color: AppColors.textGold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
