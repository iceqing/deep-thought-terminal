import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Provider icon widget.
/// Loads the official PNG from assets if available, falls back to
/// a generated icon (gear) if not found.
class ProviderIcon extends StatelessWidget {
  final String providerKey;
  final Color color;
  final double size;

  const ProviderIcon({
    super.key,
    required this.providerKey,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedKey = _normalizeKey(providerKey);
    final assetPath = 'assets/icon/providers/$normalizedKey.png';

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _FallbackIcon(color: color, size: size);
        },
      ),
    );
  }

  String _normalizeKey(String key) {
    if (key == 'minimax_openai') return 'minimax';
    return key;
  }
}

class _FallbackIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _FallbackIcon({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _FallbackGearPainter(color: color),
      ),
    );
  }
}

class _FallbackGearPainter extends CustomPainter {
  final Color color;

  _FallbackGearPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w / 2);
    final outer = w * 0.4;
    final inner = w * 0.26;
    const teeth = 8;

    final path = Path();
    for (var i = 0; i < teeth * 2; i++) {
      final angle = (i * math.pi / teeth) - math.pi / 2;
      final rad = i.isEven ? outer : inner;
      final x = c.dx + rad * math.cos(angle);
      final y = c.dy + rad * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      w * 0.14,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(covariant _FallbackGearPainter old) =>
      old.color != color;
}
