# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

```bash
# Get dependencies
flutter pub get

# Run on Linux desktop
flutter run -d linux

# Run on Android
flutter run -d android

# Build release
flutter build linux
flutter build apk

# Analyze code
flutter analyze

# Run tests
flutter test
```

## Architecture Overview

This is a Flutter terminal emulator inspired by Termux. The architecture follows a Provider-based state management pattern.

### State Management

Two main providers manage application state:

- **SettingsProvider** (`lib/providers/settings_provider.dart`): Manages all user preferences with SharedPreferences persistence. Must call `init()` before use - the app shows a loading screen until `initialized` is true.

- **TerminalProvider** (`lib/providers/terminal_provider.dart`): Manages multiple terminal sessions. Call `init()` to create the first session. Each session wraps an xterm `Terminal` and `TerminalController`.

### Key Dependencies

- **xterm ^4.0.0**: Terminal emulation. Note: xterm exports its own `TerminalTheme` class, so our themes are named `AppTerminalThemes` to avoid conflicts.
- **google_fonts**: Dynamic font loading for terminal display.
- **provider**: State management.
- **shared_preferences**: Settings persistence.
- **wakelock_plus**: Keep screen on functionality.

### Module Structure

```
lib/
├── main.dart              # App entry, MultiProvider setup
├── providers/             # State management (ChangeNotifier classes)
├── screens/               # Full-page widgets
├── widgets/               # Reusable UI components
├── themes/                # Terminal color themes (AppTerminalThemes)
├── models/                # Data models (TerminalSession)
└── utils/                 # Constants and defaults (DefaultSettings)
```

### Terminal Session Lifecycle

1. `TerminalProvider.createSession()` creates a new `TerminalSession`
2. Each session contains its own `Terminal` (xterm) and `TerminalController`
3. `TerminalScreen` renders the current session's terminal using `TerminalView`
4. Sessions are managed via the drawer (`SessionDrawer`)

### Settings Flow

Settings changes follow this pattern:
1. UI calls `SettingsProvider.setXxx(value)`
2. Provider updates internal state and persists to SharedPreferences
3. Provider calls `notifyListeners()`
4. Consumers rebuild with new values

Default values are defined in `lib/utils/constants.dart` under `DefaultSettings`.
