import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/sound_service.dart';
import '../../theme/app_colors.dart';
import 'popup_scale.dart';

/// True while the NO INTERNET popup is up. The Windows close path reads it: the
/// popup cannot be dismissed, so closing the window must not wait for it.
final ValueNotifier<bool> noInternetShowing = ValueNotifier(false);

/// Shows the NO INTERNET popup, in the look of showActionDialog but with no
/// button: it cannot be dismissed, and it goes when the connection returns.
/// Returns the popup's route, for [closeNoInternet].
Route<void> showNoInternet(BuildContext context) {
  SoundService().playNotification();
  final scale = popupScaleFor(MediaQuery.of(context).size);
  final route = RawDialogRoute<void>(
    barrierDismissible: false,
    barrierLabel: 'NoInternet',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => PopScope(
      canPop: false,
      child: Transform.scale(scale: scale, child: const _NoInternetCard()),
    ),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
  noInternetShowing.value = true;
  Navigator.of(context).push(route);
  return route;
}

/// Takes the popup away, wherever it sits among the open routes.
void closeNoInternet(Route<void> route) {
  noInternetShowing.value = false;
  if (route.isActive) route.navigator?.removeRoute(route);
}

class _NoInternetCard extends StatelessWidget {
  const _NoInternetCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            key: const ValueKey('no-internet-popup'),
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF220500), Color(0xFF0C0200)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.goldPrimary.withValues(alpha: 0.45), width: 1.5),
              boxShadow: [
                BoxShadow(color: AppColors.goldPrimary.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: 1),
                const BoxShadow(color: Colors.black87, blurRadius: 25, offset: Offset(0, 10)),
              ],
            ),
            child: const Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Color(0xFFFFD54F), size: 48),
                  SizedBox(height: 12),
                  Text(
                    'NO INTERNET',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFFFFD54F),
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Please check your connection. Reconnecting automatically...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
