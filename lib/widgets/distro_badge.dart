import 'package:flutter/material.dart';

class DistroBadge extends StatelessWidget {
  final String alias;
  final String displayName;
  final double size;
  final double fontSize;
  final BorderRadius? borderRadius;

  const DistroBadge({
    super.key,
    required this.alias,
    required this.displayName,
    this.size = 40,
    this.fontSize = 14,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _paletteForAlias(alias);
    final label = _monogramFor(displayName, alias);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius ??
            BorderRadius.circular((size * 0.34).roundToDouble()),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          letterSpacing: label.length > 1 ? 0.2 : 0,
        ),
      ),
    );
  }

  static String _monogramFor(String displayName, String alias) {
    const presets = {
      'ubuntu': 'U',
      'debian': 'D',
      'archlinux': 'AR',
      'alpine': 'AL',
      'opensuse': 'OS',
      'rockylinux': 'RL',
      'almalinux': 'AM',
      'void': 'V',
      'fedora': 'F',
      'manjaro': 'M',
      'artix': 'AX',
    };

    final preset = presets[alias.toLowerCase()];
    if (preset != null) {
      return preset;
    }

    final parts = displayName
        .split(RegExp(r'[\s\-_]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (displayName.isNotEmpty) {
      return displayName.substring(0, 1).toUpperCase();
    }
    return alias.substring(0, 1).toUpperCase();
  }

  static List<Color> _paletteForAlias(String alias) {
    switch (alias.toLowerCase()) {
      case 'ubuntu':
        return const [Color(0xFFF4743B), Color(0xFFC13C2C)];
      case 'debian':
        return const [Color(0xFFD84D87), Color(0xFFA81D5D)];
      case 'archlinux':
        return const [Color(0xFF3EA5FF), Color(0xFF0F6BCF)];
      case 'alpine':
        return const [Color(0xFF38BDF8), Color(0xFF0F4DB6)];
      case 'opensuse':
        return const [Color(0xFF8CE058), Color(0xFF319C32)];
      case 'rockylinux':
        return const [Color(0xFF2AC084), Color(0xFF0F7F62)];
      case 'almalinux':
        return const [Color(0xFF8A6BFF), Color(0xFF4E3CCB)];
      case 'void':
        return const [Color(0xFF46D3AE), Color(0xFF11806A)];
      case 'fedora':
        return const [Color(0xFF5AA2FF), Color(0xFF195DCB)];
      case 'manjaro':
        return const [Color(0xFF44D7AF), Color(0xFF13866D)];
      case 'artix':
        return const [Color(0xFF9A83FF), Color(0xFF5C49CA)];
      default:
        return const [Color(0xFF6B88FF), Color(0xFF4158C9)];
    }
  }
}
