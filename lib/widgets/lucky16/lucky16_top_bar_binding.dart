// Connects the Lucky 16 Card header ([Lucky16TopBar]) to the game's provider.
//
// Copied from the header half of lib/widgets/lucky_card/lucky_card_readouts_binding.dart and
// lib/widgets/lucky_card/lucky_card_status_strip.dart (Lucky Card); only the names changed.
//
// The provider notifies for every chip, every second of the countdown and every step of a result.
// The binding reads only what the header shows into a small value and redraws only when that value
// changes, so the countdown's tick redraws the header and nothing else.
//
// What the header shows, read from the provider:
//   * the balance ([Lucky16Provider.balance]) and the countdown ([Lucky16Provider.countdown]);
//   * the words in the middle: "PLACE YOUR CHIPS" while betting is open, "NO MORE PLAY" (red)
//     once it closes -- flashing in the last five seconds -- and steady while the round is drawn,
//     spun and shown. A refused tap borrows the same spot for a moment, in amber ([Lucky16Notice]);
//   * whether HISTORY and INFO may be used: only while betting is open and nothing is playing.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../providers/lucky16_provider.dart';
import 'lucky16_art.dart';
import 'lucky16_layout.dart';
import 'lucky16_messages.dart';
import 'lucky16_palette.dart';
import 'lucky16_top_bar.dart';

/// What the table is doing, in words.
enum Lucky16StatusMode {
  /// Betting is open.
  placeChips,

  /// Betting has just closed: the last seconds, flashing.
  noMoreFlashing,

  /// Betting is closed and the round is being drawn, spun and shown.
  noMoreSteady,
}

/// The words of each mode.
String lucky16StatusText(Lucky16StatusMode mode) =>
    mode == Lucky16StatusMode.placeChips ? 'PLACE YOUR CHIPS' : 'NO MORE PLAY';

/// Which words the header shows right now.
Lucky16StatusMode lucky16StatusModeOf(Lucky16Provider provider) {
  if (provider.isSequenceRunning || provider.stage != Lucky16Stage.none) {
    return Lucky16StatusMode.noMoreSteady;
  }
  if (!provider.isLocked) return Lucky16StatusMode.placeChips;
  return lucky16CountdownUrgent(provider.countdown) ? Lucky16StatusMode.noMoreFlashing : Lucky16StatusMode.noMoreSteady;
}

/// HISTORY and INFO work only while betting is open and nothing is playing.
bool lucky16InfoEnabledOf(Lucky16Provider provider) => !provider.isLocked && !provider.isSequenceRunning;

/// The words in the middle of the header, their colour and whether they flash: white while betting
/// is open, red once it has closed, flashing in the last five seconds. A refusal line is shown in amber
/// while betting is open; a line about the balance is important enough to be shown once it has closed.
({String text, Color color, bool isFlashing}) lucky16HeaderStatus(
  Lucky16StatusMode mode, {
  String? notice,
  bool noticeImportant = false,
}) {
  final closed = mode != Lucky16StatusMode.placeChips;
  final showNotice = notice != null && (!closed || noticeImportant);
  return (
    text: showNotice ? notice : lucky16StatusText(mode),
    color: showNotice ? kLucky16NoticeText : (closed ? kLucky16AlertText : kLucky16StatusText),
    isFlashing: mode == Lucky16StatusMode.noMoreFlashing,
  );
}

/// What the header shows apart from its words (kept apart on purpose: see [_Lucky16HeaderStatusSlot]).
@immutable
class Lucky16TopBarSnapshot {
  const Lucky16TopBarSnapshot({required this.balance, required this.countdown, required this.infoEnabled});

  factory Lucky16TopBarSnapshot.of(Lucky16Provider p) =>
      Lucky16TopBarSnapshot(balance: p.balance, countdown: p.countdown, infoEnabled: lucky16InfoEnabledOf(p));

  final int balance;
  final int countdown;
  final bool infoEnabled;

  @override
  bool operator ==(Object other) =>
      other is Lucky16TopBarSnapshot &&
      other.balance == balance &&
      other.countdown == countdown &&
      other.infoEnabled == infoEnabled;

  @override
  int get hashCode => Object.hash(balance, countdown, infoEnabled);
}

/// Listens to [provider], reduces it to a [T] with [select], and rebuilds only when the [T] changes.
class Lucky16Selector<T> extends StatefulWidget {
  const Lucky16Selector({super.key, required this.provider, required this.select, required this.builder});

  final Lucky16Provider provider;
  final T Function(Lucky16Provider provider) select;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<Lucky16Selector<T>> createState() => _Lucky16SelectorState<T>();
}

class _Lucky16SelectorState<T> extends State<Lucky16Selector<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.select(widget.provider);
    widget.provider.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(Lucky16Selector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_onChanged);
      widget.provider.addListener(_onChanged);
    }
    _value = widget.select(widget.provider);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.select(widget.provider);
    if (next != _value) setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

/// The header, linked to the provider. [soundOn], the four callbacks and the [notice] come from the
/// screen.
class Lucky16TopBarBinding extends StatelessWidget {
  const Lucky16TopBarBinding({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    required this.soundOn,
    this.bleed = EdgeInsets.zero,
    this.onExit,
    this.onToggleSound,
    this.onInfo,
    this.onHistory,
    this.notice,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;
  final bool soundOn;

  /// The one-line refusal or warning, shown in place of the round's status for as long as it lasts.
  final Lucky16Notice? notice;

  /// The phone's safe-area insets, which the bar's paint reaches into (see [Lucky16TopBar.bleed]).
  final EdgeInsets bleed;
  final VoidCallback? onExit;
  final VoidCallback? onToggleSound;
  final VoidCallback? onInfo;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    // Built once here, not inside the selector's builder below, so the words keep their own element
    // (and their flashing) across every balance or countdown rebuild of the rest of the header.
    final statusWidget = _Lucky16HeaderStatusSlot(provider: provider, layout: layout, notice: notice);
    return Lucky16Selector<Lucky16TopBarSnapshot>(
      provider: provider,
      select: Lucky16TopBarSnapshot.of,
      builder: (context, s) => Lucky16TopBar(
        layout: layout,
        art: art,
        bleed: bleed,
        balance: s.balance,
        countdown: s.countdown,
        soundOn: soundOn,
        infoEnabled: s.infoEnabled,
        statusWidget: statusWidget,
        onExit: onExit,
        onToggleSound: onToggleSound,
        onInfo: onInfo,
        onHistory: onHistory,
      ),
    );
  }
}

/// The header's words, read and redrawn independently of everything else in the bar.
class _Lucky16HeaderStatusSlot extends StatelessWidget {
  const _Lucky16HeaderStatusSlot({required this.provider, required this.layout, this.notice});

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Notice? notice;

  @override
  Widget build(BuildContext context) {
    return Lucky16Selector<Lucky16StatusMode>(
      provider: provider,
      select: lucky16StatusModeOf,
      builder: (context, mode) {
        Widget line(({String text, Color color, bool isFlashing}) status) => Lucky16StatusLine(
              key: const ValueKey('top-status'),
              text: status.text,
              size: layout.designStatusFont,
              color: status.color,
              flashing: status.isFlashing,
            );
        final notice = this.notice;
        if (notice == null) return line(lucky16HeaderStatus(mode));
        return ListenableBuilder(
          listenable: notice,
          builder: (context, _) =>
              line(lucky16HeaderStatus(mode, notice: notice.text, noticeImportant: notice.important)),
        );
      },
    );
  }
}
