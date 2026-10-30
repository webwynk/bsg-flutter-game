import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';

/// The state and rules of the change-password form, with no look of its own.
/// The phone popup and the wide tablet/desktop popup both draw from one of
/// these, so their checks, messages and success behaviour are the same code.
class ChangePasswordForm extends ChangeNotifier {
  final AuthProvider auth;

  /// Closes the popup, shortly after a successful change.
  final VoidCallback onClose;

  ChangePasswordForm({required this.auth, required this.onClose});

  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();

  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool isSubmitting = false;
  String? statusMessage;
  bool isSuccess = false;

  bool _disposed = false;

  void toggleObscureCurrent() {
    obscureCurrent = !obscureCurrent;
    notifyListeners();
  }

  void toggleObscureNew() {
    obscureNew = !obscureNew;
    notifyListeners();
  }

  void toggleObscureConfirm() {
    obscureConfirm = !obscureConfirm;
    notifyListeners();
  }

  void _fail(String message) {
    statusMessage = message;
    isSuccess = false;
    notifyListeners();
  }

  /// Runs the five checks in order, then asks the server to change the password.
  /// On success the fields are cleared and the popup closes itself after a
  /// moment; on failure the server's text is shown.
  Future<void> submit() async {
    final currentPass = currentPassword.text.trim();
    final newPass = newPassword.text.trim();
    final confirmPass = confirmPassword.text.trim();

    if (currentPass.isEmpty) {
      _fail('Please enter your current password.');
      return;
    }
    if (newPass.isEmpty) {
      _fail('Please enter a new password.');
      return;
    }
    if (newPass.length < 6) {
      _fail('New password must be at least 6 characters.');
      return;
    }
    if (newPass != confirmPass) {
      _fail('New password and confirmation do not match.');
      return;
    }
    if (currentPass == newPass) {
      _fail('New password must be different from current password.');
      return;
    }

    isSubmitting = true;
    statusMessage = null;
    notifyListeners();

    final success = await auth.changePassword(currentPass, newPass);

    if (_disposed) return;

    isSubmitting = false;
    if (success) {
      statusMessage = 'Password updated successfully!';
      isSuccess = true;
      currentPassword.clear();
      newPassword.clear();
      confirmPassword.clear();
      notifyListeners();
      // Auto-close after a moment so the success message is actually seen --
      // this used to just sit there with no way out except the X icon.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!_disposed) onClose();
      });
    } else {
      statusMessage = auth.error ?? 'Failed to update password.';
      isSuccess = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }
}
