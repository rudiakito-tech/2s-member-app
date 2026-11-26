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
    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '2S',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  letterSpacing: -1,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 6
                    ..color = JpColors.navy,
                ),
              ),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFFFFE066), Color(0xFFFFB300), Color(0xFFFF7A00)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(r),
                child: const Text(
                  '2S',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 0.95, letterSpacing: -1, color: Colors.white),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: JpColors.navy,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: JpColors.gold, width: 1.5),
            ),
            child: const Text(
              'MEMBER',
              style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.6),
            ),
          ),
        ],
      ),
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
              // Efek glossy atas
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
          if (widget.topFuji)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 155,
              child: RepaintBoundary(child: CustomPaint(painter: _JpSceneryPainter(isTop: true))),
            ),
          if (widget.bottomFuji)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 170,
              child: RepaintBoundary(child: CustomPaint(painter: _JpSceneryPainter(isTop: false))),
            ),
          // Kelopak sakura berjatuhan pelan di 60fps
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
          widget.child,
        ],
      ),
    );
  }
}

class JpMascotBadge extends StatelessWidget {
  final String bubbleText;
  const JpMascotBadge({super.key, required this.bubbleText});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)]),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: JpColors.orange.withValues(alpha: 0.3), blurRadius: 12)],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.face_retouching_natural, size: 46, color: JpColors.navy),
              Positioned(bottom: 4, right: 6, child: Icon(Icons.thumb_up_alt, size: 22, color: Color(0xFFD32F2F))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: JpColors.gold, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
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

class _JpSceneryPainter extends CustomPainter {
  final bool isTop;
  _JpSceneryPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gunung Fuji
    final fujiPath = Path()
      ..moveTo(w * 0.14, h)
      ..lineTo(w * 0.44, isTop ? h * 0.25 : h * 0.28)
      ..lineTo(w * 0.56, isTop ? h * 0.25 : h * 0.28)
      ..lineTo(w * 0.86, h)
      ..close();
    canvas.drawPath(
      fujiPath,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF4C76B8).withValues(alpha: 0.42), const Color(0xFF90B4E8).withValues(alpha: 0.18)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Salju puncak Fuji
    final snowPath = Path()
      ..moveTo(w * 0.44, isTop ? h * 0.25 : h * 0.28)
      ..lineTo(w * 0.56, isTop ? h * 0.25 : h * 0.28)
      ..lineTo(w * 0.63, isTop ? h * 0.47 : h * 0.50)
      ..lineTo(w * 0.54, isTop ? h * 0.42 : h * 0.45)
      ..lineTo(w * 0.50, isTop ? h * 0.48 : h * 0.51)
      ..lineTo(w * 0.45, isTop ? h * 0.42 : h * 0.45)
      ..lineTo(w * 0.37, isTop ? h * 0.47 : h * 0.50)
      ..close();
    canvas.drawPath(snowPath, Paint()..color = Colors.white.withValues(alpha: 0.85));

    // Siluet Pagoda di kanan
    final pagPaint = Paint()..color = const Color(0xFF9E2A2B).withValues(alpha: 0.68);
    for (int lvl = 0; lvl < 3; lvl++) {
      final y = h - 42 - (lvl * 22.0);
      final half = 26.0 - (lvl * 4.5);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.84, y), width: half * 2, height: 8), const Radius.circular(3)), pagPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.84, y + 10), width: half * 1.1, height: 12), pagPaint);
    }

    // Siluet Gerbang Torii di kiri
    final toriiPaint = Paint()..color = const Color(0xFFD32F2F).withValues(alpha: 0.72);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h - 72, 54, 7), const Radius.circular(3)), toriiPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.11, h - 60, 42, 5), toriiPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.14, h - 66, 6, 46), toriiPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.22, h - 66, 6, 46), toriiPaint);

    // Gelombang emas Seigaiha di dasar bawah
    if (!isTop) {
      final wavePaint = Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.6);
      final ringPaint = Paint()
        ..color = const Color(0xFFFFA000).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      for (double x = 0; x <= w + 36; x += 38) {
        canvas.drawCircle(Offset(x, h), 24, wavePaint);
        canvas.drawCircle(Offset(x, h), 24, ringPaint);
        canvas.drawCircle(Offset(x, h), 15, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SakuraPetalPainter extends CustomPainter {
  final double t;
  _SakuraPetalPainter(this.t);

  void _drawFlower(Canvas canvas, Offset center, double r, Color c) {
    final p = Paint()..color = c;
    for (int i = 0; i < 5; i++) {
      final a = (i * 2 * pi / 5) - pi / 2;
      canvas.drawCircle(Offset(center.dx + cos(a) * r * 0.65, center.dy + sin(a) * r * 0.65), r * 0.52, p);
    }
    canvas.drawCircle(center, r * 0.28, Paint()..color = const Color(0xFFFFE082));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Rumpun sakura sudut kanan & kiri atas
    _drawFlower(canvas, Offset(size.width - 26, 56), 14, JpColors.sakuraPink.withValues(alpha: 0.85));
    _drawFlower(canvas, Offset(size.width - 54, 42), 11, JpColors.sakuraDeep.withValues(alpha: 0.65));
    _drawFlower(canvas, Offset(size.width - 18, 92), 10, JpColors.sakuraPink.withValues(alpha: 0.75));
    _drawFlower(canvas, const Offset(28, 76), 12, JpColors.sakuraPink.withValues(alpha: 0.75));
    _drawFlower(canvas, const Offset(56, 58), 9, JpColors.sakuraDeep.withValues(alpha: 0.55));

    // 7 kelopak sakura jatuh perlahan
    final petalPaint = Paint()..color = JpColors.sakuraDeep.withValues(alpha: 0.45);
    for (int i = 0; i < 7; i++) {
      final px = ((i * 0.17 + 0.08) * size.width) + sin((t * 2 * pi) + i) * 16;
      final py = ((t + i * 0.14) % 1.0) * size.height;
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
