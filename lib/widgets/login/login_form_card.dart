import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../common/loading_bar.dart';

/// The login card: logo overlapping the top, MEMBER LOGIN, username, password
/// with its eye, the LOGIN button, the error text and the signing-in bar.
///
/// One widget for every device, so the phone and the tablet/desktop layouts
/// cannot drift apart. It only collects input and shows AuthProvider's state;
/// what happens on login belongs to the screen, through [onLogin]. Takes its
/// width from its parent.
class LoginFormCard extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;

  const LoginFormCard({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.onLogin,
  });

  @override
  State<LoginFormCard> createState() => _LoginFormCardState();
}

class _LoginFormCardState extends State<LoginFormCard> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
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
      controller: widget.usernameController,
      style: AppTextStyles.number(size: 15, color: Colors.white),
      decoration: AppDecorations.textField(
        hint: 'Enter Username',
        prefixIcon: Icons.person_outline,
      ),
    ).animate(delay: 400.ms).fadeIn().slideX(begin: -0.2);
  }

  Widget _passwordField() {
    return TextField(
      controller: widget.passwordController,
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
      onSubmitted: (_) => widget.onLogin(),
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
                onTap: widget.onLogin,
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
