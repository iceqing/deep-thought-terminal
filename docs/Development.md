# Development Guide

## Prerequisites

### Required Tools

- **Flutter SDK** 3.0.0 or higher
- **Dart SDK** (included with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Android SDK** with NDK for Android builds
- **Git** for version control

### Linux Desktop Development

For Linux builds, install GTK development libraries:

```bash
# Ubuntu/Debian
sudo apt install libgtk-3-dev

# Fedora
sudo dnf install gtk3-devel

# Arch Linux
sudo pacman -S gtk3
```

## Getting Started

### Clone Repository

```bash
git clone https://github.com/user/deep-thought.git
cd deep-thought
```

### Install Dependencies

```bash
flutter pub get
```

### Verify Setup

```bash
flutter doctor
```

Ensure all required components are available.

## Running the App

### Android Device/Emulator

```bash
# List available devices
flutter devices

# Run on Android
flutter run -d android

# Run on specific device
flutter run -d <device-id>
```

### Linux Desktop

```bash
flutter run -d linux
```

### Hot Reload

While running, press `r` for hot reload or `R` for hot restart.

## Building

### Debug Build

```bash
# Android APK
flutter build apk --debug

# Linux
flutter build linux --debug
```

### Release Build

```bash
# Android APK
flutter build apk --release

# Split APKs by ABI
flutter build apk --split-per-abi --release

# Linux
flutter build linux --release
```

### Build Output

- Android: `build/app/outputs/flutter-apk/`
- Linux: `build/linux/x64/release/bundle/`

## Code Quality

### Static Analysis

```bash
flutter analyze
```

Fix all warnings and errors before committing.

### Formatting

```bash
dart format lib/
```

### Linting

The project uses `flutter_lints` for code analysis. Rules are defined in `analysis_options.yaml`.

## Testing

### Run Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/widget_test.dart

# With coverage
flutter test --coverage
```

### Writing Tests

Place tests in the `test/` directory:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:deep_thought/main.dart';

void main() {
  testWidgets('App starts correctly', (tester) async {
    await tester.pumpWidget(const MyApp());
    // Add assertions
  });
}
```

## Project Guidelines

### Code Style

Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style):

- Use `lowerCamelCase` for variables and functions
- Use `UpperCamelCase` for classes and types
- Use `lowercase_with_underscores` for file names
- Keep lines under 80 characters when practical

### File Organization

```
lib/
├── feature_name/
│   ├── feature_name.dart      # Public API (exports)
│   ├── feature_widget.dart    # UI components
│   └── feature_provider.dart  # State management
```

### Naming Conventions

- Providers: `XxxProvider`
- Screens: `XxxScreen`
- Widgets: Descriptive name (`ExtraKeysRow`, `SessionDrawer`)
- Models: `XxxModel` or just `Xxx` for simple data classes

### Documentation

Document public APIs:

```dart
/// Creates a new terminal session.
///
/// [type] specifies whether this is a local or SSH session.
/// [name] is the display name for the session.
///
/// Returns the created [TerminalSession].
Future<TerminalSession> createSession({
  required SessionType type,
  String? name,
}) async {
  // Implementation
}
```

## Contributing

### Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Make** your changes
4. **Test** your changes
5. **Commit** with clear messages
6. **Push** to your fork
7. **Submit** a pull request

### Commit Messages

Use clear, descriptive commit messages:

```
Add SSH key authentication support

- Add private key field to SSH host model
- Implement key-based authentication in SSH provider
- Update SSH manager UI for key selection
```

### Pull Request Guidelines

- Describe what changes were made and why
- Reference related issues
- Include screenshots for UI changes
- Ensure all tests pass
- Ensure code analysis passes

## Common Development Tasks

### Adding a New Setting

1. Add field to `SettingsProvider`:

```dart
bool _newSetting = false;
bool get newSetting => _newSetting;

Future<void> setNewSetting(bool value) async {
  _newSetting = value;
  await _prefs?.setBool('newSetting', value);
  notifyListeners();
}
```

2. Initialize in `init()`:

```dart
_newSetting = _prefs?.getBool('newSetting') ?? false;
```

3. Add UI in `SettingsScreen`:

```dart
SwitchListTile(
  title: Text('New Setting'),
  value: settings.newSetting,
  onChanged: settings.setNewSetting,
)
```

### Adding a New Theme

1. Add to `lib/themes/terminal_themes.dart`:

```dart
static TerminalTheme get myTheme => TerminalTheme(
  cursor: Color(0xFFFFFFFF),
  selection: Color(0x40FFFFFF),
  foreground: Color(0xFFE0E0E0),
  background: Color(0xFF1A1A1A),
  black: Color(0xFF000000),
  // ... other colors
);
```

2. Add to theme map and UI options.

### Adding Localization

1. Add strings to `lib/l10n/app_en.arb`:

```json
{
  "newFeature": "New Feature",
  "@newFeature": {
    "description": "Label for the new feature"
  }
}
```

2. Add to other language files (e.g., `app_zh.arb`)

3. Run localization generation:

```bash
flutter gen-l10n
```

4. Use in code:

```dart
Text(AppLocalizations.of(context)!.newFeature)
```

## Debugging

### Debug Output

Use `debugPrint` for development logging:

```dart
debugPrint('Session started: ${session.id}');
```

### Flutter DevTools

Launch DevTools for inspection:

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

### Common Issues

**PTY not starting:**
- Check flutter_pty native library is built
- Verify bash path is correct
- Check environment variables

**Terminal display issues:**
- Verify wcwidth implementation
- Check font metrics
- Test with different terminal content

**State not updating:**
- Ensure `notifyListeners()` is called
- Check widget is consuming the provider
- Verify provider is in widget tree

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [xterm.dart Package](https://pub.dev/packages/xterm)
- [flutter_pty Package](https://pub.dev/packages/flutter_pty)
- [Provider Package](https://pub.dev/packages/provider)
