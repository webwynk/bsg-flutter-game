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

/// One vertical mode tab (SINGLE, DOUBLE or TRIPLE): its WIN and PLAY boxes,
/// an arrow showing whether its number grid is open, and the mode name.
/// Tapping it calls `game.openDrawerWithMode(tabMode, auth)`. The open tab is
/// the one with `game.mode == tabMode && game.isDrawerOpen`.
///
/// 3D redesign, Phase 3 changed only how it is painted (a raised, glossy tab
/// with pressed-in WIN / PLAY boxes, a raised arrow, and a 14pt label).
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
          // 3D redesign, Phase 3: a raised tab. A solid edge under it plus a
          // soft drop shadow give it height; the open tab keeps its gold glow.
          boxShadow: isActive
            ? const [
                BoxShadow(color: Color(0xFF120000), offset: Offset(0, 4)),
                BoxShadow(color: Color(0x77D4AF37), blurRadius: 6, spreadRadius: 1),
                BoxShadow(color: Color(0xA6000000), blurRadius: 9, offset: Offset(0, 7)),
              ]
            : const [
                BoxShadow(color: Color(0xFF120000), offset: Offset(0, 4)),
                BoxShadow(color: Color(0xA6000000), blurRadius: 9, offset: Offset(0, 7)),
              ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Soft dark band along the bottom (the tab curving away).
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // Side bevel: light on the left edge, shade on the right edge.
              Positioned(
                top: 0, bottom: 0, left: 0,
                width: 2,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.12)),
              ),
              Positioned(
                top: 0, bottom: 0, right: 0,
                width: 2,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
              ),
              Column(
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
                        shadows: [
                          const Shadow(color: Color(0xFF0B5A0B), offset: Offset(0, 1.5)),
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 2,
                            offset: const Offset(0, 2.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Mode label (vertical text, bottom 20% height with 10px bottom padding).
                  // 14pt, scaled down only if the word would not fit the space.
                  Expanded(
                    flex: 20,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Colors.white,
                                letterSpacing: 1.0,
                                shadows: [
                                  Shadow(color: Colors.black.withValues(alpha: 0.9), offset: const Offset(0, -1)),
                                  Shadow(color: Colors.white.withValues(alpha: 0.28), offset: const Offset(0, 1)),
                                  const Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(1, 1)),
                                ],
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Light catching the top of the tab (thin bright line + shine band).
              Positioned(
                top: 0, left: 0, right: 0,
                height: 1.5,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.38)),
              ),
              Positioned(
                top: 2, left: 3, right: 3,
                height: 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                      bottom: Radius.circular(10),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
      // 3D redesign, Phase 3: the box now looks pressed into the tab (a thin
      // light lip along its lower edge, shade falling across its top). The
      // colors and the text are unchanged.
      decoration: BoxDecoration(
        color: boxBg,
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.14), offset: const Offset(0, 1)),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            height: 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: hasValue ? 0.3 : 0.6),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Center(
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
        ],
      ),
    );
  }
}
