import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bg_lobby.webp', fit: BoxFit.cover),
          Container(color: const Color(0x99000000)),
          Consumer<AuthProvider>(
            builder: (_, auth, __) => Column(
              children: [
                // Header
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E0400),
                    border: Border(bottom: BorderSide(color: AppColors.goldPrimary)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                          color: AppColors.goldPrimary, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text('MY ACCOUNT', style: AppTextStyles.sectionHeader(size: 14)),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Profile card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2A0800), Color(0xFF100000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.goldPrimary, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: AppColors.goldDark,
                                child: Text(
                                  auth.username.length >= 2
                                    ? auth.username.substring(0, 2).toUpperCase()
                                    : auth.username.toUpperCase(),
                                  style: AppTextStyles.number(size: 22, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(auth.username,
                                    style: AppTextStyles.number(size: 20)),
                                  Text('Agent: ${auth.agentName}',
                                    style: AppTextStyles.label(size: 11,
                                      color: AppColors.goldPrimary.withValues(alpha: 0.8))),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.successGreen.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.successGreen),
                                    ),
                                    child: Text('● ACTIVE',
                                      style: AppTextStyles.label(
                                        size: 9, color: AppColors.successGreen)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Balance
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1a0000),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.goldPrimary, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Color(0x33D4AF37), blurRadius: 20),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Text('Points Balance',
                                style: AppTextStyles.label(size: 10)),
                              Text('${auth.balance}',
                                style: AppTextStyles.balance(size: 42)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Logout button
                        GestureDetector(
                          onTap: () async {
                            Provider.of<HistoryProvider>(context, listen: false).clearLocal();
                            await auth.logout();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFa93226), Color(0xFF922b21)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text('🚪  LOGOUT',
                                style: AppTextStyles.button(size: 14,
                                  color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
