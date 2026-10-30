import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'change_password_form.dart';

/// The wide change-password popup for tablets and desktops: a header, then the
/// password rules on the left and the form on the right. All behaviour lives in
/// [ChangePasswordForm], shared with the phone popup; this only draws it.
///
/// 780 wide on a tablet and about 1.4 times that on a desktop, narrower only if
/// the window is. It sits above the on-screen keyboard and scrolls when short
/// of room, because this popup, unlike the phone's, stays in landscape.
class SecurityWideDialog extends StatelessWidget {
  final ChangePasswordForm form;
  final String username;
  final bool desktop;
  final VoidCallback onClose;
  final VoidCallback onLogout;

  const SecurityWideDialog({
    super.key,
    required this.form,
    required this.username,
    required this.desktop,
    required this.onClose,
    required this.onLogout,
  });

  static const double baseWidth = 780;
  static const _gold = Color(0xFFFFD700);
  static const _goldBorder = Color(0xFFD4AF37);

  /// The size multiplier for a popup in a window [screenWidth] wide.
  static double scaleFor(double screenWidth, {required bool desktop}) =>
      math.min(desktop ? 1.4 : 1.0, (screenWidth - 48) / baseWidth);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final s = scaleFor(media.size.width, desktop: desktop);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            key: const ValueKey('security-wide-dialog'),
            width: baseWidth * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24 * s),
              boxShadow: [
                BoxShadow(color: _goldBorder.withValues(alpha: 0.25), blurRadius: 28, spreadRadius: 1),
                const BoxShadow(color: Colors.black, blurRadius: 30, offset: Offset(0, 12)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24 * s),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E0502), Color(0xFF0D0201), Color(0xFF060100)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(24 * s),
                    border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1.5),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListenableBuilder(
                      listenable: form,
                      builder: (context, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _header(s),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _rulesColumn(s),
                                Expanded(child: _formColumn(s)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(double s) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 14 * s),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _goldBorder.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          Container(
            width: 38 * s,
            height: 38 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10 * s),
              border: Border.all(color: _goldBorder, width: 1.5),
              color: const Color(0xFF2A0800),
            ),
            child: Icon(Icons.lock_reset_rounded, color: _gold, size: 22 * s),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SECURITY & ACCOUNT',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w900,
                    fontSize: 15 * s,
                    color: _gold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 3 * s),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 1.5 * s),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6 * s),
                  ),
                  child: Text(
                    '@$username',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 10 * s,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            key: const ValueKey('security-close'),
            onTap: onClose,
            child: Container(
              width: 34 * s,
              height: 34 * s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10 * s),
                border: Border.all(color: _goldBorder, width: 1.2),
                color: const Color(0xFF330E08),
              ),
              child: Icon(Icons.close_rounded, color: _gold, size: 20 * s),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rulesColumn(double s) {
    Widget rule(String text) => Padding(
          padding: EdgeInsets.only(bottom: 10 * s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, color: _goldBorder, size: 16 * s),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      width: 300 * s,
      padding: EdgeInsets.all(24 * s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(right: BorderSide(color: _goldBorder.withValues(alpha: 0.25))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104 * s,
            height: 104 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _goldBorder, width: 2),
              gradient: RadialGradient(colors: [_goldBorder.withValues(alpha: 0.25), const Color(0xFF350500)]),
              boxShadow: [BoxShadow(color: _goldBorder.withValues(alpha: 0.25), blurRadius: 14)],
            ),
            child: Icon(Icons.lock_rounded, color: _gold, size: 48 * s),
          ),
          SizedBox(height: 16 * s),
          Text(
            'CHANGE PASSWORD',
            style: TextStyle(
              fontFamily: 'Oswald',
              fontWeight: FontWeight.w600,
              fontSize: 18 * s,
              color: _gold,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 16 * s),
          rule('At least 6 characters'),
          rule('Different from the current one'),
          rule('Both new entries must match'),
          SizedBox(height: 10 * s),
          _logoutButton(s),
        ],
      ),
    );
  }

  Widget _formColumn(double s) {
    return Padding(
      padding: EdgeInsets.all(24 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _field(s, 'CURRENT PASSWORD', form.currentPassword, form.obscureCurrent, form.toggleObscureCurrent),
          SizedBox(height: 12 * s),
          _field(s, 'NEW PASSWORD (MIN 6 CHARS)', form.newPassword, form.obscureNew, form.toggleObscureNew),
          SizedBox(height: 12 * s),
          _field(s, 'CONFIRM NEW PASSWORD', form.confirmPassword, form.obscureConfirm, form.toggleObscureConfirm),
          SizedBox(height: 16 * s),
          if (form.statusMessage != null) ...[
            _statusBox(s),
            SizedBox(height: 14 * s),
          ],
          _updateButton(s),
        ],
      ),
    );
  }

  Widget _field(
    double s,
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback onToggleObscure,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 11 * s,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: _goldBorder,
          ),
        ),
        SizedBox(height: 6 * s),
        Container(
          height: 42 * s,
          padding: EdgeInsets.symmetric(horizontal: 14 * s),
          decoration: BoxDecoration(
            color: const Color(0xFF140402),
            borderRadius: BorderRadius.circular(10 * s),
            border: Border.all(color: _goldBorder.withValues(alpha: 0.35)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13 * s,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 11 * s),
              suffixIcon: GestureDetector(
                onTap: onToggleObscure,
                child: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _goldBorder.withValues(alpha: 0.75),
                  size: 18 * s,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Same colours as the phone popup's status box.
  Widget _statusBox(double s) {
    final ok = form.isSuccess;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 9 * s),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFF003810) : const Color(0xFF380000),
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: ok ? const Color(0xFF00FF55) : const Color(0xFFFF5555)),
      ),
      child: Text(
        form.statusMessage!,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 11 * s,
          fontWeight: FontWeight.bold,
          color: ok ? const Color(0xFF88FFB0) : const Color(0xFFFF9999),
        ),
      ),
    );
  }

  Widget _updateButton(double s) {
    return GestureDetector(
      onTap: form.isSubmitting ? null : form.submit,
      child: Container(
        height: 46 * s,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: form.isSubmitting
                ? const [Color(0xFF554400), Color(0xFF332200)]
                : const [Color(0xFFFFE066), Color(0xFFD4AF37), Color(0xFF8B6914)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(color: _gold, width: 1.2),
          boxShadow: [BoxShadow(color: _goldBorder.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Center(
          child: form.isSubmitting
              ? SizedBox(
                  width: 18 * s,
                  height: 18 * s,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Text(
                  'UPDATE PASSWORD',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w900,
                    fontSize: 13 * s,
                    color: const Color(0xFF1E0400),
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }

  /// Not in the first design, but this popup is the only way to log out from
  /// the lobby, so it stays, same as on the phone.
  Widget _logoutButton(double s) {
    return GestureDetector(
      onTap: onLogout,
      child: Container(
        height: 38 * s,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE52E2E), Color(0xFF990000), Color(0xFF550000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(color: const Color(0xFFFFAAAA).withValues(alpha: 0.8), width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.white, size: 16 * s),
            SizedBox(width: 8 * s),
            Text(
              'LOGOUT ACCOUNT',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontWeight: FontWeight.w900,
                fontSize: 11 * s,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
