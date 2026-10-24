import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../controls/exit_corner_button.dart';
import '../overlays/info_dialog.dart';
import '../tablet/scaled_box.dart';
import '../tablet/tablet_status_pill.dart';

/// The top bar of the desktop game screen, laid out at the desktop design
/// width (1280) and [height] 64 design units (the layout draws it scaled).
/// Left to right: the exit key, the coins balance, the countdown (centre), the
/// "Place your chips" / "No More Play" message, and the info icon. None of the
/// bar's elements has a border.
///
/// Every element reads the same game state and makes the same calls as its
/// phone or tablet counterpart: the exit key is the shared `ExitCornerButton`
/// (`Navigator.maybePop`, which the screen's `PopScope` turns into the exit
/// confirmation and then the lobby), the message is the tablet's status pill,
/// and the info icon opens `InfoDialog`.
class DesktopTopBar extends StatelessWidget {
  const DesktopTopBar({super.key});

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5A0508), Color(0xFF240204)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: AppColors.goldPrimary, width: 2)),
        boxShadow: [
          BoxShadow(color: Color(0xFF120000), offset: Offset(0, 4)),
          BoxShadow(color: Color(0x8C000000), blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: const [
          // Exit key: 40 design units drawn 1.5 times bigger, like the demo's 46px key.
          Positioned(
            left: 6,
            top: 0,
            child: ScaledBox(
              designWidth: 40,
              designHeight: 40,
              scale: 1.5,
              child: ExitCornerButton(bordered: false),
            ),
          ),
          Positioned(left: 76, top: 10, child: _CoinsPill()),
          Positioned(left: 520, top: 6, child: _Countdown()),
          Positioned(right: 76, top: 10, child: _StatusSlot()),
          Positioned(right: 16, top: 9, child: _InfoButton()),
        ],
      ),
    );
  }
}

/// The player's coins, with a thousands comma (4,650), in a pressed-in pill.
class _CoinsPill extends StatelessWidget {
  const _CoinsPill();

  static String _withCommas(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) => Container(
        height: 44,
        constraints: const BoxConstraints(minWidth: 190),
        padding: const EdgeInsets.only(left: 8, right: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF050100), Color(0xFF1F0803)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.white.withValues(alpha: 0.2), offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/bsg_coin.webp', width: 32, height: 32),
            const SizedBox(width: 10),
            Text(
              _withCommas(auth.coinBalance),
              style: const TextStyle(
                fontFamily: 'Oswald',
                fontWeight: FontWeight.w600,
                fontSize: 26,
                color: AppColors.goldBright,
                shadows: [
                  Shadow(color: Color(0x99FFD700), blurRadius: 8),
                  Shadow(color: Color(0xFF7A5A00), offset: Offset(0, 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The seconds left in the round: the number in a pressed-in window and
/// "SECONDS LEFT" beside it. The same rules as the phone's countdown box: the
/// number is `00` while spinning, turns red at 8 seconds or less, and pulses
/// then if there are bets on the board.
class _Countdown extends StatefulWidget {
  const _Countdown();

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.07)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
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
        final glow = isLow ? const Color(0xFFFF4632) : AppColors.goldBright;
        final edge = isLow ? const Color(0xFF7A1208) : const Color(0xFF7A5A00);
        return Container(
          width: 240,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A2A0C), Color(0xFF3A1206), Color(0xFF1C0603), Color(0xFF0D0302)],
              stops: [0.0, 0.48, 0.52, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0xFF120000), offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF050100), Color(0xFF1F0803)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withValues(alpha: 0.22), offset: const Offset(0, 1)),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.scale(
                    scale: (isLow && game.board.total > 0) ? _pulse.value : 1.0,
                    child: child,
                  ),
                  child: Text(
                    game.isSpinning ? '00' : game.countdown.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.w700,
                      fontSize: 34,
                      height: 1.0,
                      color: isLow ? AppColors.dangerRed : AppColors.goldBright,
                      shadows: [
                        Shadow(color: glow.withValues(alpha: 0.7), blurRadius: 9),
                        Shadow(color: edge, offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'SECONDS\nLEFT',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.25,
                  letterSpacing: 2,
                  color: AppColors.goldBright,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The status message, without the pill's border (the top bar has none).
class _StatusSlot extends StatelessWidget {
  const _StatusSlot();

  @override
  Widget build(BuildContext context) => const TabletStatusPill(scale: 0.95, bordered: false);
}

/// The info icon: a raised blue key with an italic "i". Opens the same
/// `InfoDialog` as the phone's INFO button, and is locked the same way (it does
/// nothing in the last 5 seconds or while the wheel spins, but does not dim).
class _InfoButton extends StatefulWidget {
  const _InfoButton();

  @override
  State<_InfoButton> createState() => _InfoButtonState();
}

class _InfoButtonState extends State<_InfoButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final locked = game.countdown <= 5 || game.isSpinning;
        return Semantics(
          button: true,
          label: 'Game info',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: locked ? null : () => InfoDialog.show(context),
            child: Listener(
              onPointerDown: (_) => _set(!locked),
              onPointerUp: (_) => _set(false),
              onPointerCancel: (_) => _set(false),
              child: Transform.translate(
                offset: Offset(0, _pressed ? 3 : 0),
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8FB0FF), Color(0xFF4169E1), Color(0xFF2848C4), Color(0xFF000080)],
                      stops: [0.0, 0.46, 0.54, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00003F), offset: Offset(0, _pressed ? 1 : 4)),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: _pressed ? 3 : 8,
                        offset: Offset(0, _pressed ? 2 : 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'i',
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      color: Colors.white,
                      shadows: [Shadow(color: Color(0x99000000), offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
