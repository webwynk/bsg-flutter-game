import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/sound_service.dart';
import '../utils/app_exit.dart';
import '../utils/device_type.dart';
import '../widgets/login/change_password_form.dart';
import '../widgets/login/security_wide_dialog.dart';
import 'lucky_card_screen.dart';
import 'lucky16_screen.dart';
import 'spin2win_screen.dart';

import 'package:flutter/services.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  static const List<_GameInfo> _games = [
    _GameInfo('assets/images/card_triple_chance.webp', true),
    _GameInfo('assets/lucky_card/images/lucky-card-game-card.webp', true, luckyCard: true),
    _GameInfo('assets/spin2win/images/spin2win-game-card.webp', true, spin2win: true),
    _GameInfo('assets/lucky16card/images/lucky-16-game-card.webp', true, lucky16: true),
    _GameInfo('assets/images/card_coming_soon.webp', false),
    _GameInfo('assets/images/card_coming_soon.webp', false),
    _GameInfo('assets/images/card_coming_soon.webp', false),
    _GameInfo('assets/images/card_coming_soon.webp', false),
    _GameInfo('assets/images/card_coming_soon.webp', false),
    _GameInfo('assets/images/card_coming_soon.webp', false),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bg_lobby.webp', fit: BoxFit.cover),
          Column(
            children: [
              _TopBar(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _games.length,
                  itemBuilder: (ctx, i) => _GameCard(
                    game: _games[i],
                    index: i,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, __) => Container(
        height: 52,
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(color: AppColors.goldPrimary, width: 1.2),
          ),
          image: const DecorationImage(
            image: AssetImage('assets/images/game_lobby_hader.webp'),
            fit: BoxFit.fill,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final bool showDisclaimer = width >= 500;
            final double scaleFactor = width < 750 ? 0.95 : 1.0;

            return Row(
              children: [
                // Profile/Welcome Section
                _buildProfileSection(auth, scaleFactor),
                
                if (showDisclaimer) ...[
                  const Spacer(),
                  _buildDisclaimerSection(scaleFactor),
                ],
                
                const Spacer(),
                
                // Balance & Logout Section
                _buildBalanceSection(auth, scaleFactor),
                const SizedBox(width: 8),
                _buildLogoutButton(context, auth, scaleFactor),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileSection(AuthProvider auth, double scaleFactor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32 * scaleFactor,
          height: 32 * scaleFactor,
          child: Image.asset(
            'assets/images/icon_bsg_1024.webp',
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: 8 * scaleFactor),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Welcome, ',
              style: AppTextStyles.labelLight(
                size: 10 * scaleFactor,
                color: AppColors.goldPrimary,
              ),
            ),
            Text(
              auth.username,
              style: AppTextStyles.number(
                size: 12 * scaleFactor,
                color: Colors.white,
              ).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(width: 10 * scaleFactor),
        Container(
          width: 1.0,
          height: 22 * scaleFactor,
          color: AppColors.goldPrimary.withValues(alpha: 0.25),
        ),
      ],
    );
  }

  Widget _buildDisclaimerSection(double scaleFactor) {
    return Text(
      '✦ FOR AMUSEMENT ONLY ✦',
      style: AppTextStyles.label(
        size: 10.5 * scaleFactor,
        color: AppColors.goldPrimary,
      ).copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        shadows: [
          Shadow(
            color: AppColors.goldPrimary.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection(AuthProvider auth, double scaleFactor) {
    return Container(
      height: 32 * scaleFactor,
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scaleFactor,
        vertical: 2 * scaleFactor,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldPrimary, width: 1.2),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E0800), Color(0xFF150200)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldPrimary.withValues(alpha: 0.15),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
          const BoxShadow(
            color: Colors.black38,
            blurRadius: 3,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/bsg_coin.webp',
            width: 20 * scaleFactor,
            height: 20 * scaleFactor,
          ),
          SizedBox(width: 6 * scaleFactor),
          Container(
            width: 1,
            height: 16 * scaleFactor,
            color: AppColors.goldPrimary.withValues(alpha: 0.3),
          ),
          SizedBox(width: 6 * scaleFactor),
          Text(
            '${auth.coinBalance}',
            style: AppTextStyles.number(
              size: 14 * scaleFactor,
              color: AppColors.goldBright,
            ).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider auth, double scaleFactor) {
    return GestureDetector(
      onTap: () => _showSecurityDialog(context, auth),
      child: Container(
        width: 32 * scaleFactor,
        height: 32 * scaleFactor,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.goldPrimary, width: 1.2),
          gradient: const LinearGradient(
            colors: [Color(0xFF5A0000), Color(0xFF2A0000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldPrimary.withValues(alpha: 0.15),
              blurRadius: 3,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Icon(
          Icons.lock,
          color: AppColors.goldPrimary,
          size: 16 * scaleFactor,
        ),
      ),
    );
  }

  /// Phone-only: forces portrait for the duration of this dialog so the
  /// system keyboard renders in its taller/narrower portrait shape instead
  /// of the wide, short landscape one that was hiding half the form. Never
  /// fires on desktop/laptop/tablet: those get the wide popup, which stays in
  /// landscape and moves itself above the keyboard.
  ///
  /// Not dismissible by tapping outside or the back button (see PopScope in
  /// _SecurityAccountDialog) -- only the X icon or a successful password
  /// change closes it.
  void _showSecurityDialog(BuildContext context, AuthProvider auth) async {
    SoundService().playNotification();

    final kind = loginDeviceKind();
    final wide = kind != LoginDeviceKind.phone;
    final rotateForPhone = !wide && isMobilePhone(context);
    if (rotateForPhone) {
      // Let the physical rotation settle BEFORE the dialog's own scale-in
      // animation starts -- running both at once (screen rotating while the
      // dialog is also animating in) is what would look janky. One
      // animation finishes, then the next begins.
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!context.mounted) return;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Security',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: _SecurityAccountDialog(
                auth: auth,
                lobbyContext: context,
                kind: kind,
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

    // Dialog's own exit animation has already finished by the time this
    // await resolves -- the screen rotation below is the only animation
    // running at this point, never competing with another one.
    if (rotateForPhone) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }
}

class _SecurityAccountDialog extends StatefulWidget {
  final AuthProvider auth;
  final BuildContext lobbyContext;
  final LoginDeviceKind kind;

  const _SecurityAccountDialog({
    required this.auth,
    required this.lobbyContext,
    required this.kind,
  });

  @override
  State<_SecurityAccountDialog> createState() => _SecurityAccountDialogState();
}

class _SecurityAccountDialogState extends State<_SecurityAccountDialog> {
  late final ChangePasswordForm _form;

  @override
  void initState() {
    super.initState();
    _form = ChangePasswordForm(
      auth: widget.auth,
      onClose: () => Navigator.of(context).pop(),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    Navigator.of(context).pop(); // Close security dialog
    Provider.of<HistoryProvider>(widget.lobbyContext, listen: false).clearLocal();
    // Full logout ends the session server-side (session_logout) before the
    // app closes -- matches the same abortSpin/logout-before-close ordering
    // already used for the connection-lost and blocked-account popups
    // (Issue #51), rather than returning to the login screen.
    await widget.auth.logout();
    closeApp();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind != LoginDeviceKind.phone) {
      return SecurityWideDialog(
        form: _form,
        username: widget.auth.username,
        desktop: widget.kind == LoginDeviceKind.desktop,
        onClose: () => Navigator.of(context).pop(),
        onLogout: _handleLogout,
      );
    }
    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E0502), Color(0xFF0D0201), Color(0xFF060100)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.goldBright.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldPrimary.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                  const BoxShadow(
                    color: Colors.black,
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog Header: Glowing Badge + Title + Modern Circular Close Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A0A02), Color(0xFF220301)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.goldBright.withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldPrimary.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: AppColors.goldBright,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SECURITY & ACCOUNT',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.goldBright,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '@${widget.auth.username}',
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF330E08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Password Form Fields
                    _buildPasswordField(
                      controller: _form.currentPassword,
                      label: 'Current Password',
                      obscure: _form.obscureCurrent,
                      onToggleObscure: _form.toggleObscureCurrent,
                    ),
                    const SizedBox(height: 10),

                    _buildPasswordField(
                      controller: _form.newPassword,
                      label: 'New Password (min 6 chars)',
                      obscure: _form.obscureNew,
                      onToggleObscure: _form.toggleObscureNew,
                    ),
                    const SizedBox(height: 10),

                    _buildPasswordField(
                      controller: _form.confirmPassword,
                      label: 'Confirm New Password',
                      obscure: _form.obscureConfirm,
                      onToggleObscure: _form.toggleObscureConfirm,
                    ),
                    const SizedBox(height: 14),

                    // Status / Error / Success Banner
                    if (_form.statusMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: _form.isSuccess ? const Color(0xFF003810) : const Color(0xFF380000),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _form.isSuccess ? const Color(0xFF00FF55) : const Color(0xFFFF5555),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _form.statusMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _form.isSuccess ? const Color(0xFF88FFB0) : const Color(0xFFFF9999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // UPDATE PASSWORD Button (Metallic Gold 3D Button)
                    GestureDetector(
                      onTap: _form.isSubmitting ? null : _form.submit,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _form.isSubmitting
                                ? [const Color(0xFF554400), const Color(0xFF332200)]
                                : [const Color(0xFFFFE066), const Color(0xFFD4A017), const Color(0xFF7A5200)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.goldBright, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldPrimary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _form.isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : const Text(
                                  'UPDATE PASSWORD',
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: Colors.black,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Divider Separator with Centered Pill
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: AppColors.goldPrimary.withValues(alpha: 0.2))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: AppColors.goldPrimary.withValues(alpha: 0.2))),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // LOGOUT ACCOUNT Button (Red Crimson 3D Button)
                    GestureDetector(
                      onTap: _handleLogout,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE52E2E), Color(0xFF990000), Color(0xFF550000)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFAAAA).withValues(alpha: 0.8), width: 1.2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'LOGOUT ACCOUNT',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: Colors.white,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
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
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggleObscure,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF140402),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.goldPrimary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: label,
          hintStyle: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.45),
          ),
          suffixIcon: GestureDetector(
            onTap: onToggleObscure,
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.goldPrimary.withValues(alpha: 0.75),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  final _GameInfo game;
  final int index;
  const _GameCard({required this.game, required this.index});

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _hovered = false;

  void _showLockedDialog(BuildContext context) {
    bool isClosed = false;
    SoundService().playNotification();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LockedGame',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted && !isClosed && Navigator.of(ctx).canPop()) {
            isClosed = true;
            Navigator.of(ctx).pop();
          }
        });

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
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
                      // Glowing circular lock badge
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.goldPrimary, width: 1.5),
                          gradient: RadialGradient(
                            colors: [
                              AppColors.goldPrimary.withValues(alpha: 0.25),
                              const Color(0xFF350500),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldPrimary.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock_rounded,
                            color: AppColors.goldBright,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      
                      // ShaderMask Gold Gradient Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.goldBright, AppColors.goldPrimary],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: const Text(
                          'COMING SOON',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      
                      // Gold divider separator with star
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1.0,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, AppColors.goldPrimary.withValues(alpha: 0.5)],
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Icon(Icons.star, color: AppColors.goldPrimary, size: 10),
                            ),
                            Expanded(
                              child: Container(
                                height: 1.0,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.goldPrimary.withValues(alpha: 0.5), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Message
                      const Text(
                        // Housekeeping #38 fix: the previous copy implied a
                        // per-agent entitlement toggle that doesn't exist --
                        // these 9 slots are reserved for games not built yet,
                        // confirmed as the real intent, not a restriction any
                        // agent can lift.
                        'This game hasn\'t been released yet.\nMore games are on the way -- stay tuned!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // OK Button (3D green gradient action button)
                      GestureDetector(
                        onTap: () {
                          if (!isClosed) {
                            isClosed = true;
                            Navigator.of(ctx).pop();
                          }
                        },
                        child: Container(
                          height: 40,
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
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 3,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'OK',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundService().playButtonClick();
        if (widget.game.isActive) {
          if (widget.game.luckyCard) {
            // Lucky Card has no named route (main.dart is not touched): its screen is opened directly.
            Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LuckyCardScreen()));
          } else if (widget.game.spin2win) {
            // Spin2Win has no named route either (main.dart is not touched): its screen is opened directly.
            Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const Spin2WinScreen()));
          } else if (widget.game.lucky16) {
            // Lucky 16 Card has no named route either (main.dart is not touched): its screen is opened directly.
            Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const Lucky16Screen()));
          } else {
            Navigator.pushNamed(context, '/game');
          }
        } else {
          _showLockedDialog(context);
        }
      },
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Image.asset(widget.game.imagePath, fit: BoxFit.fill),
      ),
    ).animate(delay: Duration(milliseconds: widget.index * 80))
     .fadeIn(duration: 400.ms)
     .slideY(begin: 0.4, duration: 400.ms, curve: Curves.easeOut);
  }
}

class _GameInfo {
  final String imagePath;
  final bool isActive;

  /// True for the Lucky Card poster: its tap opens the Lucky Card screen instead of '/game'.
  final bool luckyCard;

  /// True for the Spin2Win poster: its tap opens the Spin2Win screen instead of '/game'.
  final bool spin2win;

  /// True for the Lucky 16 Card poster: its tap opens the Lucky 16 Card screen instead of '/game'.
  final bool lucky16;
  const _GameInfo(this.imagePath, this.isActive, {this.luckyCard = false, this.spin2win = false, this.lucky16 = false});
}
