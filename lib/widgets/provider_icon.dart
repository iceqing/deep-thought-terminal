import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hand-painted brand icons for AI providers.
/// Each icon is drawn via CustomPainter to match official logos closely.
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
    final brightness = Theme.of(context).brightness;
    // For dark-on-dark providers, lighten in dark mode
    var effectiveColor = color;
    if (brightness == Brightness.dark) {
      if (color.red < 50 && color.green < 50 && color.blue < 50) {
        effectiveColor = Color.lerp(color, Colors.white, 0.8)!;
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ProviderIconPainter(
          key: providerKey,
          color: effectiveColor,
        ),
      ),
    );
  }
}

class _ProviderIconPainter extends CustomPainter {
  final String key;
  final Color color;

  _ProviderIconPainter({required this.key, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    switch (key) {
      case 'openai':        _paintOpenAI(canvas, size);
      case 'anthropic':     _paintAnthropic(canvas, size);
      case 'openrouter':     _paintOpenRouter(canvas, size);
      case 'groq':           _paintGroq(canvas, size);
      case 'ollama':         _paintOllama(canvas, size);
      case 'mistral':        _paintMistral(canvas, size);
      case 'cohere':          _paintCohere(canvas, size);
      case 'deepseek':        _paintDeepSeek(canvas, size);
      case 'xiaomi':          _paintXiaomi(canvas, size);
      case 'minimax':
      case 'minimax_openai': _paintMiniMax(canvas, size);
      case 'siliconflow':     _paintSiliconFlow(canvas, size);
      case 'qwen':            _paintQwen(canvas, size);
      case 'volcengine':      _paintVolcEngine(canvas, size);
      case 'moonshot':        _paintMoonshot(canvas, size);
      case 'zhipu':           _paintZhipu(canvas, size);
      case 'yi':              _paintYi(canvas, size);
      case 'stepfun':         _paintStepfun(canvas, size);
      case 'baidu':           _paintBaidu(canvas, size);
      case 'custom':          _paintCustom(canvas, size);
      default:                _paintCustom(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _ProviderIconPainter old) =>
      old.key != key || old.color != color;

  Paint get _p => Paint()..color = color..style = PaintingStyle.fill;

  Paint _ps(double strokeWidth) =>
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  // ── OpenAI: orbital logo ──
  // Official: circle with an inner O shape and orbital dots
  void _paintOpenAI(Canvas canvas, Size s) {
    final w = s.width;
    final c = Offset(w / 2, w / 2);
    final outerR = w * 0.42;
    final innerR = w * 0.22;

    // Outer ring
    canvas.drawCircle(c, outerR, _ps(w * 0.07));
    // Inner O ring
    canvas.drawCircle(c, innerR, _ps(w * 0.07));
    // Center dot
    canvas.drawCircle(c, w * 0.04, _p);
    // Orbital dots
    for (var i = 0; i < 3; i++) {
      final angle = i * math.pi * 2 / 3 - math.pi / 2;
      final ox = c.dx + outerR * math.cos(angle);
      final oy = c.dy + outerR * math.sin(angle);
      canvas.drawCircle(Offset(ox, oy), w * 0.045, _p);
    }
  }

  // ── Anthropic: stylized arrow-A / spark ──
  // Official: three diagonal strokes forming a right-pointing arrow
  void _paintAnthropic(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;
    final gap = w * 0.09;

    // Three diagonal bars, angled like →
    for (var i = 0; i < 3; i++) {
      final yBase = w * 0.2 + i * gap * 2.2;
      final path = Path();
      path.moveTo(w * 0.18, yBase + gap * 2);
      path.lineTo(w * 0.82, yBase + gap);
      path.lineTo(w * 0.82, yBase + gap * 2);
      path.lineTo(w * 0.18, yBase + gap * 3);
      path.close();
      canvas.drawPath(path, p);
    }
  }

  // ── OpenRouter: diamond within diamond ──
  // Official: diamond with OR text, simplified to nested diamonds
  void _paintOpenRouter(Canvas canvas, Size s) {
    final w = s.width;
    final c = Offset(w / 2, w / 2);
    final r = w * 0.36;

    // Outer diamond
    final outer = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(outer, _ps(w * 0.065));

    // Inner diamond
    final ir = r * 0.48;
    final inner = Path()
      ..moveTo(c.dx, c.dy - ir)
      ..lineTo(c.dx + ir, c.dy)
      ..lineTo(c.dx, c.dy + ir)
      ..lineTo(c.dx - ir, c.dy)
      ..close();
    canvas.drawPath(inner, _ps(w * 0.05));

    // Center dot
    canvas.drawCircle(c, w * 0.04, _p);
  }

  // ── Groq: clean lightning bolt ──
  void _paintGroq(Canvas canvas, Size s) {
    final w = s.width;
    final path = Path()
      ..moveTo(w * 0.62, w * 0.06)
      ..lineTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.46, w * 0.52)
      ..lineTo(w * 0.36, w * 0.94)
      ..lineTo(w * 0.76, w * 0.46)
      ..lineTo(w * 0.54, w * 0.46)
      ..close();
    canvas.drawPath(path, _p);
  }

  // ── Ollama: minimalist llama head ──
  void _paintOllama(Canvas canvas, Size s) {
    final w = s.width;
    final paint = _p;

    // Rounded square background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.1, w * 0.1, w * 0.8, w * 0.8),
        Radius.circular(w * 0.2),
      ),
      paint,
    );

    // White llama face inside
    final facePaint = Paint()..color = Colors.white;
    final path = Path()
      // Left ear
      ..moveTo(w * 0.28, w * 0.32)
      ..lineTo(w * 0.2, w * 0.15)
      ..lineTo(w * 0.35, w * 0.28)
      // Head top
      ..lineTo(w * 0.5, w * 0.2)
      // Right ear
      ..lineTo(w * 0.65, w * 0.28)
      ..lineTo(w * 0.8, w * 0.15)
      ..lineTo(w * 0.72, w * 0.32)
      // Right face
      ..quadraticBezierTo(w * 0.88, w * 0.42, w * 0.82, w * 0.55)
      // Snout
      ..quadraticBezierTo(w * 0.78, w * 0.68, w * 0.65, w * 0.72)
      // Neck left
      ..quadraticBezierTo(w * 0.48, w * 0.78, w * 0.3, w * 0.7)
      // Snout left
      ..quadraticBezierTo(w * 0.22, w * 0.62, w * 0.18, w * 0.52)
      ..quadraticBezierTo(w * 0.12, w * 0.42, w * 0.28, w * 0.32)
      ..close();
    canvas.drawPath(path, facePaint);

    // Eyes
    canvas.drawCircle(Offset(w * 0.38, w * 0.42), w * 0.03, Paint()..color = color);
    canvas.drawCircle(Offset(w * 0.62, w * 0.42), w * 0.03, Paint()..color = color);
  }

  // ── Mistral: vertical M stripes ──
  // Official: stylized "M" made of diagonal stripes
  void _paintMistral(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;

    // Background rounded rect
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, w * 0.08, w * 0.84, w * 0.84),
        Radius.circular(w * 0.14),
      ),
      p,
    );

    // M shape in white
    final wp = Paint()..color = Colors.white;
    final sw = w * 0.13;
    final path = Path()
      ..moveTo(w * 0.18, w * 0.72)
      ..lineTo(w * 0.18, w * 0.3)
      ..lineTo(w * 0.38, w * 0.52)
      ..lineTo(w * 0.58, w * 0.3)
      ..lineTo(w * 0.58, w * 0.72)
      ..moveTo(w * 0.22, w * 0.72)
      ..lineTo(w * 0.26, w * 0.72)
      ..lineTo(w * 0.26, w * 0.36)
      ..lineTo(w * 0.38, w * 0.52)
      ..lineTo(w * 0.5, w * 0.36)
      ..lineTo(w * 0.5, w * 0.72)
      ..lineTo(w * 0.54, w * 0.72)
      ..lineTo(w * 0.54, w * 0.3)
      ..lineTo(w * 0.58, w * 0.3)
      ..lineTo(w * 0.58, w * 0.72)
      ..close();
    canvas.drawPath(path, wp);
  }

  // ── Cohere: three overlapping circles (triangular) ──
  void _paintCohere(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;
    final r = w * 0.2;
    final c = Offset(w / 2, w / 2);

    // Bottom-left circle
    canvas.drawCircle(Offset(c.dx - r * 0.6, c.dy + r * 0.3), r, p);
    // Bottom-right circle
    canvas.drawCircle(Offset(c.dx + r * 0.6, c.dy + r * 0.3), r, p);
    // Top circle
    canvas.drawCircle(Offset(c.dx, c.dy - r * 0.5), r, p);
  }

  // ── DeepSeek: whale tail ──
  void _paintDeepSeek(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;

    // Whale body
    final body = Path()
      ..moveTo(w * 0.1, w * 0.5)
      ..quadraticBezierTo(w * 0.08, w * 0.28, w * 0.3, w * 0.22)
      ..quadraticBezierTo(w * 0.55, w * 0.15, w * 0.78, w * 0.28)
      ..quadraticBezierTo(w * 0.92, w * 0.38, w * 0.88, w * 0.52)
      ..quadraticBezierTo(w * 0.85, w * 0.68, w * 0.65, w * 0.74)
      ..quadraticBezierTo(w * 0.4, w * 0.82, w * 0.1, w * 0.5)
      ..close();
    canvas.drawPath(body, p);

    // Tail fin
    final tail = Path()
      ..moveTo(w * 0.78, w * 0.28)
      ..quadraticBezierTo(w * 0.92, w * 0.15, w * 0.92, w * 0.3)
      ..quadraticBezierTo(w * 0.92, w * 0.45, w * 0.88, w * 0.52)
      ..close();
    canvas.drawPath(tail, p);

    // Eye (white)
    canvas.drawCircle(Offset(w * 0.55, w * 0.4), w * 0.045, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.56, w * 0.4), w * 0.018, p);
  }

  // ── Xiaomi: MI square logo ──
  void _paintXiaomi(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;

    // Orange square
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, w * 0.08, w * 0.84, w * 0.84),
        Radius.circular(w * 0.18),
      ),
      p,
    );

    // White MI text drawn as shapes
    final wp = Paint()..color = Colors.white;
    // M
    final m = Path()
      ..moveTo(w * 0.18, w * 0.7)
      ..lineTo(w * 0.18, w * 0.32)
      ..lineTo(w * 0.3, w * 0.32)
      ..lineTo(w * 0.3, w * 0.55)
      ..lineTo(w * 0.37, w * 0.42)
      ..lineTo(w * 0.44, w * 0.55)
      ..lineTo(w * 0.44, w * 0.32)
      ..lineTo(w * 0.56, w * 0.32)
      ..lineTo(w * 0.56, w * 0.7)
      ..lineTo(w * 0.46, w * 0.7)
      ..lineTo(w * 0.37, w * 0.5)
      ..lineTo(w * 0.28, w * 0.7)
      ..close();
    canvas.drawPath(m, wp);

    // I (rect + dot)
    canvas.drawRect(Rect.fromLTWH(w * 0.6, w * 0.42, w * 0.14, w * 0.28), wp);
    canvas.drawCircle(Offset(w * 0.67, w * 0.34), w * 0.05, wp);
  }

  // ── MiniMax: triangle ──
  void _paintMiniMax(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;

    // Inverted triangle (MiniMax logo style)
    final tri = Path()
      ..moveTo(w * 0.5, w * 0.14)
      ..lineTo(w * 0.88, w * 0.82)
      ..lineTo(w * 0.12, w * 0.82)
      ..close();
    canvas.drawPath(tri, p);

    // Inner triangle (cutout effect in white)
    final inner = Path()
      ..moveTo(w * 0.5, w * 0.28)
      ..lineTo(w * 0.76, w * 0.72)
      ..lineTo(w * 0.24, w * 0.72)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.white.withValues(alpha: 0.35));
  }

  // ── SiliconFlow: flowing wave ──
  void _paintSiliconFlow(Canvas canvas, Size s) {
    final w = s.width;
    final sw = w * 0.065;

    for (var i = 0; i < 4; i++) {
      final y = w * (0.2 + i * 0.17);
      final path = Path()
        ..moveTo(w * 0.08, y)
        ..cubicTo(w * 0.22, y - w * 0.1,
                   w * 0.4, y + w * 0.08,
                   w * 0.55, y)
        ..cubicTo(w * 0.7, y - w * 0.06,
                   w * 0.82, y + w * 0.04,
                   w * 0.92, y);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 1.0 - i * 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ── Qwen (通义千问): circle with Q tail ──
  void _paintQwen(Canvas canvas, Size s) {
    final w = s.width;
    final c = Offset(w / 2, w / 2);

    // Outer ring
    canvas.drawCircle(c, w * 0.38, _ps(w * 0.08));
    // Inner small circle (the hole of Q)
    canvas.drawCircle(c, w * 0.1, Paint()..color = color);
    // Q tail
    final tail = Path()
      ..moveTo(c.dx + w * 0.2, c.dy + w * 0.18)
      ..lineTo(c.dx + w * 0.42, c.dy + w * 0.42);
    canvas.drawPath(tail, _ps(w * 0.1));
  }

  // ── VolcEngine: volcano ──
  void _paintVolcEngine(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;

    // Volcano body (trapezoid with rounded top)
    final body = Path()
      ..moveTo(w * 0.08, w * 0.88)
      ..lineTo(w * 0.3, w * 0.32)
      ..quadraticBezierTo(w * 0.5, w * 0.18, w * 0.7, w * 0.32)
      ..lineTo(w * 0.92, w * 0.88)
      ..close();
    canvas.drawPath(body, p);

    // Lava glow inside
    final lava = Paint()..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.35, w * 0.35, w * 0.3, w * 0.2),
        Radius.circular(w * 0.08),
      ),
      lava,
    );

    // Smoke puff
    final smoke = Paint()..color = color.withValues(alpha: 0.4);
    canvas.drawCircle(Offset(w * 0.35, w * 0.18), w * 0.06, smoke);
    canvas.drawCircle(Offset(w * 0.5, w * 0.1), w * 0.07, smoke);
    canvas.drawCircle(Offset(w * 0.65, w * 0.18), w * 0.05, smoke);
  }

  // ── Moonshot (Kimi): crescent moon ──
  void _paintMoonshot(Canvas canvas, Size s) {
    final w = s.width;
    final c = Offset(w / 2, w / 2);

    final full = Path()..addOval(Rect.fromCircle(center: c, radius: w * 0.4));
    final cut = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(c.dx + w * 0.22, c.dy - w * 0.08),
        radius: w * 0.3,
      ));

    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cut),
      _p,
    );

    // Kimi text suggestion: small circle for "i" dot
    canvas.drawCircle(
      Offset(c.dx - w * 0.12, c.dy - w * 0.28),
      w * 0.035,
      Paint()..color = color,
    );
  }

  // ── Zhipu GLM: hexagon with network ──
  void _paintZhipu(Canvas canvas, Size s) {
    final w = s.width;
    final c = Offset(w / 2, w / 2);
    final r = w * 0.38;

    // Hexagon outline
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 6;
      final x = c.dx + r * math.cos(angle);
      final y = c.dy + r * math.sin(angle);
      if (i == 0) {
        hex.moveTo(x, y);
      } else {
        hex.lineTo(x, y);
      }
    }
    hex.close();
    canvas.drawPath(hex, _ps(w * 0.06));

    // Internal network nodes
    final nodes = [
      c,
      Offset(c.dx, c.dy - r * 0.55),
      Offset(c.dx - r * 0.48, c.dy + r * 0.3),
      Offset(c.dx + r * 0.48, c.dy + r * 0.3),
    ];
    final np = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final ep = _ps(w * 0.04);
    final edges = [[0, 1], [0, 2], [0, 3], [2, 3]];
    for (final e in edges) {
      canvas.drawLine(nodes[e[0]], nodes[e[1]], ep);
    }
    for (final n in nodes) {
      canvas.drawCircle(n, w * 0.06, np);
    }
  }

  // ── Yi (零一万物): "01" stylized ──
  void _paintYi(Canvas canvas, Size s) {
    final w = s.width;
    final sw = w * 0.1;
    final p = _ps(sw);

    // "0" oval
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.3, w * 0.5), width: w * 0.28, height: w * 0.46),
      p,
    );

    // "1" with serif
    final one = Path()
      ..moveTo(w * 0.56, w * 0.28)
      ..lineTo(w * 0.7, w * 0.22)
      ..lineTo(w * 0.7, w * 0.76)
      ..moveTo(w * 0.56, w * 0.76)
      ..lineTo(w * 0.84, w * 0.76);
    canvas.drawPath(one, p);
  }

  // ── Stepfun (阶跃星辰): rising steps ──
  void _paintStepfun(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;
    final step = w * 0.2;

    // Four ascending rectangles (steps)
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          w * 0.1 + i * step * 0.7,
          w * 0.78 - (i + 1) * step,
          step,
          step,
        ),
        p,
      );
    }

    // Star at top-right
    _drawStar(canvas, Offset(w * 0.82, w * 0.18), w * 0.1, _p);
  }

  // ── Baidu: bear paw print ──
  void _paintBaidu(Canvas canvas, Size s) {
    final w = s.width;
    final p = _p;

    // Main pad (large oval)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, w * 0.6),
        width: w * 0.46,
        height: w * 0.36,
      ),
      p,
    );

    // Toe pads (5 ovals arranged in arc above main pad)
    final toes = [
      Offset(w * 0.2, w * 0.32),
      Offset(w * 0.36, w * 0.22),
      Offset(w * 0.52, w * 0.18),
      Offset(w * 0.68, w * 0.22),
      Offset(w * 0.82, w * 0.32),
    ];
    for (final toe in toes) {
      canvas.drawOval(
        Rect.fromCenter(center: toe, width: w * 0.16, height: w * 0.2),
        p,
      );
    }
  }

  // ── Custom: gear ──
  void _paintCustom(Canvas canvas, Size s) {
    final w = s.width;
    final c = Offset(w / 2, w / 2);
    final outer = w * 0.4;
    final inner = w * 0.26;
    const teeth = 8;

    final path = Path();
    for (var i = 0; i < teeth * 2; i++) {
      final angle = (i * math.pi / teeth) - math.pi / 2;
      final r = i.isEven ? outer : inner;
      final x = c.dx + r * math.cos(angle);
      final y = c.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, _p);
    // Center hole
    canvas.drawCircle(c, w * 0.12, Paint()..color = Colors.white);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = (i * math.pi / 5) - math.pi / 2;
      final radius = i.isEven ? r : r * 0.4;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
