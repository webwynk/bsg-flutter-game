import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bet_model.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import 'grid_cells.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE  (0–9 in a 2×5 layout)
// ─────────────────────────────────────────────────────────────────────────────
class GridSingle extends StatelessWidget {
  const GridSingle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameProvider, AuthProvider>(
      builder: (_, game, auth, __) => Padding(
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (_, c) {
            final cellW = (c.maxWidth - 2) / 2;
            final cellH = (c.maxHeight - 8) / 5;
            final cs    = cellW < cellH ? cellW : cellH;
            return Center(
              child: SizedBox(
                width: cs * 2 + 2,
                height: cs * 5 + 8,
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: 10,
                  itemBuilder: (_, i) {
                    final key = '$i';
                    return NumberCell(
                      number: key,
                      stakedAmount: game.board.single[key],
                      isEven: i % 2 == 0,
                      onTap: () => game.activeChip != null
                          ? game.placeBet(BoardType.single, key, auth)
                          : game.removeChipFromCell(BoardType.single, key, auth),
                      fontSize: cs * 0.36,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOUBLE  (00–99, 10×10 with row/col arrows + chip shortcuts)
// ─────────────────────────────────────────────────────────────────────────────
class GridDouble extends StatelessWidget {
  const GridDouble({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameProvider, AuthProvider>(
      builder: (_, game, auth, __) => LayoutBuilder(
        builder: (_, outer) => _DoubleBody(
          game: game,
          auth: auth,
          availW: outer.maxWidth,
          availH: outer.maxHeight,
        ),
      ),
    );
  }
}

class _DoubleBody extends StatelessWidget {
  final GameProvider game;
  final AuthProvider auth;
  final double availW;
  final double availH;

  const _DoubleBody({
    required this.game,
    required this.auth,
    required this.availW,
    required this.availH,
  });

  @override
  Widget build(BuildContext context) {
    const rowArrowW = 28.0;
    const chipBtnW  = 36.0;
    const colArrowH = 26.0;
    const gap       = 2.0;

    // Grid area available after fixed-width strips
    final gridAvailW = availW - rowArrowW - chipBtnW - gap * 2;
    final gridAvailH = availH - colArrowH - gap;

    // Keep cells square; grid fills all available space
    final cs = min(gridAvailW / 10, gridAvailH / 10);
    final gridW = cs * 10;
    final gridH = cs * 10;
    final fontSize = cs * 0.30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Row: [row arrows] [grid] [chip buttons] ────────────────────
        SizedBox(
          height: gridH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left row arrows (►)
              SizedBox(
                width: rowArrowW,
                child: Column(
                  children: List.generate(10, (row) => SizedBox(
                    height: cs,
                    child: RowArrowButton(
                      rowIndex: row,
                      boardType: BoardType.double_,
                      game: game,
                      auth: auth,
                    ),
                  )),
                ),
              ),
              const SizedBox(width: gap),

              // Centre: gold-framed 10×10 grid
              Container(
                width: gridW,
                height: gridH,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D1A00),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.goldPrimary, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 10,
                    childAspectRatio: 1,
                    crossAxisSpacing: 0,
                    mainAxisSpacing: 0,
                  ),
                  itemCount: 100,
                  itemBuilder: (_, i) {
                    final num = i.toString().padLeft(2, '0');
                    return NumberCell(
                      number: num,
                      stakedAmount: game.board.double_[num],
                      isEven: ((i ~/ 10) + (i % 10)) % 2 == 0,
                      onTap: () => game.activeChip != null
                          ? game.placeBet(BoardType.double_, num, auth)
                          : game.removeChipFromCell(BoardType.double_, num, auth),
                      fontSize: fontSize,
                    );
                  },
                ),
              ),
              const SizedBox(width: gap),

              // Right random shortcut buttons
              SizedBox(
                width: chipBtnW,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _DoubleBody._buildRandomBtns(game, auth, gridH),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: gap),

        // ── Bottom column arrows (▼) ────────────────────────────────────
        SizedBox(
          height: colArrowH,
          child: Row(
            children: [
              const SizedBox(width: rowArrowW + gap),
              ...List.generate(10, (col) => SizedBox(
                width: cs,
                child: ColArrowButton(
                  colIndex: col,
                  boardType: BoardType.double_,
                  game: game,
                  auth: auth,
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  static const _doubleRandomCounts = [5, 10, 15, 20, 25, 50, 75];

  static List<Widget> _buildRandomBtns(
    GameProvider game, AuthProvider auth, double gridH) {
    return _doubleRandomCounts.map((count) => Expanded(
      child: RandomShortcutButton(
        count: count,
        boardType: BoardType.double_,
        game: game,
        auth: auth,
      ),
    )).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIPLE  (000–999 paged 10×10)
// ─────────────────────────────────────────────────────────────────────────────
class GridTriple extends StatelessWidget {
  const GridTriple({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameProvider, AuthProvider>(
      builder: (_, game, auth, __) => LayoutBuilder(
        builder: (_, outer) => _TripleBody(
          game: game,
          auth: auth,
          availW: outer.maxWidth,
          availH: outer.maxHeight,
        ),
      ),
    );
  }
}

class _TripleBody extends StatelessWidget {
  final GameProvider game;
  final AuthProvider auth;
  final double availW;
  final double availH;

  const _TripleBody({
    required this.game,
    required this.auth,
    required this.availW,
    required this.availH,
  });

  static const _tripleRandomCounts = [5, 10, 15, 20, 25, 50, 100];
  static const _tabH     = 24.0;
  static const _rowArrW  = 28.0;
  static const _chipBtnW = 36.0;
  static const _colArrH  = 26.0;
  static const _gap      = 2.0;

  @override
  Widget build(BuildContext context) {
    final gridAvailW = availW - _rowArrW - _chipBtnW - _gap * 2;
    final gridAvailH = availH - _tabH - _colArrH - _gap * 2;

    final cs       = min(gridAvailW / 10, gridAvailH / 10);
    final gridW    = cs * 10;
    final gridH    = cs * 10;
    final fontSize = cs * 0.26;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Page tabs ──────────────────────────────────────────────────
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _rowArrW + _gap + gridW,
            height: _tabH,
            child: Row(
              children: [
                const SizedBox(width: _rowArrW + _gap),
                ...List.generate(10, (p) => Expanded(
                  child: GestureDetector(
                    onTap: () => game.setTriplePage(p, auth),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: game.triplePage == p
                          ? const LinearGradient(
                              colors: [Color(0xFFFFEE66), Color(0xFFCC8800)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF440800), Color(0xFF1A0000)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: game.triplePage == p
                            ? AppColors.goldBright
                            : const Color(0xFF661100),
                          width: game.triplePage == p ? 1.5 : 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (p * 100).toString().padLeft(3, '0'),
                          style: GoogleFonts.oswald(
                            fontWeight: FontWeight.w700,
                            fontSize: 10, // slightly larger and cleaner in Oswald
                            height: 1.0,
                            color: game.triplePage == p
                              ? const Color(0xFF2A1000)
                              : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: _gap),

        // ── Row: [row arrows] [grid] [chip buttons] ────────────────────
        SizedBox(
          height: gridH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left row arrows
              SizedBox(
                width: _rowArrW,
                child: Column(
                  children: List.generate(10, (row) => SizedBox(
                    height: cs,
                    child: RowArrowButton(
                      rowIndex: row,
                      boardType: BoardType.triple,
                      game: game,
                      auth: auth,
                    ),
                  )),
                ),
              ),
              const SizedBox(width: _gap),

              // Grid with gold frame
              Container(
                width: gridW,
                height: gridH,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D1A00),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.goldPrimary, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 10,
                    childAspectRatio: 1,
                    crossAxisSpacing: 0,
                    mainAxisSpacing: 0,
                  ),
                  itemCount: 100,
                  itemBuilder: (_, i) {
                    final base = game.triplePage * 100;
                    final num  = (base + i).toString().padLeft(3, '0');
                    return NumberCell(
                      number: num,
                      stakedAmount: game.board.triple[num],
                      isEven: ((i ~/ 10) + (i % 10)) % 2 == 0,
                      onTap: () => game.activeChip != null
                          ? game.placeBet(BoardType.triple, num, auth)
                          : game.removeChipFromCell(BoardType.triple, num, auth),
                      fontSize: fontSize,
                    );
                  },
                ),
              ),
              const SizedBox(width: _gap),

              // Right random buttons
              SizedBox(
                width: _chipBtnW,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _tripleRandomCounts.map((count) => Expanded(
                    child: RandomShortcutButton(
                      count: count,
                      boardType: BoardType.triple,
                      game: game,
                      auth: auth,
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),

        // ── Bottom column arrows ────────────────────────────────────────
        SizedBox(
          height: _colArrH,
          child: Row(
            children: [
              const SizedBox(width: _rowArrW + _gap),
              ...List.generate(10, (col) => SizedBox(
                width: cs,
                child: ColArrowButton(
                  colIndex: col,
                  boardType: BoardType.triple,
                  game: game,
                  auth: auth,
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

