import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import 'grids.dart';

class LeftAccordionPanel extends StatelessWidget {
  const LeftAccordionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the maximum width available for the DOUBLE and TRIPLE grids.
        // We know the RightControlPanel takes 28% of the screen.
        // The screen width is calculated dynamically.
        final double screenWidth = MediaQuery.of(context).size.width;
        final double rightPanelWidth = screenWidth * 0.28;
        // Total width available for the entire LeftAccordionPanel and the Wheel
        final double totalLeftAreaWidth = screenWidth - rightPanelWidth;
        // The three mode tabs each take 45px + 5px margin = 50px each -> 150px total.
        // We add some padding (4 left + 4 right = 8). Total static width ≈ 158px.
        final double tabsWidth = (45.0 + 5.0) * 3 + 8.0;
        final double doubleTripleGridWidth = totalLeftAreaWidth - tabsWidth - 1.5; // subtract right border width

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF150200), // Rich dark red-brown theme background
            border: Border(
              right: BorderSide(color: AppColors.goldPrimary, width: 1.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Consumer2<GameProvider, AuthProvider>(
            builder: (_, game, auth, __) {
              final mode = game.mode;
              final isOpen = game.isDrawerOpen;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min, // Hugs content when closed
                children: [
                  // 1. SINGLE Tab
                  _ModeTab(tabMode: 'single', label: 'SINGLE', game: game, auth: auth),
                  
                  // 2. SINGLE Grid (Animated Width)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    width: (mode == 'single' && isOpen) ? 140.0 : 0.0,
                    child: ClipRect(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: 140.0,
                          child: const GridSingle(),
                        ),
                      ),
                    ),
                  ),

                  // 3. DOUBLE Tab
                  _ModeTab(tabMode: 'double', label: 'DOUBLE', game: game, auth: auth),

                  // 4. DOUBLE Grid (Animated Width)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    width: (mode == 'double' && isOpen) ? doubleTripleGridWidth : 0.0,
                    child: ClipRect(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: doubleTripleGridWidth,
                          child: const GridDouble(),
                        ),
                      ),
                    ),
                  ),

                  // 5. TRIPLE Tab
                  _ModeTab(tabMode: 'triple', label: 'TRIPLE', game: game, auth: auth),

                  // 6. TRIPLE Grid (Animated Width)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    width: (mode == 'triple' && isOpen) ? doubleTripleGridWidth : 0.0,
                    child: ClipRect(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: doubleTripleGridWidth,
                          child: const GridTriple(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String tabMode;
  final String label;
  final GameProvider game;
  final AuthProvider auth;

  const _ModeTab({
    required this.tabMode,
    required this.label,
    required this.game,
    required this.auth,
  });

  bool get isActive => game.mode == tabMode && game.isDrawerOpen;

  @override
  Widget build(BuildContext context) {
    final win  = game.winForMode(tabMode);
    final play = game.playForMode(tabMode);

    return GestureDetector(
      onTap: () => game.openDrawerWithMode(tabMode, auth),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 45, // Fixed width for the vertical tab
        margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive
              ? const [Color(0xFFCC1818), Color(0xFF780A0A), Color(0xFF3A0101)]
              : const [Color(0xFF9A0A0A), Color(0xFF5A0404), Color(0xFF280101)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.goldBright : const Color(0xFF6A0404),
            width: isActive ? 2.2 : 1.5,
          ),
          boxShadow: isActive
            ? const [
                BoxShadow(color: Color(0x77D4AF37), blurRadius: 6, spreadRadius: 1),
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
              ]
            : const [
                BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
              ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 6),
            // WIN box (rounded rectangle, 35% height)
            Expanded(
              flex: 35,
              child: _VerticalInfoBox(
                label: 'WIN',
                value: '$win',
              ),
            ),
            // PLAY box (rounded rectangle, 35% height)
            Expanded(
              flex: 35,
              child: _VerticalInfoBox(
                label: 'PLAY',
                value: '$play',
              ),
            ),
            const SizedBox(height: 8),
            // Solid green triangle pointing down (open/active) or up (closed/inactive)
            SizedBox(
              height: 24,
              child: Center(
                child: Icon(
                  isActive ? Icons.arrow_drop_down_sharp : Icons.arrow_drop_up_sharp,
                  color: const Color(0xFF32CD32), // Pure Lime Green
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Mode label (vertical text, bottom 20% height with 10px bottom padding)
            Expanded(
              flex: 20,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'DMSans',
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.white,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(1, 1)),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A taller box whose text content runs vertically (rotated 90°).
class _VerticalInfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _VerticalInfoBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final valInt = int.tryParse(value) ?? 0;
    final bool hasValue = valInt > 0;

    Color boxBg = const Color(0xFF4A0000); // Default dark red bg
    Color borderColor = const Color(0xFF7B0000); // Default dark red border

    if (label == 'WIN') {
      if (hasValue) {
        boxBg = const Color(0xFF32CD32); // Pure bright green bg
        borderColor = const Color(0xFF99FF99); // Light green border
      }
    } else if (label == 'PLAY') {
      if (hasValue) {
        boxBg = const Color(0xFFFF0000); // Pure red bg
        borderColor = const Color(0xFFFFFF00); // Golden yellow border
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
      width: double.infinity,
      decoration: BoxDecoration(
        color: boxBg,
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: '$label : ',
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
