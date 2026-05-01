import 'package:deep_thought/core/terminal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial resize shrink drops empty padding rows', () {
    final terminal = TermuxTerminal(maxLines: 1000)..resize(80, 24);

    terminal.resize(80, 14);

    expect(terminal.buffer.scrollBack, equals(0));
    expect(terminal.buffer.lines.length, equals(14));
  });

  test('reverse index does not grow the main buffer', () {
    final terminal = TermuxTerminal(maxLines: 1000)..resize(80, 24);

    for (var i = 0; i < 23; i++) {
      terminal.write('row-$i\r\n');
    }
    terminal.write('bottom-row');

    terminal.write('\x1b[1;24r\x1b[1;1H\x1bM');

    expect(terminal.buffer.scrollBack, equals(0));
    expect(terminal.buffer.lines.length, equals(24));
    expect(terminal.buffer.lines[0].getText().trim(), isEmpty);
    expect(terminal.buffer.lines[1].getText().trim(), equals('row-0'));
  });

  test('partial top scroll region does not push fixed tail content', () {
    final terminal = TermuxTerminal(maxLines: 1000)..resize(80, 24);

    for (var i = 0; i < 23; i++) {
      terminal.write('row-$i\r\n');
    }
    terminal.write('fixed-tail');

    terminal.write('\x1b[1;17r\x1b[17;1H\r\n');

    expect(terminal.buffer.scrollBack, equals(0));
    expect(
      terminal.buffer.lines[23].getText().trim(),
      equals('fixed-tail'),
    );
  });

  test('main buffer resize shrink preserves bottom content', () {
    final terminal = TermuxTerminal(maxLines: 1000)..resize(80, 24);

    for (var i = 0; i < 23; i++) {
      terminal.write('row-$i\r\n');
    }
    terminal.write('bottom-row');

    terminal.write('\x1b[1;1H');
    terminal.resize(80, 14);

    expect(terminal.buffer.scrollBack, equals(10));
    expect(terminal.buffer.lines.length, equals(24));
    expect(
      terminal.buffer.lines[23].getText().trim(),
      equals('bottom-row'),
    );

    terminal.resize(80, 24);

    expect(terminal.buffer.scrollBack, equals(0));
    expect(
      terminal.buffer.lines[23].getText().trim(),
      equals('bottom-row'),
    );
  });

  test('resize with trailing empty line shows correct content', () {
    final terminal = TermuxTerminal(maxLines: 1000)..resize(80, 24);

    // Write 30 lines with \r\n
    for (var i = 0; i < 30; i++) {
      terminal.write('line-$i\r\n');
    }

    // Shrink viewport
    terminal.resize(80, 14);

    // The first visible line should be line-16 (not line-17)
    expect(terminal.buffer.lines[terminal.buffer.scrollBack].getText().trim(),
        equals('line-16'));
    // The last content line should be line-28 (line-29 was consumed by cursor positioning)
    // The trailing empty line was popped, so line-28 is at height-2
    expect(terminal.buffer.lines[terminal.buffer.height - 2].getText().trim(),
        equals('line-28'));
  });
}
