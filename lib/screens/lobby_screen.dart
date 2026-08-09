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

import 'package:flutter/services.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  static const List<_GameInfo> _games = [
    _GameInfo('Triple Chance', 'assets/images/card_triple_chance.webp', true),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
    _GameInfo('Coming Soon', 'assets/images/card_coming_soon.webp', false),
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
  /// fires on desktop/laptop/tablet (see isMobilePhone) -- those layouts
  /// don't have this problem in the first place.
  ///
  /// Not dismissible by tapping outside or the back button (see PopScope in
  /// _SecurityAccountDialog) -- only the X icon or a successful password
  /// change closes it.
  void _showSecurityDialog(BuildContext context, AuthProvider auth) async {
    SoundService().playNotification();

    final rotateForPhone = isMobilePhone(context);
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
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return PopScope(
          canPop: false,
          child: Center(
            child: _SecurityAccountDialog(auth: auth, lobbyContext: context),
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

  const _SecurityAccountDialog({
    required this.auth,
    required this.lobbyContext,
  });

  @override
  State<_SecurityAccountDialog> createState() => _SecurityAccountDialogState();
}

class _SecurityAccountDialogState extends State<_SecurityAccountDialog> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final currentPass = _currentPasswordCtrl.text.trim();
    final newPass = _newPasswordCtrl.text.trim();
    final confirmPass = _confirmPasswordCtrl.text.trim();

    if (currentPass.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter your current password.';
        _isSuccess = false;
      });
      return;
    }
    if (newPass.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a new password.';
        _isSuccess = false;
      });
      return;
    }
    if (newPass.length < 6) {
      setState(() {
        _statusMessage = 'New password must be at least 6 characters.';
        _isSuccess = false;
      });
      return;
    }
    if (newPass != confirmPass) {
      setState(() {
        _statusMessage = 'New password and confirmation do not match.';
        _isSuccess = false;
      });
      return;
    }
    if (currentPass == newPass) {
      setState(() {
        _statusMessage = 'New password must be different from current password.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    final success = await widget.auth.changePassword(currentPass, newPass);

    if (!mounted) return;

    if (success) {
      setState(() {
        _isSubmitting = false;
        _statusMessage = 'Password updated successfully!';
        _isSuccess = true;
        _currentPasswordCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      });
      // Auto-close after a moment so the success message is actually seen --
      // this used to just sit there with no way out except the X icon.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() {
        _isSubmitting = false;
        _statusMessage = widget.auth.error ?? 'Failed to update password.';
        _isSuccess = false;
      });
    }
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
    return SingleChildScrollView(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF220500), Color(0xFF0C0200)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.goldPrimary.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldPrimary.withValues(alpha: 0.15),
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
                  // Dialog Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3E0800),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppColors.goldBright,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SECURITY & ACCOUNT',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: AppColors.goldBright,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '@${widget.auth.username}',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Password Form Fields
                  _buildPasswordField(
                    controller: _currentPasswordCtrl,
                    label: 'Current Password',
                    obscure: _obscureCurrent,
                    onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  const SizedBox(height: 10),

                  _buildPasswordField(
                    controller: _newPasswordCtrl,
                    label: 'New Password (min 6 chars)',
                    obscure: _obscureNew,
                    onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  const SizedBox(height: 10),

                  _buildPasswordField(
                    controller: _confirmPasswordCtrl,
                    label: 'Confirm New Password',
                    obscure: _obscureConfirm,
                    onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 12),

                  // Status / Error / Success Banner
                  if (_statusMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isSuccess ? const Color(0xFF003810) : const Color(0xFF380000),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isSuccess ? const Color(0xFF00FF55) : const Color(0xFFFF5555),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isSuccess ? const Color(0xFF88FFB0) : const Color(0xFFFF9999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // UPDATE PASSWORD Button (Gold 3D Gradient)
                  GestureDetector(
                    onTap: _isSubmitting ? null : _handleChangePassword,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSubmitting
                              ? [const Color(0xFF554400), const Color(0xFF332200)]
                              : [const Color(0xFFFFDD55), const Color(0xFFCC9900), const Color(0xFF664400)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.goldBright, width: 1.2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Center(
                        child: _isSubmitting
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

                  // Divider Separator
                  Row(
                    children: [
                      Expanded(child: Container(height: 1, color: Colors.white12)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      Expanded(child: Container(height: 1, color: Colors.white12)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // LOGOUT ACCOUNT Button (Red 3D Danger Button)
                  GestureDetector(
                    onTap: _handleLogout,
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3333), Color(0xFF990000), Color(0xFF550000)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFAAAA), width: 1.2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'LOGOUT ACCOUNT',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: Colors.white,
                              letterSpacing: 1.0,
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
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggleObscure,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.goldPrimary.withValues(alpha: 0.3),
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
            color: Colors.white.withValues(alpha: 0.4),
          ),
          suffixIcon: GestureDetector(
            onTap: onToggleObscure,
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.goldPrimary.withValues(alpha: 0.7),
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
                          'GAME LOCKED',
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
                        'This game is currently locked.\nContact your agent to activate this slot.',
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
          Navigator.pushNamed(context, '/game');
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
  final String name;
  final String imagePath;
  final bool isActive;
  const _GameInfo(this.name, this.imagePath, this.isActive);
}
