import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../../models/spin_result_model.dart';
import '../../services/sound_service.dart';
import 'hub_smoke.dart';
import 'wheel_painter.dart';

class WheelWidget extends StatefulWidget {
  const WheelWidget({super.key});

  @override
  State<WheelWidget> createState() => _WheelWidgetState();
}

class _WheelWidgetState extends State<WheelWidget>
    with TickerProviderStateMixin {
  // ── Spin ring controllers (one per ring, all identical approach) ──────────
  late AnimationController _redCtrl;
  late AnimationController _greenCtrl;
  late AnimationController _blackCtrl;

  late Animation<double> _redAnim;
  late Animation<double> _greenAnim;
  late Animation<double> _blackAnim;

  // Stable landing angles (updated at spin end, used as next spin's base)
  double _redAngle   = 0;
  double _greenAngle = 0;
  double _blackAngle = 0;

  double _redTarget   = 0;
  double _greenTarget = 0;
  double _blackTarget = 0;

  // ── Hub state flags ───────────────────────────────────────────────────────
  bool _isActivelySpinning = false; // true only during _spinToResult
  bool _spinStarted     = false;
  bool _showSmoke       = false;
  bool _showN           = false;
  bool _showFinalResult = false;

  bool _showRedGlow   = false;
  bool _showGreenGlow = false;
  bool _showBlackGlow = false;

  int? _landedRed;
  int? _landedGreen;
  int? _landedBlack;
  int  _landedBonusMultiplier = 1;

  GameProvider? _gameProvider;

  // ── N letter pulse animation ──────────────────────────────────────────────
  late AnimationController _nPulseCtrl;
  late Animation<double>   _nPulseAnim;

  @override
  void initState() {
    super.initState();

    // ── Spin controllers — all use same curve ────────────────────────────────
    _redCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _greenCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000));
    _blackCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 7000));

    _redAnim   = CurvedAnimation(parent: _redCtrl,   curve: const LateDecelerateCurve());
    _greenAnim = CurvedAnimation(parent: _greenCtrl, curve: const LateDecelerateCurve());
    _blackAnim = CurvedAnimation(parent: _blackCtrl, curve: const LateDecelerateCurve());

    // Status listeners — setState for glow/result flags (fired 3× per spin max)
    _redCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SoundService().playRimSelect();
        setState(() => _showRedGlow = true);
      }
    });

    _greenCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SoundService().playRimSelect();
        setState(() => _showGreenGlow = true);
      }
    });

    _blackCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SoundService().playRimSelect();
        SoundService().playSpinStop();
        setState(() {
          _showBlackGlow   = true;
          _showSmoke       = false;
          _showN           = false;
          _showFinalResult = true;
        });
        _nPulseCtrl.stop();
        // All 3 rings have now genuinely landed on screen -- tell the
        // provider so it can reveal the balance/popup in sync with this,
        // instead of on its own separate, blindly-timed clock.
        _gameProvider?.notifyWheelRevealComplete();
      }
    });

    // ── N letter pulse ────────────────────────────────────────────────────────
    _nPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _nPulseAnim = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _nPulseCtrl, curve: Curves.easeInOut),
    );

    // Listen for spin result from GameProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final game = context.read<GameProvider>();
        _gameProvider = game;
        _gameProvider?.addListener(_onGameStateChange);

        if (game.globalHistory.isNotEmpty) {
          final last = game.globalHistory.first;
          setState(() {
            _landedRed   = last.red;
            _landedGreen = last.green;
            _landedBlack = last.black;
            _landedBonusMultiplier = last.bonusMultiplier;
            _showRedGlow = true;
            _showGreenGlow = true;
            _showBlackGlow = true;
            _showFinalResult = false;
            _spinStarted = false;

            final segAngle = 2 * pi / 10;
            _redAngle   = (2 * pi - _landedRed! * segAngle) % (2 * pi);
            _blackAngle = (2 * pi - _landedBlack! * segAngle) % (2 * pi);
            _greenAngle = -(_landedGreen! * segAngle);
          });
        }
      }
    });
  }

  void _onGameStateChange() {
    final game = context.read<GameProvider>();
    final result = game.pendingResult;

    if (!_spinStarted && !_isActivelySpinning && game.globalHistory.isNotEmpty && _landedRed == null) {
      final last = game.globalHistory.first;
      setState(() {
        _landedRed   = last.red;
        _landedGreen = last.green;
        _landedBlack = last.black;
        _landedBonusMultiplier = last.bonusMultiplier;
        _showRedGlow = true;
        _showGreenGlow = true;
        _showBlackGlow = true;
        _showFinalResult = false;

        final segAngle = 2 * pi / 10;
        _redAngle   = (2 * pi - _landedRed! * segAngle) % (2 * pi);
        _blackAngle = (2 * pi - _landedBlack! * segAngle) % (2 * pi);
        _greenAngle = -(_landedGreen! * segAngle);
      });
    }

    if (!game.isSpinning) return;

    if (result != null && !_isActivelySpinning) {
      _spinToResult(result);
    }
  }

  /// Calculates CW rotation so [digit] lands at top. Used for Red and Black.
  double _calcTarget(double currentAngle, int digit, int rotations) {
    final segAngle = 2 * pi / 10;
    final cur360 = currentAngle % (2 * pi);
    final tgt360 = (2 * pi - digit * segAngle) % (2 * pi);
    var diff = tgt360 - cur360;
    if (diff <= 0) diff += 2 * pi;
    return currentAngle + (rotations * 2 * pi) + diff;
  }

  /// Calculates CCW rotation (negative angle) so [digit] lands at top. Used for Green.
  /// Returns a negative value so canvas.rotate() spins anticlockwise.
  double _calcTargetCCW(double currentAngle, int digit, int rotations) {
    final segAngle = 2 * pi / 10;
    // CCW accumulated position (treat negative angles as positive CCW distance)
    final cur360 = (-currentAngle) % (2 * pi);
    // How far CCW to bring digit to top: digit*segAngle
    final tgt360 = (digit * segAngle) % (2 * pi);
    var diff = tgt360 - cur360;
    if (diff <= 0) diff += 2 * pi;
    return currentAngle - (rotations * 2 * pi) - diff; // negative → anticlockwise
  }

  Future<void> _spinToResult(SpinResult result) async {
    // Red: 4 rotations (over 2.5 seconds)
    // Green: 8 rotations (over 5.0 seconds)
    // Black: 11 rotations (over 7.0 seconds)
    _redTarget   = _calcTarget(_redAngle,     result.red,   4);
    _greenTarget = _calcTargetCCW(_greenAngle, result.green, 8); // anticlockwise
    _blackTarget = _calcTarget(_blackAngle,   result.black, 11);

    _landedRed   = result.red;
    _landedGreen = result.green;
    _landedBlack = result.black;
    _landedBonusMultiplier = result.bonusMultiplier;


    setState(() {
      _isActivelySpinning = true;
      _spinStarted        = true;
      _showSmoke          = true;
      _showN              = true;
      _showFinalResult    = false;
      _showRedGlow        = false;
      _showGreenGlow      = false;
      _showBlackGlow      = false;
    });

    SoundService().playSpinStart();
    _redCtrl.reset();
    _greenCtrl.reset();
    _blackCtrl.reset();
    _nPulseCtrl.stop();
    _nPulseCtrl.repeat(reverse: true);

    // All three rings start together
    await Future.wait([
      _redCtrl.forward(),
      _greenCtrl.forward(),
      _blackCtrl.forward(),
    ]);

    // Stabilise final angles
    if (mounted) {
      _redAngle   = _redTarget;
      _greenAngle = _greenTarget;
      _blackAngle = _blackTarget;
    }

    // Wheel returns to static position after spin
    if (mounted) {
      setState(() => _isActivelySpinning = false);
    }
  }

  @override
  void dispose() {
    _gameProvider?.removeListener(_onGameStateChange);
    _redCtrl.dispose();
    _greenCtrl.dispose();
    _blackCtrl.dispose();
    _nPulseCtrl.dispose();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight) * 0.98;
        return Center(
          child: SizedBox(
            width: size, height: size,
            child: _buildWheelStack(size),
          ),
        );
      },
    );
  }

  Widget _buildWheelStack(double size) {
    final double ringSize = size * 0.74;
    final double offsetY  = size * 0.01636;
    // Issue #101 follow-up (corrected): all three rings (red/green/black)
    // narrowed from width 0.26 to 0.24, pushing the hub edge 0.22 -> 0.28
    // (+62% hub area), so the result number/bonus badge inside it get
    // bigger still, on top of their own ratio increase. Must stay in sync
    // with wheel_painter.dart's black-ring innerFrac and separator-ring
    // position (both also -> 0.28) -- all three define the same boundary;
    // changing only one would leave a visible gap or overlap between the
    // hub and the black ring.
    final double hubSize  = ringSize * 0.28;

    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Layer 1: Animated rings ──────────────────────────────────────
        // AnimatedBuilder rebuilds ONLY the CustomPaint each frame.
        // Listens to all 3 spin controllers.
        Transform.translate(
          offset: Offset(0, offsetY),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _redCtrl,
              _greenCtrl,
              _blackCtrl,
            ]),
            builder: (_, __) {
              final double redA;
              final double greenA;
              final double blackA;

              if (_isActivelySpinning) {
                // ── During spin: interpolate smoothly from captured start to target ──
                redA   = _redAngle   + _redAnim.value   * (_redTarget   - _redAngle);
                greenA = _greenAngle + _greenAnim.value * (_greenTarget - _greenAngle);
                blackA = _blackAngle + _blackAnim.value * (_blackTarget - _blackAngle);
              } else {
                // Static when not spinning
                redA   = _redAngle;
                greenA = _greenAngle;
                blackA = _blackAngle;
              }

              return CustomPaint(
                painter: WheelPainter(
                  redAngle:      redA,
                  greenAngle:    greenA,
                  blackAngle:    blackA,
                  showRedGlow:   _showRedGlow,
                  showGreenGlow: _showGreenGlow,
                  showBlackGlow: _showBlackGlow,
                ),
                size: Size(ringSize, ringSize),
              );
            },
          ),
        ),

        // ── Layer 2: Outer decorative rim (static) ───────────────────────
        Image.asset('assets/images/final_rim.webp',
            width: size, height: size, fit: BoxFit.contain),

        // ── Layer 3: Hub center ─────────────────────────────────────────
        Transform.translate(
          offset: Offset(0, offsetY),
          child: _buildHub(hubSize),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hub states
  //  Idle / between spins → gold wheel_hub.webp + idle rings turning
  //  Spinning             → gold hub + smoke + reveal image (pulsing)
  //  Done                 → white circle + result number + reveal image
  //  "Reveal image" is n_letter.webp when this round has no bonus active,
  //  or 2X/3X/4X.webp when it does -- see _hubImageAsset() below.
  // ─────────────────────────────────────────────────────────────────────────

  /// Maps this round's bonus multiplier (1/2/3/4) to the reveal-hub image
  /// asset. 1 ("N", no bonus active) is today's exact default behavior;
  /// 2/3/4 render the matching promotional image with the identical
  /// pulse-during-spin / static-after-landing treatment -- only the asset
  /// path changes, nothing about animation timing or choreography.
  String _hubImageAsset(int bonusMultiplier) {
    switch (bonusMultiplier) {
      case 2: return 'assets/images/2X.webp';
      case 3: return 'assets/images/3X.webp';
      case 4: return 'assets/images/4X.webp';
      default: return 'assets/images/n_letter.webp';
    }
  }

  Widget _buildHub(double size) {

    // ── Final result ── white circle ────────────────────────────────────────
    if (_showFinalResult && _landedRed != null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width:  size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD4AF37), width: 2.0),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 6, spreadRadius: 1),
          ],
        ),
        child: ClipOval(
          child: LayoutBuilder(
            builder: (_, c) {
              final w = c.maxWidth;
              // Enlarged (both the ratio and the clamp floor/ceiling) -- the
              // old 0.35/0.20 ratios left ~35-40% of the hub circle's
              // available vertical space unused at typical mobile hub sizes,
              // making the result number and especially the bonus badge
              // (N/2X/3X/4X) hard to read. Verified the new total content
              // height (number + gap + badge) still fits inside the circle
              // with margin across the realistic hub-size range -- nothing
              // gets clipped by the ClipOval mask above.
              // Result number: -3px flat, N and bonus rounds alike (both
              // explicitly asked for the same reduction) -- clamp bounds
              // shifted by the same 3px so it applies uniformly across the
              // size range, not just at the extremes.
              final numFontSize = ((w * 0.48) - 3.0).clamp(15.0, 45.0);
              final nImgSize    = (w * 0.32).clamp(12.0, 32.0);
              // 2X/3X/4X assets are 278x170 (W/H=1.635, measured) vs N's
              // near-square n_letter.webp at 886x928 (W/H=0.955). Inside the
              // same square nImgSize box with BoxFit.contain, N fills ~100%
              // of the box's height, but the much-wider 2X/3X/4X glyphs are
              // width-constrained and only fill ~61% of that same height --
              // same nominal box, visibly smaller glyph. bonusImgSize
              // compensates by exactly that measured factor (1.635) so
              // 2X/3X/4X render at the SAME visual height as N; N itself is
              // untouched (nImgSize, above). Because the compensation targets
              // matching N's rendered height (not exceeding it), this adds no
              // new vertical footprint vs. what Issue #101 already verified
              // fits inside the hub's ClipOval -- only the badge's rendered
              // width grows, confirmed with margin against the circle's
              // chord width at both small and large hub sizes.
              final bonusImgSize = nImgSize * (278 / 170);
              // Gap between number and badge: N keeps its original
              // proportional spacing; 2X/3X/4X gets a small fixed 3px gap
              // (was fully removed to 0, then asked back as "a little gap").
              final gap = _landedBonusMultiplier == 1 ? (w * 0.05) : 3.0;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Text(
                      '$_landedRed$_landedGreen$_landedBlack',
                      style: GoogleFonts.oswald(
                        fontWeight: FontWeight.w700,
                        fontSize: numFontSize,
                        color: AppColors.blackRim,
                        letterSpacing: 1.0,
                        height: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  Image.asset(
                    _hubImageAsset(_landedBonusMultiplier),
                    // Box is sized to the badge's TRUE rendered aspect ratio,
                    // not a square -- bonusImgSize (width) x nImgSize (height)
                    // exactly matches the 278x170 asset's real proportions at
                    // the target nImgSize content-height. A square box here
                    // (bonusImgSize x bonusImgSize) was the earlier bug: it
                    // left invisible dead space above/below the glyph inside
                    // its own box (since BoxFit.contain centers content
                    // within whatever box it's given), which looked like a
                    // leftover gap above the badge and extra padding below it
                    // even after the explicit `gap` SizedBox was set to 0.
                    width:  _landedBonusMultiplier == 1 ? nImgSize : bonusImgSize,
                    height: nImgSize,
                    fit: BoxFit.contain,
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // ── Spinning or idle: gold hub ± smoke + N ───────────────────────────────
    return SizedBox(
      width:  size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/wheel_hub.webp',
            width:  size,
            height: size,
            fit: BoxFit.contain,
          ),

          if (_showSmoke && _spinStarted)
            ClipOval(
              child: SizedBox(
                width:  size,
                height: size,
                child: HubSmokeAnimation(size: size),
              ),
            ),

          if (_showN && _spinStarted)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 4000),
              curve: Curves.easeIn,
              builder: (_, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: AnimatedBuilder(
                animation: _nPulseAnim,
                builder: (_, __) {
                  final imgSize = (size * 0.50).clamp(15.0, 50.0);
                  return Transform.scale(
                    scale: _nPulseAnim.value,
                    child: Image.asset(
                      _hubImageAsset(_landedBonusMultiplier),
                      width:  imgSize,
                      height: imgSize,
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A high-performance custom animation curve designed to keep the wheel spinning
/// fast and smooth for 85% of its duration, and then perform a brief, sharp,
/// and continuous quadratic deceleration to prevent low-velocity sub-pixel jitter.
class LateDecelerateCurve extends Curve {
  const LateDecelerateCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.85) {
      // Linear phase: constant speed
      return (40.0 / 37.0) * t;
    } else {
      // Braking phase (final 15%): smooth quadratic ease-out to 1.0 with continuous velocity
      final double diff = 1.0 - t;
      return 1.0 - (400.0 / 111.0) * diff * diff;
    }
  }
}
