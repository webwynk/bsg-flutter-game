import 'package:flutter/material.dart';
import '../../models/bet_model.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NUMBER CELL — matches reference image design safely
// ─────────────────────────────────────────────────────────────────────────────
class NumberCell extends StatelessWidget {
  final String number;
  final bool isEven;          // true = green, false = pink
  final VoidCallback onTap;
  final double fontSize;
  final int? stakedAmount;

  const NumberCell({
    super.key,
    required this.number,
    required this.isEven,
    required this.onTap,
    this.fontSize = 11,
    this.stakedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final hasBet = stakedAmount != null && stakedAmount! > 0;
    
    // Original bright green/pink colors
    const greenTop    = Color(0xFF6ADE5A);
    const greenBot    = Color(0xFF237A23);
    const greenBorder = Color(0xFFAAFFAA);

    const pinkTop    = Color(0xFFFF7088);
    const pinkBot    = Color(0xFFAA1230);
    const pinkBorder = Color(0xFFFFBBCC);

    final topC    = isEven ? greenTop    : pinkTop;
    final botC    = isEven ? greenBot    : pinkBot;
    final borderC = isEven ? greenBorder : pinkBorder;

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortSide = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final numberFontSize = shortSide * 0.44;
        final valueFontSize = numberFontSize * 0.55;
        final domeHeight = shortSide * 0.36;

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            clipBehavior: Clip.antiAlias, // Ensures the sliding gold dome doesn't overflow
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasBet 
                    ? const [Color(0xFFD32F2F), Color(0xFF8E0000)] // Deep red gradient
                    : [topC, botC],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: hasBet 
                    ? const Color(0xFFFFD700) 
                    : borderC.withValues(alpha: 0.7),
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 1. Number: centered when unbet, slides up when betted
                AnimatedAlign(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  alignment: hasBet ? const Alignment(0, -0.7) : Alignment.center,
                  child: Text(
                    number,
                    style: GoogleFonts.oswald(
                      fontSize: hasBet ? numberFontSize - 1.0 : numberFontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1.0,
                      color: hasBet ? const Color(0xFFFFD54F) : Colors.white,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),

                // 2. Gold Dome: slides up and fades in
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  bottom: hasBet ? 0 : -domeHeight,
                  height: domeHeight,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: hasBet ? 1.0 : 0.0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFEEAA), Color(0xFFD4AF37), Color(0xFF886611)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.elliptical(100, 100)),
                        boxShadow: [
                          BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, -1)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${stakedAmount ?? 0}',
                          style: GoogleFonts.oswald(
                            fontSize: (valueFontSize).clamp(8.0, 16.0),
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ROW ARROW BUTTON  ►  (left side)
// ─────────────────────────────────────────────────────────────────────────────
class RowArrowButton extends StatelessWidget {
  final int rowIndex;
  final BoardType boardType;
  final GameProvider game;
  final AuthProvider auth;

  const RowArrowButton({
    super.key,
    required this.rowIndex,
    required this.boardType,
    required this.game,
    required this.auth,
  });

  List<String> _keys() {
    if (boardType == BoardType.double_) {
      return List.generate(10, (c) => '$rowIndex$c');
    }
    final base = game.triplePage * 100 + rowIndex * 10;
    return List.generate(10, (c) => (base + c).toString().padLeft(3, '0'));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => game.activeChip != null
          ? game.placeBetOnRow(boardType, _keys(), auth)
          : game.removeChipFromRow(boardType, _keys(), auth),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 1.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5599EE), Color(0xFF1155BB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF88BBFF), width: 1.0),
        ),
        child: const Center(
          child: Icon(Icons.arrow_right, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLUMN ARROW BUTTON  ▼  (bottom strip)
// ─────────────────────────────────────────────────────────────────────────────
class ColArrowButton extends StatelessWidget {
  final int colIndex;
  final BoardType boardType;
  final GameProvider game;
  final AuthProvider auth;

  const ColArrowButton({
    super.key,
    required this.colIndex,
    required this.boardType,
    required this.game,
    required this.auth,
  });

  List<String> _keys() {
    if (boardType == BoardType.double_) {
      return List.generate(10, (r) => '$r$colIndex');
    }
    return List.generate(10, (r) {
      final n = game.triplePage * 100 + r * 10 + colIndex;
      return n.toString().padLeft(3, '0');
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => game.activeChip != null
          ? game.placeBetOnRow(boardType, _keys(), auth)
          : game.removeChipFromRow(boardType, _keys(), auth),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 1.0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5599EE), Color(0xFF1155BB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF88BBFF), width: 1.0),
        ),
        child: const Center(
          child: Icon(Icons.arrow_drop_up_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RANDOM SHORTCUT BUTTON  (right side — triggers random bet placement)
// ─────────────────────────────────────────────────────────────────────────────
class RandomShortcutButton extends StatelessWidget {
  final int count;
  final BoardType boardType;
  final GameProvider game;
  final AuthProvider auth;
  final double? height;

  const RandomShortcutButton({
    super.key,
    required this.count,
    required this.boardType,
    required this.game,
    required this.auth,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        game.placeRandomBets(boardType, count, auth);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: height,
        margin: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDD3344), Color(0xFF881122), Color(0xFF550011)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: const Color(0xFFCC3344),
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Center(
          child: Text(
            '$count',
            style: GoogleFonts.oswald(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
