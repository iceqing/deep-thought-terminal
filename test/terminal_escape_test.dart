import 'package:deep_thought/core/terminal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cursor position report uses one-based row and column', () {
    final output = <String>[];
    final terminal = TermuxTerminal(onOutput: output.add)..resize(80, 24);

    terminal.write('\x1b[3;17H');
    terminal.write('\x1b[6n');

    expect(output, equals(['\x1b[3;17R']));
  });

  test('setting scroll margins moves cursor to home', () {
    final terminal = TermuxTerminal(maxLines: 1000)..resize(80, 24);

    terminal.write('\x1b[10;20H');
    terminal.write('\x1b[5;15r');

    expect(terminal.buffer.marginTop, equals(4));
    expect(terminal.buffer.marginBottom, equals(14));
    expect(terminal.buffer.cursorX, equals(0));
    expect(terminal.buffer.cursorY, equals(0));
  });
}
