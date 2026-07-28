import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/sound_service.dart';

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
            '${auth.balance}',
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
      onTap: () => _showLogoutDialog(context, auth),
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

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    bool isClosed = false;
    SoundService().playNotification();
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Logout',
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
                width: 300,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                      // Logout warning icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3E0800),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.goldBright,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Title
                      const Text(
                        'LOGOUT',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.goldBright,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Message
                      const Text(
                        'Are you sure you want to logout of your account?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Actions (YES / NO buttons side-by-side)
                      Row(
                        children: [
                          // CANCEL button (Stay logged in) - Green 3D Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!isClosed) {
                                  isClosed = true;
                                  Navigator.of(ctx).pop();
                                }
                              },
                              child: Container(
                                height: 38,
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
                                child: const Center(
                                  child: Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // YES button (Exit) - Red 3D Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                if (!isClosed) {
                                  isClosed = true;
                                  Navigator.of(ctx).pop();
                                  Provider.of<HistoryProvider>(context, listen: false).clearLocal();
                                  await auth.logout();
                                  if (context.mounted) {
                                    Navigator.pushReplacementNamed(context, '/login');
                                  }
                                }
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF5555), Color(0xFFCC0000), Color(0xFF660000)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFAAAA), width: 1.2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'YES, LOGOUT',
                                    style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
