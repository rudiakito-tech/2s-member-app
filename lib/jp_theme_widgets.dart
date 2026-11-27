import 'dart:math';
import 'package:flutter/material.dart';

class JpColors {
  static const creamBg = Color(0xFFFFF8EC);
  static const creamLight = Color(0xFFFFFDF8);
  static const navy = Color(0xFF162238);
  static const navyMuted = Color(0xFF536179);
  static const gold = Color(0xFFFFB800);
  static const orange = Color(0xFFFF7300);
  static const sakuraPink = Color(0xFFFFB7C5);
  static const sakuraDeep = Color(0xFFF47296);
  static const inputFill = Color(0xFFFFFCF5);
  static const inputBorder = Color(0xFFEBDCCB);
}

class TwoSMemberLogo extends StatelessWidget {
  final double scale;
  const TwoSMemberLogo({super.key, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_2s.png',
      height: 88 * scale,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        '2S MEMBER',
        style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.w900, color: JpColors.navy),
      ),
    );
  }
}

class JpTierCrown extends StatelessWidget {
  final String tier;
  final double size;
  const JpTierCrown({super.key, required this.tier, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final map = {
      'Bronze': 'assets/images/crown_bronze.png',
      'Silver': 'assets/images/crown_silver.png',
      'Gold': 'assets/images/crown_gold.png',
      'Platinum': 'assets/images/crown_platinum.png',
    };
    return Image.asset(
      map[tier] ?? 'assets/images/crown_bronze.png',
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.workspace_premium, size: size, color: JpColors.gold),
    );
  }
}

class JpOrangeButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;

  const JpOrangeButton({super.key, required this.label, required this.onTap, this.icon, this.loading = false});

  @override
  State<JpOrangeButton> createState() => _JpOrangeButtonState();
}

class _JpOrangeButtonState extends State<JpOrangeButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: enabled ? const [Color(0xFFFFC107), Color(0xFFFF7A00), Color(0xFFE65100)] : [Colors.grey.shade400, Colors.grey.shade500],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: enabled
                ? [BoxShadow(color: const Color(0xFFFF7A00).withValues(alpha: 0.38), blurRadius: 12, offset: const Offset(0, 5))]
                : [],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 3,
                left: 16,
                right: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Center(
                child: widget.loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: 19),
                            const SizedBox(width: 8),
                          ],
                          Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JpInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const JpInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JpColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JpColors.inputBorder, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(color: JpColors.navy, fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: JpColors.navyMuted.withValues(alpha: 0.7), fontSize: 13.5, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: JpColors.navyMuted, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class JpBackdrop extends StatefulWidget {
  final Widget child;
  final bool topFuji;
  final bool bottomFuji;
  const JpBackdrop({super.key, required this.child, this.topFuji = false, this.bottomFuji = true});

  @override
  State<JpBackdrop> createState() => _JpBackdropState();
}

class _JpBackdropState extends State<JpBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _petalCtrl;

  @override
  void initState() {
    super.initState();
    _petalCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  }

  @override
  void dispose() {
    _petalCtrl.dispose();
    super.dispose();
  }

  Widget _safeImg(String path, {double? height, double? width, BoxFit fit = BoxFit.contain, double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        path,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [JpColors.creamLight, JpColors.creamBg, Color(0xFFFFEED2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Pemandangan Atas (untuk Layar Login & Reset OTP)
          if (widget.topFuji) ...[
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(child: _safeImg('assets/images/scene_fuji.png', height: 125, opacity: 0.85)),
              ),
            ),
            Positioned(
              top: 42,
              right: -6,
              child: IgnorePointer(child: _safeImg('assets/images/pagoda.png', height: 115, opacity: 0.85)),
            ),
          ],

          // Ranting Sakura Sudut Kanan Atas & Kiri
          Positioned(
            top: 0,
            right: -4,
            child: IgnorePointer(child: _safeImg('assets/images/sakura_top.png', height: 105, opacity: 0.92)),
          ),
          Positioned(
            top: 30,
            left: -12,
            child: IgnorePointer(
              child: Transform.flip(
                flipX: true,
                child: _safeImg('assets/images/sakura_side.png', height: 110, opacity: 0.65),
              ),
            ),
          ),

          // Pemandangan Bawah (Fuji, Pagoda, Lentera & Gelombang Emas)
          if (widget.bottomFuji) ...[
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(child: _safeImg('assets/images/scene_fuji.png', height: 125, opacity: 0.88)),
              ),
            ),
            Positioned(
              bottom: 24,
              right: 4,
              child: IgnorePointer(child: _safeImg('assets/images/pagoda.png', height: 115, opacity: 0.9)),
            ),
            Positioned(
              bottom: 28,
              left: 6,
              child: IgnorePointer(child: _safeImg('assets/images/lantern.png', height: 78, opacity: 0.9)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  children: List.generate(
                    3,
                    (_) => Expanded(
                      child: Image.asset(
                        'assets/images/waves_gold.png',
                        height: 44,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Kelopak Sakura Jatuh 60fps
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _petalCtrl,
                  builder: (_, __) => CustomPaint(painter: _SakuraPetalPainter(_petalCtrl.value)),
                ),
              ),
            ),
          ),

          // Konten Layar Utama
          widget.child,
        ],
      ),
    );
  }
}

class JpMascotBadge extends StatelessWidget {
  final String bubbleText;
  final bool useGirl;
  const JpMascotBadge({super.key, required this.bubbleText, this.useGirl = false});

  @override
  Widget build(BuildContext context) {
    final path = useGirl ? 'assets/images/mascot_girl.png' : 'assets/images/mascot_boy.png';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          path,
          height: 138,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const CircleAvatar(
            radius: 40,
            backgroundColor: JpColors.gold,
            child: Icon(Icons.face, size: 44, color: JpColors.navy),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: JpColors.gold, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
            ),
            child: Text(
              bubbleText,
              style: const TextStyle(color: JpColors.navy, fontWeight: FontWeight.w800, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ],
    );
  }
}

class _SakuraPetalPainter extends CustomPainter {
  final double t;
  _SakuraPetalPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final petalPaint = Paint()..color = JpColors.sakuraDeep.withValues(alpha: 0.45);
    for (int i = 0; i < 8; i++) {
      final px = ((i * 0.14 + 0.06) * size.width) + sin((t * 2 * pi) + i) * 18;
      final py = ((t + i * 0.125) % 1.0) * size.height;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(t * 2 * pi + i);
      canvas.drawOval(const Rect.fromLTWH(-5, -3, 10, 6), petalPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SakuraPetalPainter oldDelegate) => oldDelegate.t != t;
}
