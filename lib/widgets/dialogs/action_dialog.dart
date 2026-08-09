import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/sound_service.dart';
import '../../theme/app_colors.dart';

/// Shared centered popup used across the app for single-action notices --
/// bet-rejection, connection-lost, and blocked-account dialogs all reuse
/// this instead of duplicating the same ~150-line card/icon/title/message/
/// button structure.
///
/// [onPressed] fires only on a manual tap, never on [autoDismissAfter]'s
/// silent timeout -- an auto-dismiss is "the player didn't need to see this
/// anymore," not "the player confirmed an action."
///
/// [barrierDismissible] also gates the system back button/gesture (via the
/// inner PopScope), not just tapping outside -- a dialog that must not be
/// skippable (e.g. connection-lost, account-blocked) needs both closed.
void showActionDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  VoidCallback? onPressed,
  String buttonLabel = 'OK',
  bool barrierDismissible = true,
  Duration? autoDismissAfter,
}) {
  bool isClosed = false;
  SoundService().playNotification();
  showGeneralDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'ActionDialog',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, anim1, anim2) {
      if (autoDismissAfter != null) {
        Future.delayed(autoDismissAfter, () {
          if (ctx.mounted && !isClosed && Navigator.of(ctx).canPop()) {
            isClosed = true;
            Navigator.of(ctx).pop();
          }
        });
      }

      return PopScope(
        canPop: barrierDismissible,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF220500), Color(0xFF0C0200)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.goldPrimary.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
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
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: const Color(0xFFFFD54F),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'DMSans',
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Color(0xFFFFD54F),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          if (!isClosed) {
                            isClosed = true;
                            SoundService().playButtonClick();
                            Navigator.of(ctx).pop();
                            onPressed?.call();
                          }
                        },
                        child: Container(
                          height: 38,
                          width: 140,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF99FF99), width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              buttonLabel,
                              style: const TextStyle(
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}
