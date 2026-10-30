import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_exit.dart';
import '../utils/device_type.dart';
import '../widgets/dialogs/action_dialog.dart';
import '../widgets/login/login_form_card.dart';
import '../widgets/login/login_wide_layout.dart';

/// The login screen. Portrait card on a phone; on a tablet or desktop the
/// horizontal [LoginWideLayout]. Both show the same [LoginFormCard] and both
/// log in through [_handleLogin].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(loginOrientations(loginDeviceKind()));
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) {
      auth.setError('Wrong username or password');
      return;
    }
    final outcome = await auth.login(username, password);
    if (!mounted) return;

    if (outcome.success) {
      Navigator.pushReplacementNamed(context, '/lobby');
      return;
    }

    // Blocked account -- either just now, by hitting 5 failed attempts, or
    // already blocked beforehand. Same treatment either way: a dedicated
    // popup instead of the usual inline error text, since this needs a
    // conscious acknowledgement, not something to read past while retrying.
    // There's no session to log out of here (login never succeeded), so OK
    // just closes the app rather than calling auth.logout().
    if (outcome.accountBlocked) {
      showActionDialog(
        context,
        icon: Icons.block_rounded,
        title: 'ACCOUNT BLOCKED',
        message: outcome.error ?? 'You are temporarily blocked. Please contact your agent.',
        barrierDismissible: false,
        onPressed: closeApp,
      );
      return;
    }

    // Q6: a second device is refused rather than displacing the first. Say so
    // plainly, including when the other session will go stale, so the player
    // does not read it as a wrong password and keep retrying.
    if (outcome.sessionHeldElsewhere) {
      final secs = outcome.secondsUntilFree;
      auth.setError(secs > 0
          ? 'Already playing on another device. Try again in ${secs}s.'
          : 'This account is already playing on another device.');
    }
    // Every other failure (including the new "...N attempts left" text) is
    // already in auth.error -- AuthProvider.login() sets it from
    // outcome.error before returning, so LoginFormCard picks it up with no
    // further action needed here.
  }

  @override
  Widget build(BuildContext context) {
    final wide = loginDeviceKind() != LoginDeviceKind.phone;
    final form = LoginFormCard(
      usernameController: _usernameCtrl,
      passwordController: _passwordCtrl,
      onLogin: _handleLogin,
    );
    return Scaffold(
      // The wide layout moves its own right side for the keyboard.
      resizeToAvoidBottomInset: !wide,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset('assets/images/bg_lobby.webp', fit: BoxFit.cover),
          // Dark vignette
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Colors.transparent, Color(0x88000000)],
              ),
            ),
          ),
          if (wide)
            LoginWideLayout(form: form)
          else ...[
            // Login card
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SizedBox(
                  width: 340,
                  child: form,
                ),
              ),
            ),
            // Bottom disclaimer
            Positioned(
              bottom: 12,
              left: 0, right: 0,
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Image.asset(
                    'assets/images/warning_18.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
