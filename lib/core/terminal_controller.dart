import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart' show BufferRange;
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range_line.dart';
import 'buffer/line.dart'; // Local CellAnchor

class TermuxTerminalController extends ChangeNotifier {
  BufferRange? _selection;
  BufferRange? get selection => _selection;

  void setSelection(CellAnchor begin, CellAnchor end) {
    // Using BufferRangeLine (static offsets).
    // Ideally we should use anchors to track text movement, but we can't mix local/xterm anchors.
    _selection = BufferRangeLine(
      CellOffset(begin.x, begin.y),
      CellOffset(end.x, end.y)
    );
    notifyListeners();
  }

  void clearSelection() {
    if (_selection != null) {
      _selection = null;
      notifyListeners();
    }
  }
}