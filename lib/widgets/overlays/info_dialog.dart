import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/history_provider.dart';
import '../../models/spin_result_model.dart';
import '../../theme/app_colors.dart';
// ignore: unused_import
import '../../theme/app_text_styles.dart';
import '../../services/sound_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INFO DIALOG  ·  Entry point
// ─────────────────────────────────────────────────────────────────────────────
class InfoDialog extends StatefulWidget {
  const InfoDialog({super.key});

  static void show(BuildContext context) {
    SoundService().playNotification();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Info',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const InfoDialog(),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  @override
  State<InfoDialog> createState() => _InfoDialogState();
}

class _InfoDialogState extends State<InfoDialog>
    with SingleTickerProviderStateMixin {
  final List<String> _tabs = ['HISTORY', 'PAYOUT', 'RULES'];
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isLoggedIn) {
        Provider.of<HistoryProvider>(context, listen: false)
            .loadFirstPage(auth.token, userId: auth.user?.id, since: auth.sessionStartAt);
      }
    });
  }

  void _switchTab(int idx) {
    if (_tabIndex == idx) return;
    SoundService().playButtonClick();
    setState(() => _tabIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    final dialogW = (size.width * 0.92).clamp(300.0, 620.0);
    final dialogH = isLandscape
        ? (size.height * 0.88).clamp(260.0, 420.0)
        : (size.height * 0.62).clamp(360.0, 560.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 20 : 14,
        vertical: isLandscape ? 8 : 20,
      ),
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Blur
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const SizedBox.expand(),
              ),
            ),
            // Body
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E0400),
                    Color(0xFF0C0000),
                    Color(0xFF1a0200),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: AppColors.goldPrimary.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldPrimary.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Colors.black87,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Gold shimmer top strip
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.goldBright.withValues(alpha: 0.9),
                          AppColors.goldBright,
                          AppColors.goldBright.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                  // Tab bar
                  _buildTabBar(),
                  // Separator
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.goldPrimary.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Content with fade+slide animation
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_tabIndex),
                          child: _buildTabContent(),
                        ),
                      ),
                    ),
                  ),
                  // Close button
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: _CloseButton(onTap: () {
                      SoundService().playButtonClick();
                      Navigator.of(context).pop();
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: List.generate(_tabs.length, (idx) {
          final isActive = _tabIndex == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isActive
                      ? AppColors.goldPrimary.withValues(alpha: 0.13)
                      : Colors.transparent,
                  border: Border.all(
                    color: isActive
                        ? AppColors.goldBright.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.07),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tabs[idx],
                      style: GoogleFonts.oswald(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isActive
                            ? AppColors.goldBright
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 2,
                      width: isActive ? 32 : 0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [AppColors.goldGlow, AppColors.goldBright],
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.goldBright
                                      .withValues(alpha: 0.55),
                                  blurRadius: 6,
                                )
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 1:
        return const _PayoutTab();
      case 2:
        return const _RulesTab();
      default:
        return const _HistoryTab();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLOSE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 140,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0xFF2C7D00), const Color(0xFF1a4a00)]
                  : [const Color(0xFF5dbb00), const Color(0xFF2C7D00)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.goldPrimary.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5dbb00).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'CLOSE',
              style: GoogleFonts.oswald(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final history = Provider.of<HistoryProvider>(context);
    final game = Provider.of<GameProvider>(context, listen: false);

    final displayRecords = history.records.isNotEmpty ? history.records : game.spinHistory;

    if (!auth.isLoggedIn) {
      return const _EmptyState(
          icon: Icons.lock_outline,
          message: 'Please log in to view history');
    }

    if (history.isLoading && displayRecords.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                color: AppColors.goldPrimary, strokeWidth: 2),
            SizedBox(height: 12),
            Text('Loading session history…',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      );
    }

    if (history.error != null && displayRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: Colors.white30, size: 32),
            const SizedBox(height: 8),
            Text(history.error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 12)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                history.loadFirstPage(auth.token, userId: auth.user?.id, since: auth.sessionStartAt);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: AppColors.goldPrimary, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Retry',
                    style: GoogleFonts.oswald(
                        color: AppColors.goldBright, fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(children: [

      // Table header
      Container(
        height: 30,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3a0800), Color(0xFF1a0000)],
          ),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(8)),
          border:
              Border.all(color: AppColors.goldDark.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          _HeaderCell('S.No', 8),
          _vDiv(),
          _HeaderCell('Hand ID', 18),
          _vDiv(),
          _HeaderCell('PLAY', 10),
          _vDiv(),
          _HeaderCell('WIN', 10),
        ]),
      ),

      // Rows
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0a0000).withValues(alpha: 0.6),
            border: Border.all(
                color: AppColors.goldDark.withValues(alpha: 0.35)),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: displayRecords.isEmpty
              ? const _EmptyState(
                  icon: Icons.history_toggle_off,
                  message: 'No rounds in this session yet')
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: displayRecords.length,
                        itemBuilder: (_, i) {
                          final item = displayRecords[i];
                          final sno = i + 1;
                          return _HistoryRow(
                            record: item,
                            serialNo: sno,
                            onTap: () =>
                                _showDetailDialog(context, item, sno),
                          );
                        },
                      ),
                    ),
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a0000).withValues(alpha: 0.8),
                        border: Border(
                          top: BorderSide(
                            color: AppColors.goldDark.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 3), // Match colored strip width
                          Expanded(
                            flex: 26,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'TOTAL SESSION:',
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    color: AppColors.textGoldLight.withValues(alpha: 0.85),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, color: AppColors.goldDark.withValues(alpha: 0.3)),
                          Expanded(
                            flex: 10,
                            child: Center(
                              child: Text(
                                '${history.totalPlay}',
                                style: const TextStyle(
                                  fontFamily: 'Oswald',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.goldBright,
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, color: AppColors.goldDark.withValues(alpha: 0.3)),
                          Expanded(
                            flex: 10,
                            child: Center(
                              child: Text(
                                history.totalWin > 0 ? '+${history.totalWin}' : '0',
                                style: TextStyle(
                                  fontFamily: 'Oswald',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: history.totalWin > 0
                                      ? const Color(0xFF44D680)
                                      : Colors.white30,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),

    ]);
  }

  Widget _vDiv() =>
      Container(width: 1, color: AppColors.goldDark.withValues(alpha: 0.3));

  void _showDetailDialog(
      BuildContext context, SpinResult record, int serialNo) {
    SoundService().playNotification();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'HistoryDetail',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) =>
          _HistoryDetailDialog(record: record, serialNo: serialNo),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }
}

// ── History Row ───────────────────────────────────────────────────────────────
class _HistoryRow extends StatefulWidget {
  final SpinResult record;
  final int serialNo;
  final VoidCallback onTap;
  const _HistoryRow(
      {required this.record,
      required this.serialNo,
      required this.onTap});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isWin = widget.record.winAmount > 0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.goldPrimary.withValues(alpha: 0.09)
              : (widget.serialNo.isEven
                  ? const Color(0xFF120000).withValues(alpha: 0.5)
                  : Colors.transparent),
          border: const Border(
              bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isWin
                        ? [
                            const Color(0xFF44D680),
                            const Color(0xFF27ae60)
                          ]
                        : [
                            const Color(0xFF8B0000),
                            const Color(0xFF550000)
                          ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              _BodyCell(
                  text: '${widget.serialNo}',
                  flex: 8,
                  color: Colors.white54,
                  bold: false,
                  center: true),
              Container(width: 1, color: Colors.white10),
              _BodyCell(
                  text: _shortenId(widget.record.id),
                  flex: 18,
                  color: Colors.white60,
                  bold: false),
              Container(width: 1, color: Colors.white10),
              _BodyCell(
                  text: '${widget.record.deductedAmount}',
                  flex: 10,
                  color: AppColors.goldGlow,
                  bold: true,
                  center: true),
              Container(width: 1, color: Colors.white10),
              _BodyCell(
                  text: isWin
                      ? '+${widget.record.winAmount}'
                      : '0',
                  flex: 10,
                  color: isWin
                      ? const Color(0xFF44D680)
                      : Colors.white30,
                  bold: isWin,
                  center: true),
            ],
          ),
        ),
      ),
    );
  }

  String _shortenId(String id) {
    if (id.length <= 8) return id;
    return '...${id.substring(id.length - 8)}';
  }
}

// ── Cell widgets ──────────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, this.flex);

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Center(
          child: Text(text,
              style: GoogleFonts.oswald(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textGoldLight.withValues(alpha: 0.9),
                letterSpacing: 0.8,
              )),
        ),
      );
}

class _BodyCell extends StatelessWidget {
  final String text;
  final int flex;
  final Color color;
  final bool bold;
  final bool center;
  const _BodyCell({
    required this.text,
    required this.flex,
    required this.color,
    required this.bold,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: GoogleFonts.oswald(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ),
      );
}



// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.2), size: 36),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY DETAIL DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryDetailDialog extends StatelessWidget {
  final SpinResult record;
  final int serialNo;
  const _HistoryDetailDialog(
      {required this.record, required this.serialNo});

  @override
  Widget build(BuildContext context) {
    final isWin = record.winAmount > 0;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF220500), Color(0xFF0C0200)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(
                  color: AppColors.goldPrimary.withValues(alpha: 0.45),
                  width: 1.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldPrimary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Colors.black87,
                  blurRadius: 25,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.goldGlow, AppColors.goldPrimary]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('ROUND #$serialNo',
                    style: GoogleFonts.oswald(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  SoundService().playButtonClick();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white54, size: 14),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWin
                      ? [
                          const Color(0xFF27ae60).withValues(alpha: 0.2),
                          const Color(0xFF44D680).withValues(alpha: 0.08)
                        ]
                      : [
                          const Color(0xFF8B0000).withValues(alpha: 0.2),
                          const Color(0xFF550000).withValues(alpha: 0.08)
                        ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWin
                      ? const Color(0xFF44D680).withValues(alpha: 0.4)
                      : const Color(0xFF8B0000).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      isWin
                          ? Icons.emoji_events
                          : Icons.sentiment_dissatisfied_rounded,
                      color: isWin
                          ? const Color(0xFF44D680)
                          : Colors.redAccent,
                      size: 18),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      children: isWin
                          ? [
                              const TextSpan(
                                text: 'WIN  ',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF44D680),
                                ),
                              ),
                              TextSpan(
                                text: '+${record.winAmount}',
                                style: const TextStyle(
                                  fontFamily: 'Oswald',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF44D680),
                                ),
                              ),
                              const TextSpan(
                                text: ' coins',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF44D680),
                                ),
                              ),
                            ]
                          : [
                              const TextSpan(
                                text: 'NO WIN',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow('Hand ID', record.id, color: Colors.white54),
            _DetailRow('Mode', record.modeLabel,
                color: AppColors.goldBright),
            _DetailRow('Result',
                '${record.red} . ${record.green} . ${record.black}',
                color: Colors.white70),
            _DetailRow('Total Bet', '${record.deductedAmount} coins',
                color: AppColors.goldGlow),
            _DetailRow('Total Win', '${record.winAmount} coins',
                color:
                    isWin ? const Color(0xFF44D680) : Colors.white30),
            if (record.selections.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Picks:',
                  style: GoogleFonts.oswald(
                      fontSize: 11,
                      color: Colors.white38,
                      letterSpacing: 0.5)),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: record.selections
                    .map((sel) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: AppColors.goldDark, width: 1),
                            color: AppColors.goldPrimary
                                .withValues(alpha: 0.06),
                          ),
                          child: Text(sel,
                              style: GoogleFonts.oswald(
                                  fontSize: 11,
                                  color: AppColors.goldBright)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _DetailRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    Widget valueWidget;
    if (label == 'Mode') {
      valueWidget = Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 11,
          color: color ?? Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (label == 'Total Bet' || label == 'Total Win') {
      final parts = value.split(' ');
      final amount = parts[0];
      final suffix = parts.length > 1 ? ' ${parts[1]}' : '';
      valueWidget = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: amount,
              style: TextStyle(
                fontFamily: 'Oswald',
                fontSize: 11,
                color: color ?? Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: suffix,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                color: color ?? Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (label == 'Result') {
      valueWidget = Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Oswald',
          fontSize: 11,
          color: color ?? Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      valueWidget = Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 11,
          color: color ?? Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 80,
          child: Text('$label:',
              style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  color: Colors.white30,
                  letterSpacing: 0.3)),
        ),
        Expanded(child: valueWidget),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYOUT TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PayoutTab extends StatelessWidget {
  const _PayoutTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 4),
          _SectionTitle(title: 'Game Play Payout'),
          SizedBox(height: 8),
          _PayoutCard(
            ringColor: Color(0xFF1a4a1a),
            ringBorder: Color(0xFF44aa44),
            ringLabel: 'INNER WHEEL',
            mode: 'Singles Play',
            desc: 'Play 10 chips on a single number',
            payout: '90',
          ),
          SizedBox(height: 6),
          _PayoutCard(
            ringColor: Color(0xFF002244),
            ringBorder: Color(0xFF4488cc),
            ringLabel: 'MIDDLE WHEEL',
            mode: 'Doubles Play',
            desc: 'Play 10 chips on a single number',
            payout: '900',
          ),
          SizedBox(height: 6),
          _PayoutCard(
            ringColor: Color(0xFF4a0000),
            ringBorder: Color(0xFFcc4444),
            ringLabel: 'OUTER WHEEL',
            mode: 'Triples Play',
            desc: 'Play 10 chips on a single number',
            payout: '9000',
          ),
          SizedBox(height: 16),
          _SectionTitle(title: 'Play Limits'),
          SizedBox(height: 8),
          _LimitTable(),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.goldGlow, AppColors.goldBright],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  color: AppColors.goldBright.withValues(alpha: 0.45),
                  blurRadius: 6)
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.oswald(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.goldBright,
                letterSpacing: 0.5)),
      ]);
}

class _PayoutCard extends StatelessWidget {
  final Color ringColor;
  final Color ringBorder;
  final String ringLabel;
  final String mode;
  final String desc;
  final String payout;
  const _PayoutCard({
    required this.ringColor,
    required this.ringBorder,
    required this.ringLabel,
    required this.mode,
    required this.desc,
    required this.payout,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ringColor.withValues(alpha: 0.35),
              const Color(0xFF0a0000)
            ],
          ),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: ringBorder.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: ringBorder.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: ringBorder.withValues(alpha: 0.5), width: 1),
            ),
            child: Text(ringLabel,
                style: GoogleFonts.oswald(
                    fontSize: 8,
                    color: ringBorder,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode,
                    style: GoogleFonts.oswald(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(desc,
                    style: GoogleFonts.oswald(
                        fontSize: 9,
                        color: Colors.white38,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(payout,
                style: GoogleFonts.oswald(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.goldBright,
                  shadows: [
                    Shadow(
                        color:
                            AppColors.goldBright.withValues(alpha: 0.4),
                        blurRadius: 10)
                  ],
                )),
            Text('pts',
                style: GoogleFonts.oswald(
                    fontSize: 8,
                    color: Colors.white30,
                    letterSpacing: 0.5)),
          ]),
        ]),
      );
}

class _LimitTable extends StatelessWidget {
  const _LimitTable();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: AppColors.goldDark.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          _LimitHeader(),
          const _LimitRow('Singles Play', '2', '10,000', border: true),
          const _LimitRow('Doubles Play', '2', '1,000', border: true),
          const _LimitRow('Triples Play', '2', '100', border: false),
        ]),
      );
}

class _LimitHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF1a0300),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(8)),
          border: Border(
              bottom: BorderSide(
                  color: Color(0xFF5a3f00), width: 0.8)),
        ),
        child: Row(children: [
          Expanded(flex: 3, child: Text('Play', style: _hStyle())),
          Expanded(
              flex: 2,
              child: Text('Min',
                  textAlign: TextAlign.center, style: _hStyle())),
          Expanded(
              flex: 2,
              child: Text('Max',
                  textAlign: TextAlign.center, style: _hStyle())),
        ]),
      );

  TextStyle _hStyle() => const TextStyle(
      fontFamily: 'DMSans',
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.textGoldLight,
      letterSpacing: 0.8);
}

class _LimitRow extends StatelessWidget {
  final String play;
  final String min;
  final String max;
  final bool border;
  const _LimitRow(this.play, this.min, this.max,
      {required this.border});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          border: border
              ? const Border(
                  bottom: BorderSide(
                      color: Colors.white10, width: 0.5))
              : null,
        ),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: Text(play,
                  style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      color: Colors.white70))),
          Expanded(
              flex: 2,
              child: Text(min,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Oswald',
                      fontSize: 11,
                      color: Colors.white38))),
          Expanded(
              flex: 2,
              child: Text(max,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Oswald',
                      fontSize: 12,
                      color: AppColors.goldGlow,
                      fontWeight: FontWeight.w700))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// RULES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _RulesTab extends StatelessWidget {
  const _RulesTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 4),
          _SectionTitle(title: 'Game Play Rules'),
          SizedBox(height: 10),
          _RuleCard(
            icon: Icons.rotate_90_degrees_cw_outlined,
            text:
                'Triple Chance has 3 wheels: outer, middle and inner. Each wheel has numbers 0-9 placed at equal intervals.',
          ),
          SizedBox(height: 6),
          _RuleCard(
            icon: Icons.stop_circle_outlined,
            text:
                'In every game the 3 wheels rotate in opposite directions. When they stop, the result is displayed and payout is calculated.',
          ),
          SizedBox(height: 12),
          _WheelImage(),
          SizedBox(height: 12),
          _RuleCard(
            icon: Icons.touch_app_outlined,
            text:
                'Place chips on any wheel:\n- Inner wheel = Singles play (0-9)\n- Middle wheel = Doubles play (00-99)\n- Outer wheel = Triples play (000-999)',
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WheelImage extends StatelessWidget {
  const _WheelImage();

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/rules_wheel.webp',
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.goldPrimary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.goldDark.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.broken_image,
                color: AppColors.goldPrimary, size: 36),
          ),
        ),
      );
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _RuleCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.goldPrimary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
                color: AppColors.goldGlow.withValues(alpha: 0.55),
                width: 3),
            top: BorderSide(
                color: AppColors.goldPrimary.withValues(alpha: 0.12),
                width: 0.5),
            bottom: BorderSide(
                color: AppColors.goldPrimary.withValues(alpha: 0.12),
                width: 0.5),
            right: BorderSide(
                color: AppColors.goldPrimary.withValues(alpha: 0.12),
                width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.goldGlow, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.white70,
                      height: 1.5)),
            ),
          ],
        ),
      );
}
