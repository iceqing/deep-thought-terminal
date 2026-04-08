import 'dart:convert';

class ExtraKeysPosition {
  static const top = 'top';
  static const bottom = 'bottom';

  static const values = [top, bottom];
}

class ExtraKeyIds {
  static const esc = 'ESC';
  static const tab = 'TAB';
  static const ctrl = 'CTRL';
  static const alt = 'ALT';
  static const home = 'HOME';
  static const end = 'END';
  static const pgup = 'PGUP';
  static const pgdn = 'PGDN';
  static const insert = 'INS';
  static const up = 'UP';
  static const down = 'DOWN';
  static const left = 'LEFT';
  static const right = 'RIGHT';
  static const enter = 'ENTER';
  static const backspace = 'DEL';
  static const deleteKey = 'FORWARD_DEL';
  static const minus = '-';
  static const slash = '/';
  static const pipe = '|';
  static const backslash = '\\';
  static const underscore = '_';
  static const tilde = '~';
  static const at = '@';
  static const hash = '#';
  static const dollar = r'$';
  static const percent = '%';
  static const caret = '^';
  static const ampersand = '&';
  static const asterisk = '*';
  static const equals = '=';
  static const plus = '+';
  static const colon = ':';
  static const semicolon = ';';
  static const quote = "'";
  static const doubleQuote = '"';
  static const backtick = '`';
  static const exclamation = '!';
  static const question = '?';
  static const lessThan = '<';
  static const greaterThan = '>';
  static const append = '>>';
  static const and = '&&';
  static const leftParen = '(';
  static const rightParen = ')';
  static const leftBracket = '[';
  static const rightBracket = ']';
  static const leftBrace = '{';
  static const rightBrace = '}';
  static const f1 = 'F1';
  static const f2 = 'F2';
  static const f3 = 'F3';
  static const f4 = 'F4';
  static const f5 = 'F5';
  static const f6 = 'F6';
  static const f7 = 'F7';
  static const f8 = 'F8';
  static const f9 = 'F9';
  static const f10 = 'F10';
  static const f11 = 'F11';
  static const f12 = 'F12';
  static const menu = 'MENU';

  static const common = [
    esc,
    tab,
    ctrl,
    alt,
    enter,
    backspace,
    deleteKey,
    minus,
    slash,
  ];

  static const navigation = [
    home,
    end,
    pgup,
    pgdn,
    insert,
    up,
    down,
    left,
    right,
  ];

  static const symbols = [
    pipe,
    greaterThan,
    append,
    ampersand,
    and,
    semicolon,
    backslash,
    slash,
    tilde,
    backtick,
    exclamation,
    at,
    hash,
    dollar,
    percent,
    caret,
    asterisk,
    plus,
    minus,
    equals,
    underscore,
    colon,
    lessThan,
    question,
    leftParen,
    rightParen,
    leftBracket,
    rightBracket,
    leftBrace,
    rightBrace,
    quote,
    doubleQuote,
  ];

  static const functionKeys = [
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
  ];

  static const pickerIds = [
    ...common,
    ...navigation,
    ...symbols,
    ...functionKeys,
  ];

  static const supportedIds = [...pickerIds, menu];
}

class ExtraKeysLayoutConfig {
  static const rowCount = 2;
  static const columnCount = 7;
  static const lockedMenuRow = 1;
  static const lockedMenuColumn = 3;

  static const defaultRows = [
    [
      ExtraKeyIds.esc,
      ExtraKeyIds.ctrl,
      ExtraKeyIds.alt,
      ExtraKeyIds.minus,
      ExtraKeyIds.home,
      ExtraKeyIds.up,
      ExtraKeyIds.end,
    ],
    [
      ExtraKeyIds.tab,
      ExtraKeyIds.slash,
      ExtraKeyIds.enter,
      ExtraKeyIds.menu,
      ExtraKeyIds.left,
      ExtraKeyIds.down,
      ExtraKeyIds.right,
    ],
  ];

  final String position;
  final List<List<String>> rows;

  ExtraKeysLayoutConfig._({
    required this.position,
    required this.rows,
  });

  factory ExtraKeysLayoutConfig({
    required String position,
    required List<List<String>> rows,
  }) {
    final normalizedPosition = ExtraKeysPosition.values.contains(position)
        ? position
        : ExtraKeysPosition.bottom;
    final normalizedRows = _sanitizeRows(rows);

    return ExtraKeysLayoutConfig._(
      position: normalizedPosition,
      rows: List<List<String>>.unmodifiable(
        normalizedRows
            .map((row) => List<String>.unmodifiable(row))
            .toList(growable: false),
      ),
    );
  }

  factory ExtraKeysLayoutConfig.defaults() {
    return ExtraKeysLayoutConfig(
      position: ExtraKeysPosition.bottom,
      rows: defaultRows,
    );
  }

  factory ExtraKeysLayoutConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ExtraKeysLayoutConfig.defaults();

    final decodedRows = <List<String>>[];
    final rawRows = json['rows'];
    if (rawRows is List) {
      for (final row in rawRows) {
        if (row is List) {
          decodedRows.add(row.map((value) => value.toString()).toList());
        }
      }
    }

    return ExtraKeysLayoutConfig(
      position: json['position']?.toString() ?? ExtraKeysPosition.bottom,
      rows: decodedRows,
    );
  }

  factory ExtraKeysLayoutConfig.fromPreferenceString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ExtraKeysLayoutConfig.defaults();
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return ExtraKeysLayoutConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return ExtraKeysLayoutConfig.fromJson(
          decoded.map(
            (key, item) => MapEntry(key.toString(), item),
          ),
        );
      }
    } catch (_) {
      // Ignore invalid serialized values and fall back to defaults.
    }

    return ExtraKeysLayoutConfig.defaults();
  }

  Map<String, dynamic> toJson() {
    return {
      'position': position,
      'rows': rows,
    };
  }

  String toPreferenceString() => jsonEncode(toJson());

  ExtraKeysLayoutConfig copyWith({
    String? position,
    List<List<String>>? rows,
  }) {
    return ExtraKeysLayoutConfig(
      position: position ?? this.position,
      rows: rows ?? this.rows,
    );
  }

  ExtraKeysLayoutConfig updateKeyAt(int row, int column, String keyId) {
    if (!isEditableCell(row, column)) return this;
    if (!ExtraKeyIds.pickerIds.contains(keyId)) return this;
    if (rows[row][column] == keyId) return this;

    final nextRows = rows.map((item) => List<String>.from(item)).toList();
    final previousValue = nextRows[row][column];

    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) {
        if (!isEditableCell(rowIndex, columnIndex)) continue;
        if (nextRows[rowIndex][columnIndex] != keyId) continue;
        nextRows[rowIndex][columnIndex] = previousValue;
        nextRows[row][column] = keyId;
        return copyWith(rows: nextRows);
      }
    }

    nextRows[row][column] = keyId;
    return copyWith(rows: nextRows);
  }

  ExtraKeysLayoutConfig updatePosition(String nextPosition) {
    return copyWith(position: nextPosition);
  }

  static bool isEditableCell(int row, int column) {
    return row != lockedMenuRow || column != lockedMenuColumn;
  }

  static List<List<String>> _sanitizeRows(List<List<String>> rows) {
    return List<List<String>>.generate(rowCount, (rowIndex) {
      final sourceRow = rowIndex < rows.length ? rows[rowIndex] : const [];

      return List<String>.generate(columnCount, (columnIndex) {
        if (!isEditableCell(rowIndex, columnIndex)) {
          return ExtraKeyIds.menu;
        }

        final rawValue =
            columnIndex < sourceRow.length ? sourceRow[columnIndex] : null;
        final fallback = defaultRows[rowIndex][columnIndex];
        final normalized = rawValue?.trim();

        if (normalized == null ||
            !ExtraKeyIds.supportedIds.contains(normalized) ||
            normalized == ExtraKeyIds.menu) {
          return fallback;
        }

        return normalized;
      });
    });
  }
}
