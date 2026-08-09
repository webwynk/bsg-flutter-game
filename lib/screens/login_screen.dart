import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_decorations.dart';
import '../utils/app_exit.dart';
import '../widgets/common/loading_bar.dart';
import '../widgets/dialogs/action_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _shaking = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
      _shake();
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
      _shake();
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
    // outcome.error before returning, so _errorMessage() below picks it up
    // with no further action needed here.

    _shake();
  }

  void _shake() {
    setState(() => _shaking = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shaking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          // Login card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: 340,
                child: _buildCard(),
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
      ),
    );
  }

  Widget _buildCard() {
    return AnimatedBuilder(
      animation: const AlwaysStoppedAnimation(0),
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: _shaking ? -8 : 0, end: 0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (_, val, child) => Transform.translate(
            offset: Offset(val, 0),
            child: child,
          ),
          child: _cardContent(),
        );
      },
    );
  }

  Widget _cardContent() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Card body
        Container(
          margin: const EdgeInsets.only(top: 55),
          padding: const EdgeInsets.fromLTRB(36, 52, 36, 24),
          decoration: AppDecorations.loginCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _memberLoginLabel(),
              const SizedBox(height: 18),
              _usernameField(),
              const SizedBox(height: 10),
              _passwordField(),
              const SizedBox(height: 18),
              _loginButton(),
              const SizedBox(height: 10),
              _errorMessage(),
            ],
          ),
        ),
        // Logo overlapping top of card
        Positioned(
          top: 0,
          child: Image.asset(
            'assets/images/logo_bsg_full.webp',
            height: 110,
            fit: BoxFit.contain,
          ).animate().fadeIn(delay: 200.ms).scale(
            begin: const Offset(0.7, 0.7),
            curve: Curves.elasticOut,
            duration: 800.ms,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  Widget _memberLoginLabel() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.goldPrimary.withValues(alpha: 0.5))),
        const SizedBox(width: 10),
        Text('MEMBER LOGIN', style: AppTextStyles.sectionHeader(size: 12)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.goldPrimary.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _usernameField() {
    return TextField(
      controller: _usernameCtrl,
      style: AppTextStyles.number(size: 15, color: Colors.white),
      decoration: AppDecorations.textField(
        hint: 'Enter Username',
        prefixIcon: Icons.person_outline,
      ),
    ).animate(delay: 400.ms).fadeIn().slideX(begin: -0.2);
  }

  Widget _passwordField() {
    return TextField(
      controller: _passwordCtrl,
      obscureText: !_showPassword,
      style: AppTextStyles.number(size: 15, color: Colors.white),
      decoration: AppDecorations.textField(
        hint: 'Enter Password',
        prefixIcon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            color: AppColors.goldPrimary,
            size: 20,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
      ),
      onSubmitted: (_) => _handleLogin(),
    ).animate(delay: 500.ms).fadeIn().slideX(begin: -0.2);
  }

  Widget _loginButton() {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!auth.isLoading)
              GestureDetector(
                onTap: _handleLogin,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF99FF99),
                      width: 1.5,
                    ),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF00).withValues(alpha: 0.35),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gloss overlay
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          height: 25,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            gradient: LinearGradient(
                              colors: [Colors.white.withValues(alpha: 0.25), Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'LOGIN',
                        style: AppTextStyles.button(size: 17).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            const Shadow(
                              color: Colors.black,
                              offset: Offset(0, 2),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.2),

            // 3D loading bar — visible only when auth is loading
            if (auth.isLoading) ...[
              const SizedBox(height: 14),
              const LoadingBar3D(width: 200, height: 16, label: 'SIGNING IN...'),
            ],
          ],
        );
      },
    );
  }

  Widget _errorMessage() {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (auth.error == null) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.dangerRed, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                auth.error!,
                style: AppTextStyles.label(size: 11, color: AppColors.dangerRed),
              ),
            ),
          ],
        ).animate().fadeIn().slideY(begin: -0.3);
      },
    );
  }
}
