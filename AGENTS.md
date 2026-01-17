# AGENTS.md - Development Guidelines for Agentic Coding

This file provides comprehensive guidelines for agentic coding agents working on the Deep Thought Flutter terminal emulator project.

## Project Overview

**Deep Thought** is a Flutter terminal emulator inspired by Termux. The project follows a Provider-based state management pattern with clean architecture separation.

### Architecture
- **State Management**: Provider pattern with `SettingsProvider` and `TerminalProvider`
- **Terminal Engine**: xterm ^4.0.0 for terminal emulation
- **UI Framework**: Flutter with Material Design 3
- **Platforms**: Linux, Android, macOS, Windows (Flutter multi-platform)

## Build & Development Commands

### Essential Commands
```bash
# Get dependencies
flutter pub get

# Run on Linux desktop
flutter run -d linux

# Run on Android device/emulator
flutter run -d android

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>

# Build releases
flutter build linux
flutter build apk
flutter build appbundle

# Code analysis and formatting
flutter analyze          # Run static analysis
flutter format .         # Format all Dart files
dart fix --dry-run       # Preview automatic fixes
dart fix --apply         # Apply automatic fixes
```

### Testing Commands
```bash
# Run all tests
flutter test

# Run single test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Run tests in debug mode
flutter test --debug

# Run tests with verbose output
flutter test --reporter expanded
```

### Platform-Specific Commands
```bash
# Android
flutter build apk --release
flutter install  # Install on connected device

# Linux
flutter build linux
./build/linux/x64/release/deep_thought

# Check platform readiness
flutter doctor
```

## Code Style Guidelines

### Import Organization
```dart
// 1. Dart core packages first
import 'dart:convert';
import 'dart:io';

// 2. Flutter framework
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. External packages (alphabetical)
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';

// 4. Local relative imports (alphabetical)
import '../models/terminal_session.dart';
import '../providers/settings_provider.dart';
import '../screens/terminal_screen.dart';
import '../themes/terminal_themes.dart';
import '../utils/constants.dart';
```

### Naming Conventions

#### Classes & Types
- **Classes**: PascalCase (`TerminalProvider`, `SettingsProvider`)
- **Constants**: PascalCase (`AppConstants`, `DefaultSettings`)
- **Enums**: PascalCase (`TerminalTheme`)
- **Private classes**: Leading underscore (`_LoadingScreen`)

#### Files
- **File names**: snake_case (`terminal_provider.dart`, `settings_screen.dart`)
- **Match file name to primary class**: `settings_provider.dart` → `SettingsProvider`

#### Variables & Functions
- **Variables**: camelCase (`terminalSessions`, `currentIndex`)
- **Functions**: camelCase (`createSession()`, `switchToSession()`)
- **Private members**: Leading underscore (`_sessions`, `_currentIndex`)
- **Constants**: camelCase for values, but class names in PascalCase
```dart
static const String fontFamily = 'Roboto Mono';  // Class constant
final String userName = 'john';                    // Variable
```

#### Widgets
- **Stateful widgets**: `WidgetName` + `State<WidgetName>`
```dart
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  // Implementation
}
```

### Code Formatting

#### Function Signatures
```dart
// Good: Separate parameters with new line if > 2 parameters
PreferredSizeWidget _buildAppBar(
  BuildContext context,
  TerminalProvider terminalProvider,
  SettingsProvider settings,
) {
  // Implementation
}

// Good: Short functions can be single line
void dispose() {
  _terminalFocusNode.dispose();
  super.dispose();
}
```

#### Widget Composition
```dart
// Good: Use trailing commas for better formatting
return Scaffold(
  key: _scaffoldKey,
  backgroundColor: settings.terminalTheme.background,
  appBar: _buildAppBar(context, terminalProvider, settings),
  drawer: SessionDrawer(
    onSettingsTap: () => _openSettings(context),
  ),
  body: SafeArea(
    child: Column(
      children: [
        // Widget children
      ],
    ),
  ),
);
```

#### List and Map Literals
```dart
// Use const for compile-time constants
static const List<String> fonts = [
  'Roboto Mono',
  'Fira Code',
  'Ubuntu Mono',
];

static const Map<String, TerminalTheme> themes = {
  'default': _defaultTheme,
  'dracula': _draculaTheme,
};
```

### Type Annotations

#### Prefer Type Inference for Local Variables
```dart
// Good: Type inference
final sessions = <TerminalSession>[];
final currentSession = terminalProvider.currentSession;

// Explicit types for public fields
class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _initialized = false;
}
```

#### Return Type Annotations
```dart
// Always specify return types
Future<void> setFontFamily(String value) async {
  // Implementation
}

Widget buildTerminalView(BuildContext context) {
  // Implementation
}
```

### Error Handling Patterns

#### Async Error Handling
```dart
Future<void> init() async {
  try {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    _initialized = true;
    notifyListeners();
  } catch (e) {
    // Handle error appropriately
    debugPrint('Failed to initialize settings: $e');
  }
}
```

#### Null Safety
```dart
// Use null-aware operators
TerminalSession? get currentSession {
  if (_currentIndex >= 0 && _currentIndex < _sessions.length) {
    return _sessions[_currentIndex];
  }
  return null;
}

// Use late for non-nullable fields initialized in init()
late SharedPreferences _prefs;
```

### Widget Patterns

#### Build Method Organization
```dart
@override
Widget build(BuildContext context) {
  // 1. Get providers
  final settings = context.watch<SettingsProvider>();
  final terminalProvider = context.watch<TerminalProvider>();

  // 2. Early returns for loading states
  if (!settings.initialized) {
    return const LoadingScreen();
  }

  // 3. Build widget tree
  return Scaffold(
    // Widget implementation
  );
}
```

#### Provider Consumer Pattern
```dart
// Consumer pattern for selective rebuilding
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Text('Font size: ${settings.fontSize}');
      },
    );
  }
}
```

### Documentation Patterns

#### Class Documentation
```dart
/// 设置状态管理
/// 参考 termux-app: TermuxAppSharedPreferences.java
class SettingsProvider extends ChangeNotifier {
  // Implementation
}
```

#### Method Documentation
```dart
/// 创建新会话
/// 
/// [title] 可选的会话标题，默认为 'Terminal {index}'
Future<TerminalSession> createSession({String? title}) async {
  // Implementation
}
```

### Provider State Management

#### Provider Initialization
```dart
// In main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
    ChangeNotifierProvider(create: (_) => TerminalProvider()),
  ],
  child: Consumer<SettingsProvider>(
    builder: (context, settings, child) {
      return MaterialApp(
        home: settings.initialized
            ? const TerminalScreen()
            : const LoadingScreen(),
      );
    },
  ),
);
```

#### Provider Usage Patterns
```dart
// Watching for rebuilds
Widget build(BuildContext context) {
  final settings = context.watch<SettingsProvider>();
  return Text('Theme: ${settings.colorTheme}');
}

// Reading without rebuilding
void someMethod() {
  final settings = context.read<SettingsProvider>();
  settings.setFontSize(16.0);
}
```

### Terminal-Specific Patterns

#### Terminal Session Management
```dart
class TerminalProvider extends ChangeNotifier {
  final List<TerminalSession> _sessions = [];
  int _currentIndex = -1;

  // Provide immutable access
  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  TerminalSession? get currentSession {
    if (_currentIndex >= 0 && _currentIndex < _sessions.length) {
      return _sessions[_currentIndex];
    }
    return null;
  }

  // Always notify listeners after state changes
  Future<TerminalSession> createSession() async {
    // ... create session
    notifyListeners();
    return session;
  }
}
```

#### Theme Integration
```dart
// In settings provider
TerminalTheme get terminalTheme => AppTerminalThemes.getTheme(_colorTheme);

TerminalCursorType get terminalCursorType {
  switch (_cursorStyle) {
    case CursorStyles.underline:
      return TerminalCursorType.underline;
    case CursorStyles.bar:
      return TerminalCursorType.verticalBar;
    case CursorStyles.block:
    default:
      return TerminalCursorType.block;
  }
}
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── providers/             # State management
│   ├── settings_provider.dart
│   └── terminal_provider.dart
├── screens/               # Full-page widgets
│   ├── terminal_screen.dart
│   └── settings_screen.dart
├── widgets/               # Reusable UI components
│   ├── extra_keys.dart
│   └── session_drawer.dart
├── models/                # Data models
│   └── terminal_session.dart
├── shell/                 # Shell integration
│   └── shell_session.dart
├── themes/                # Terminal color themes
│   └── terminal_themes.dart
└── utils/                 # Constants and utilities
    └── constants.dart
```

## Linting & Analysis

### Analysis Configuration
- Uses `package:flutter_lints/flutter.yaml` as base
- Standard Flutter lints enabled
- No custom lint rules configured
- Run `flutter analyze` to check code quality

### Common Lint Rules
- **avoid_print**: Disabled (useful for debugging)
- **prefer_single_quotes**: Can be enabled in analysis_options.yaml
- **use_super_parameters**: Recommended
- **use_colored_box**: Recommended

## Testing Guidelines

### Current Test Structure
- One existing widget test: `test/widget_test.dart`
- Uses Flutter's test framework
- Tests should follow widget testing patterns

### Writing Tests
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../lib/main.dart';
import '../lib/providers/settings_provider.dart';
import '../lib/providers/terminal_provider.dart';

void main() {
  group('DeepThoughtApp', () {
    testWidgets('should show loading screen when settings not initialized', (WidgetTester tester) async {
      // Test implementation
    });
  });
}
```

## Platform-Specific Considerations

### Android
- Uses `wakelock_plus` for keeping screen on
- Terminal input handling via `SystemChannels.textInput`
- Build with `flutter build apk`

### Linux
- Direct terminal integration
- Build with `flutter build linux`
- Runs on desktop environments

### Multi-platform
- Uses Material Design 3 (`useMaterial3: true`)
- Responsive design patterns
- Platform-agnostic terminal emulation via xterm

## Common Patterns & Best Practices

### Memory Management
```dart
class _TerminalScreenState extends State<TerminalScreen> {
  final FocusNode _terminalFocusNode = FocusNode();

  @override
  void dispose() {
    _terminalFocusNode.dispose();
    super.dispose();
  }
}
```

### Async Operations
```dart
Future<void> someAsyncMethod() async {
  try {
    // Async operation
  } catch (e) {
    // Error handling
  }
}
```

### Provider Notification
```dart
void updateValue(String newValue) {
  _value = newValue;
  notifyListeners();  // Always call after state changes
}
```

### Widget Performance
```dart
// Use const constructors when possible
const SizedBox(height: 16),

// Cache expensive computations
Widget get expensiveWidget {
  return _cachedWidget ??= ExpensiveWidget();
}
```

## Development Workflow

1. **Get dependencies**: `flutter pub get`
2. **Check analysis**: `flutter analyze`
3. **Run tests**: `flutter test`
4. **Format code**: `flutter format .`
5. **Build and test**: `flutter run -d <platform>`

## Important Files to Know

- `pubspec.yaml`: Dependencies and project metadata
- `analysis_options.yaml`: Linting configuration
- `lib/main.dart`: Application entry point
- `lib/providers/settings_provider.dart`: Settings state management
- `lib/providers/terminal_provider.dart`: Terminal session management
- `lib/utils/constants.dart`: Application constants
- `lib/themes/terminal_themes.dart`: Terminal color themes

## Troubleshooting

### Common Issues
- **Build failures**: Run `flutter clean && flutter pub get`
- **Analysis errors**: Check `flutter analyze` output
- **Import errors**: Verify relative import paths
- **Provider issues**: Ensure proper initialization

### Getting Help
- Run `flutter doctor` for environment issues
- Use `flutter analyze` for code quality
- Check `dart fix` for auto-fixable issues
