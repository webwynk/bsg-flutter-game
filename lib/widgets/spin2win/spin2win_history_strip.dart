// The Spin2Win history strip along the bottom, as the reference design draws it: a "HISTORY"
// label, then the last ten results as tiles in the winning number's colour, each with its bonus
// (N, 2x, 3x, 4x) on a bar along the bottom. The newest is at the left, ringed in gold, and pops in
// when a new result arrives (the design's `newtile`).
//
// Given the results to show, nothing else: no provider.
//
// Belongs to Spin2Win only.

import 'package:flutter/widgets.dart';

import 'spin2win_bump.dart';
import 'spin2win_palette.dart';

/// One result on the strip.
class Spin2WinHistoryTile {
  const Spin2WinHistoryTile({required this.number, required this.bonusMultiplier, this.roundId});

  final int number;
  final int bonusMultiplier;

  /// The round it came from; a new round in the newest place makes that tile pop in.
  final String? roundId;
}

class Spin2WinHistoryStrip extends StatelessWidget {
  const Spin2WinHistoryStrip({super.key, required this.tiles});

  /// Newest first. Only the first [slots] are shown; missing ones leave their place empty.
  final List<Spin2WinHistoryTile> tiles;

  static const int slots = 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kS2wGoldBorder, width: 2),
        gradient: kS2wStripFill,
        boxShadow: const [
          BoxShadow(color: kS2wGoldUnder, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x8C000000), offset: Offset(0, 6), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0x80FFB52E)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF02081C), kS2wNavyWell],
                stops: [0, .3],
              ),
            ),
            child: const Text(
              'HISTORY',
              style: TextStyle(
                fontFamily: kSpin2WinFont,
                fontWeight: FontWeight.w900,
                fontSize: 17,
                height: 1,
                letterSpacing: 1,
                color: kS2wGold,
                shadows: [
                  Shadow(color: Color(0x99000000), offset: Offset(0, 2)),
                  Shadow(color: Color(0x80FFB52E), blurRadius: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < slots; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: i >= tiles.length
                        ? const SizedBox(height: 42)
                        : i == 0
                            ? Spin2WinPopIn(
                                popKey: tiles[0].roundId,
                                child: _Tile(key: const ValueKey('spin2win-history-0'), tile: tiles[0], newest: true),
                              )
                            : _Tile(key: ValueKey('spin2win-history-$i'), tile: tiles[i], newest: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.tile, required this.newest});

  final Spin2WinHistoryTile tile;
  final bool newest;

  @override
  Widget build(BuildContext context) {
    final shades = spin2WinShades(tile.number);
    final hasBonus = tile.bonusMultiplier > 1;
    final bonus = spin2WinBonusShades(tile.bonusMultiplier);
    return Semantics(
      label: '${tile.number}, bonus ${spin2WinBonusText(tile.bonusMultiplier)}',
      excludeSemantics: true,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: shades.edge, width: 2),
          gradient: shades.face,
          boxShadow: [
            if (newest) const BoxShadow(color: Color(0xCCFFD45A), blurRadius: 14),
            BoxShadow(color: shades.under, offset: const Offset(0, 3)),
            const BoxShadow(color: Color(0x80000000), offset: Offset(0, 5), blurRadius: 8),
            if (newest) const BoxShadow(color: kS2wGold, spreadRadius: 2),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: CustomPaint(
            painter: const Spin2WinGlossPainter(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Center(child: Spin2WinOutlinedText('${tile.number}', size: 20, height: 1))),
                Container(
                  height: 13,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: const Border(top: BorderSide(color: Color(0xBFFFFFFF))),
                    gradient: hasBonus
                        ? bonus.fill
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF22365F), Color(0xFF0D1A38)],
                          ),
                  ),
                  child: Spin2WinOutlinedText(
                    spin2WinBonusText(tile.bonusMultiplier),
                    size: 10,
                    height: 1,
                    color: hasBonus ? const Color(0xFFFFFFFF) : const Color(0xFF8FA2C8),
                    stroke: const Color(0xB30A061E),
                    strokeWidth: 1.5,
                    shadows: const [],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
