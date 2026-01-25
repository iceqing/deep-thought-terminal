# Architecture Overview

## Technology Stack

- **Framework**: Flutter 3.0+
- **Language**: Dart
- **Terminal Emulation**: xterm.dart
- **PTY Support**: flutter_pty
- **State Management**: Provider
- **Persistence**: SharedPreferences

## Project Structure

```
deep-thought/
├── lib/
│   ├── main.dart              # App entry point
│   ├── bootstrap/             # Bootstrap extraction
│   ├── core/                  # Custom terminal implementation
│   ├── l10n/                  # Internationalization
│   ├── models/                # Data models
│   ├── providers/             # State management
│   ├── screens/               # Main screens
│   ├── services/              # Platform services
│   ├── shell/                 # Shell session management
│   ├── themes/                # Terminal themes
│   ├── utils/                 # Utilities and constants
│   └── widgets/               # Reusable widgets
├── assets/
│   ├── bootstrap-aarch64.zip  # ARM64 bootstrap
│   ├── bootstrap-x86_64.zip   # x86_64 bootstrap
│   ├── fonts/                 # Nerd Font files
│   └── icon/                  # App icons
└── android/                   # Android platform code
```

## Core Components

### 1. Bootstrap System (`lib/bootstrap/`)

Handles extraction and setup of the Termux bootstrap environment.

**Key Files:**
- `termux_bootstrap.dart` - Bootstrap extraction and environment setup

**Responsibilities:**
- Extract bootstrap archive on first launch
- Create Linux filesystem hierarchy
- Set up environment variables
- Configure package manager paths

**Bootstrap Contents:**
- bash shell
- coreutils (ls, cp, mv, etc.)
- apt package manager
- Basic utilities

### 2. Terminal Core (`lib/core/`)

Custom terminal implementation extending xterm.dart with Termux compatibility.

**Key Components:**
- `terminal.dart` - Extended Terminal class (TermuxTerminal)
- `terminal_controller.dart` - Selection and interaction handling
- `wcwidth.dart` - Termux-compatible character width calculation
- `buffer/` - Terminal buffer management with cell anchors

**wcwidth Implementation:**

Critical for proper display of:
- CJK characters (Chinese, Japanese, Korean)
- Emoji
- Special symbols
- Nerd Font glyphs

The custom wcwidth follows Termux's implementation for consistency.

### 3. Shell Session (`lib/shell/`)

Manages PTY (pseudo-terminal) sessions.

**Key Files:**
- `shell_session.dart` - Shell session abstraction and factory

**Session Types:**
- `PtyShellSession` - Local shell using flutter_pty
- SSH sessions (via SSH provider)

**Session Lifecycle:**
1. Create session with configuration
2. Start PTY with environment
3. Handle I/O streams
4. Process resize events
5. Clean up on exit

### 4. State Management (`lib/providers/`)

Provider-based state management pattern.

**Providers:**

| Provider | Purpose |
|----------|---------|
| `SettingsProvider` | User preferences and app settings |
| `TerminalProvider` | Terminal sessions management |
| `SSHProvider` | SSH host configurations |
| `TaskProvider` | Command shortcuts |

**SettingsProvider:**
- Persists settings via SharedPreferences
- Notifies listeners on changes
- Provides default values

**TerminalProvider:**
- Manages multiple sessions
- Tracks current active session
- Handles session creation/destruction

### 5. Screens (`lib/screens/`)

Main application screens.

| Screen | Purpose |
|--------|---------|
| `BootstrapScreen` | First-launch bootstrap extraction |
| `TerminalScreen` | Main terminal interface |
| `SettingsScreen` | App configuration |
| `SSHManagerScreen` | SSH host management |

### 6. Widgets (`lib/widgets/`)

Reusable UI components.

**Key Widgets:**
- `scaled_terminal_view.dart` - Terminal view with zoom support
- `terminal_selection_handles.dart` - Text selection UI
- `extra_keys.dart` - Extra keys row
- `session_drawer.dart` - Session list drawer

### 7. Themes (`lib/themes/`)

Terminal color theme definitions.

**AppTerminalThemes:**
Named to avoid conflict with xterm's TerminalTheme class.

Themes define:
- Foreground/background colors
- ANSI color palette (16 colors)
- Cursor color
- Selection color

## Data Flow

### Settings Flow

```
User Action → SettingsProvider.setX() → SharedPreferences
                     ↓
              notifyListeners()
                     ↓
              Consumer<SettingsProvider> rebuilds
```

### Terminal I/O Flow

```
User Input → Terminal.write() → PTY.write()
                                    ↓
                              Process stdin
                                    ↓
                              Process stdout
                                    ↓
PTY Output Stream → Terminal.onOutput → Screen Update
```

### Session Creation Flow

```
User taps "New Session"
        ↓
TerminalProvider.createSession()
        ↓
ShellSessionFactory.createInteractiveSession()
        ↓
PtyShellSession.start()
        ↓
Session added to provider
        ↓
UI updates via notifyListeners()
```

## Key Technical Decisions

### 1. Custom wcwidth

Why: xterm.dart's default wcwidth doesn't match Termux's behavior, causing display issues with CJK text and emoji.

Solution: Implement Termux-compatible wcwidth for consistent character width calculation.

### 2. Shell Launch Wrapper

Why: Termux bash has hardcoded paths that don't match our app's data directory.

Solution: Launch bash through `/system/bin/sh` with proper environment variables set via wrapper command.

### 3. Provider Pattern

Why: Simple, effective state management for Flutter apps without excessive boilerplate.

Trade-offs: Good for medium complexity; might need revision for very complex state.

### 4. Cell Anchors

Why: Standard row/column offsets become invalid when buffer scrolls.

Solution: Use cell anchors that track position relative to buffer content, maintaining validity through scrolling.

## Platform Specifics

### Android

- Uses flutter_pty native library
- Requires storage permissions
- Bootstrap stored in app data directory
- Volume key interception for Ctrl/Alt

### Linux Desktop

- Direct shell execution
- No bootstrap needed (uses system shell)
- Development/testing platform

## Extension Points

### Adding New Themes

1. Add theme definition to `lib/themes/terminal_themes.dart`
2. Add theme name to settings options
3. Theme automatically available in settings

### Adding Languages

1. Add ARB file to `lib/l10n/`
2. Run Flutter localization generation
3. Language available in settings

### Adding SSH Features

1. Extend `SSHProvider` for new data
2. Update `SSHManagerScreen` UI
3. Modify session creation in `TerminalProvider`
