import 'package:flutter/material.dart';
import '../../theme/app_decorations.dart';
import '../controls/right_panel.dart';
import 'tablet_chip_row.dart';

/// The control panel of the tablet game screen: the same parts as the phone's
/// `RightControlPanel`, in tablet positions. Laid out at the phone panel's
/// design width and drawn enlarged by `TabletGameLayout`.
///
/// Top to bottom: play / win / balance, the history grid (taller cells than
/// the phone), the chips in a row, then the action buttons and the countdown
/// box. (The status message is the pill above the wheel, not a bar here.)
/// Tablet phases that follow arrange the buttons as a 2 x 2 block and enlarge
/// the countdown box.
class TabletRightPanel extends StatelessWidget {
  final VoidCallback onSpin;
  const TabletRightPanel({super.key, required this.onSpin});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.rightPanel,
      child: Column(
        children: [
          RightPanelParts.stats(),
          RightPanelParts.history(cellHeight: 16, fontSize: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TabletChipRow(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: RightPanelParts.actions(onSpin),
            ),
          ),
        ],
      ),
    );
  }
}
