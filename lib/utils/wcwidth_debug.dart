/// wcwidth 调试工具
/// 用于诊断字符宽度计算问题

import 'termux_wcwidth.dart';

/// 调试模式开关
bool wcwidthDebugEnabled = false;

/// 调试日志缓冲
final List<String> wcwidthDebugLog = [];

/// 带调试的 wcwidth
int debugWcwidth(int ucs) {
  final width = termuxWcwidth(ucs);

  if (wcwidthDebugEnabled) {
    // 只记录可能有问题的字符
    // Powerline: U+E0A0-U+E0D4
    // Nerd Font: U+E000-U+F8FF (PUA)
    // Box Drawing: U+2500-U+257F
    // Block Elements: U+2580-U+259F
    // Geometric Shapes: U+25A0-U+25FF
    if ((ucs >= 0xE000 && ucs <= 0xF8FF) ||  // PUA (Nerd Font)
        (ucs >= 0x2500 && ucs <= 0x259F) ||  // Box Drawing + Block
        (ucs >= 0x25A0 && ucs <= 0x25FF) ||  // Geometric
        (ucs >= 0x2700 && ucs <= 0x27BF) ||  // Dingbats
        (ucs >= 0x1F300 && ucs <= 0x1F9FF)) { // Emoji
      final hex = ucs.toRadixString(16).toUpperCase().padLeft(4, '0');
      final char = String.fromCharCode(ucs);
      final name = _getCharName(ucs);
      wcwidthDebugLog.add('U+$hex ($char) width=$width $name');
    }
  }

  return width;
}

/// 获取字符名称（常见的特殊字符）
String _getCharName(int ucs) {
  final names = {
    // Powerline
    0xE0A0: 'PL Branch',
    0xE0A1: 'PL Line',
    0xE0A2: 'PL Lock',
    0xE0A3: 'PL Column',
    0xE0B0: 'PL Right Arrow',
    0xE0B1: 'PL Right Arrow Thin',
    0xE0B2: 'PL Left Arrow',
    0xE0B3: 'PL Left Arrow Thin',
    0xE0B4: 'PL Right Round',
    0xE0B5: 'PL Right Round Thin',
    0xE0B6: 'PL Left Round',
    0xE0B7: 'PL Left Round Thin',
    0xE0B8: 'PL Right Bottom',
    0xE0B9: 'PL Right Bottom Thin',
    0xE0BA: 'PL Left Bottom',
    0xE0BB: 'PL Left Bottom Thin',
    0xE0BC: 'PL Right Top',
    0xE0BD: 'PL Right Top Thin',
    0xE0BE: 'PL Left Top',
    0xE0BF: 'PL Left Top Thin',
    // Box Drawing
    0x2500: 'Horizontal',
    0x2502: 'Vertical',
    0x250C: 'Top-Left Corner',
    0x2510: 'Top-Right Corner',
    0x2514: 'Bottom-Left Corner',
    0x2518: 'Bottom-Right Corner',
    0x251C: 'T-Left',
    0x2524: 'T-Right',
    0x252C: 'T-Top',
    0x2534: 'T-Bottom',
    0x253C: 'Cross',
    // Block
    0x2580: 'Upper Half Block',
    0x2584: 'Lower Half Block',
    0x2588: 'Full Block',
    0x258C: 'Left Half Block',
    0x2590: 'Right Half Block',
    0x2591: 'Light Shade',
    0x2592: 'Medium Shade',
    0x2593: 'Dark Shade',
    // Common Nerd Font
    0xF015: 'NF Home',
    0xF07C: 'NF Folder Open',
    0xF113: 'NF Git Branch',
    0xF126: 'NF Git Commit',
    0xF1D3: 'NF Git',
    0xF268: 'NF Chrome',
    0xF120: 'NF Terminal',
    0xF121: 'NF Code',
    0xF07B: 'NF Folder',
    0xE712: 'NF Linux',
    0xE711: 'NF Apple',
    0xE70F: 'NF Windows',
  };
  return names[ucs] ?? '';
}

/// 打印调试日志
void printWcwidthDebugLog() {
  if (wcwidthDebugLog.isEmpty) {
    print('[wcwidth] No special characters logged');
    return;
  }
  print('[wcwidth] === Character Width Debug Log ===');
  for (final entry in wcwidthDebugLog) {
    print('[wcwidth] $entry');
  }
  print('[wcwidth] === End of Log (${wcwidthDebugLog.length} chars) ===');
}

/// 清空调试日志
void clearWcwidthDebugLog() {
  wcwidthDebugLog.clear();
}

/// 测试常见 Powerline/Nerd Font 字符
void testCommonCharacters() {
  print('=== Powerline Characters ===');
  final powerline = [
    0xE0A0, 0xE0A1, 0xE0A2, 0xE0B0, 0xE0B1, 0xE0B2, 0xE0B3,
    0xE0B4, 0xE0B5, 0xE0B6, 0xE0B7, 0xE0B8, 0xE0B9, 0xE0BA, 0xE0BB,
  ];
  for (final c in powerline) {
    final w = termuxWcwidth(c);
    final hex = c.toRadixString(16).toUpperCase().padLeft(4, '0');
    final char = String.fromCharCode(c);
    final name = _getCharName(c);
    print('U+$hex  $char  width=$w  $name');
  }

  print('\n=== Box Drawing Characters ===');
  final box = [
    0x2500, 0x2502, 0x250C, 0x2510, 0x2514, 0x2518,
    0x251C, 0x2524, 0x252C, 0x2534, 0x253C,
  ];
  for (final c in box) {
    final w = termuxWcwidth(c);
    final hex = c.toRadixString(16).toUpperCase().padLeft(4, '0');
    final char = String.fromCharCode(c);
    final name = _getCharName(c);
    print('U+$hex  $char  width=$w  $name');
  }

  print('\n=== Block Elements ===');
  final blocks = [0x2580, 0x2584, 0x2588, 0x258C, 0x2590, 0x2591, 0x2592, 0x2593];
  for (final c in blocks) {
    final w = termuxWcwidth(c);
    final hex = c.toRadixString(16).toUpperCase().padLeft(4, '0');
    final char = String.fromCharCode(c);
    final name = _getCharName(c);
    print('U+$hex  $char  width=$w  $name');
  }
}

/// 分析一段文本中的所有字符宽度
List<Map<String, dynamic>> analyzeText(String text) {
  final result = <Map<String, dynamic>>[];
  final runes = text.runes.toList();

  for (int i = 0; i < runes.length; i++) {
    final c = runes[i];
    final w = termuxWcwidth(c);
    final hex = c.toRadixString(16).toUpperCase().padLeft(4, '0');
    final char = String.fromCharCode(c);
    final name = _getCharName(c);

    result.add({
      'index': i,
      'codepoint': c,
      'hex': 'U+$hex',
      'char': char,
      'width': w,
      'name': name,
      'isPUA': c >= 0xE000 && c <= 0xF8FF,
      'isBox': c >= 0x2500 && c <= 0x257F,
      'isBlock': c >= 0x2580 && c <= 0x259F,
    });
  }

  return result;
}

/// 打印文本分析结果
void printTextAnalysis(String text) {
  final analysis = analyzeText(text);
  int totalWidth = 0;

  print('=== Text Analysis ===');
  print('Input: "$text"');
  print('Length: ${text.length} chars, ${text.runes.length} codepoints');
  print('');
  print('Idx  Hex      Char  Width  Name');
  print('---  -------  ----  -----  ----');

  for (final item in analysis) {
    final idx = item['index'].toString().padLeft(3);
    final hex = item['hex'];
    final char = item['char'];
    final width = item['width'];
    final name = item['name'];
    totalWidth += width as int;

    // 高亮可能有问题的字符
    String flag = '';
    if (item['isPUA'] == true) flag = '[PUA]';
    if (item['isBox'] == true) flag = '[BOX]';
    if (item['isBlock'] == true) flag = '[BLK]';

    print('$idx  $hex  $char     $width      $name $flag');
  }

  print('');
  print('Total calculated width: $totalWidth');
}
