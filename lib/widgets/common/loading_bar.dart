import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A premium 3D landscape loading bar widget.
/// 
/// Features:
/// - Horizontal (landscape) orientation
/// - Metallic gold outer frame
/// - Deep dark inner channel
/// - Animated gold gradient fill (loops continuously)
/// - 3D effect: top sheen highlight + bottom shadow + glowing tip
/// - Optional [label] text shown below
class LoadingBar3D extends StatefulWidget {
  final double width;
  final double height;
  final String label;

  const LoadingBar3D({
    super.key,
    this.width = 220,
    this.height = 18,
    this.label = 'LOADING...',
  });

  @override
  State<LoadingBar3D> createState() => _LoadingBar3DState();
}

class _LoadingBar3DState extends State<LoadingBar3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fill;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _fill = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer frame
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8B6914),  // dark gold
                Color(0xFFDAA520),  // gold
                Color(0xFFFFD700),  // bright gold
                Color(0xFFDAA520),  // gold
                Color(0xFF8B6914),  // dark gold
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.goldBright.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: AnimatedBuilder(
            animation: _fill,
            builder: (_, __) {
              return ClipRRect(
                borderRadius: BorderRadius.circular((widget.height - 5) / 2),
                child: Stack(
                  children: [
                    // Inner channel (dark background)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A0800), Color(0xFF0A0000)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // Fill bar
                    FractionallySizedBox(
                      widthFactor: 0.05 + (_fill.value * 0.95),
                      heightFactor: 1.0,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular((widget.height - 5) / 2),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFB8860B),  // dark gold start
                              Color(0xFFFFD700),  // bright gold mid
                              Color(0xFFFFF176),  // pale gold tip
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),

                    // 3D top sheen highlight
                    Positioned(
                      top: 0, left: 0, right: 0,
                      height: (widget.height - 5) * 0.45,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular((widget.height - 5) / 2),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // 3D bottom shadow
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      height: (widget.height - 5) * 0.30,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Glowing tip at leading edge of fill
                    Align(
                      alignment: Alignment(
                        -0.90 + (_fill.value * 1.90),
                        0,
                      ),
                      child: Container(
                        width: 8,
                        height: widget.height - 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.9),
                              AppColors.goldBright.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Label
        Text(
          widget.label,
          style: AppTextStyles.labelLight(size: 10, color: AppColors.goldBright),
        ),
      ],
    );
  }
}
