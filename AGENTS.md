# AGENTS.md - Development Guidelines for Agentic Coding

This file provides guidelines for agentic coding agents working on the Deep Thought Flutter terminal emulator project.

## Project Overview

**Deep Thought** is a Flutter terminal emulator inspired by Termux. The project follows a Provider-based state management pattern with clean architecture separation.

### Architecture
- **State Management**: Provider pattern with `SettingsProvider` and `TerminalProvider`
- **Terminal Engine**: xterm ^4.0.0 for terminal emulation
- **UI Framework**: Flutter with Material Design 3
- **Platforms**: Linux, Android, macOS, Windows (Flutter multi-platform)

### Key Dependencies
- **xterm ^4.0.0**: Terminal emulation. Note: xterm exports its own `TerminalTheme` class, so our themes are named `AppTerminalThemes` to avoid conflicts.
- **google_fonts**: Dynamic font loading for terminal display.
- **provider**: State management.
- **shared_preferences**: Settings persistence.
- **wakelock_plus**: Keep screen on functionality.

## Project Context

This project involves a custom Termux fork (com.dpterm) and a Flutter-based terminal emulator. Key paths use the dpterm package name, NOT standard Termux paths. Never assume standard Termux paths like com.termux — always check existing code for the correct package name and path patterns.

For Linux desktop adaptations, use native system paths (e.g., /usr, /home, ~/.config) rather than Android-style or app-specific sandbox paths unless explicitly told otherwise.

## Code Change Principles

When making changes, prefer minimal, targeted edits. Do NOT make large refactors or rename things unless explicitly asked. If a fix requires touching many files, explain the plan first and get approval before proceeding.

## Build & Development Commands

```bash
# Get dependencies
flutter pub get

# Run on Linux desktop / Android
flutter run -d linux
flutter run -d android

# Build releases
flutter build linux
flutter build apk
flutter build appbundle

# Code analysis and formatting
flutter analyze
flutter format .
dart fix --apply

# Run tests
flutter test
```

## Build & Compilation

When building or compiling (Docker builds, bootstrap, NDK), always verify proxy/network configuration, dependency names (e.g., bzip2 vs libbz2), and build cache state BEFORE attempting the build. List assumptions and ask for confirmation if unsure.

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

## Project-Specific Patterns

### Terminal Session Management
- `TerminalProvider` 通过 `List<TerminalSession>` + `_currentIndex` 管理多会话
- 对外暴露不可变列表 `List.unmodifiable()`，`currentSession` 为 nullable getter
- 会话状态变更（创建/切换/关闭）后必须调用 `notifyListeners()`

### Settings Flow
1. UI 调用 `SettingsProvider.setXxx(value)`
2. Provider 更新内部状态并持久化到 SharedPreferences
3. Provider 调用 `notifyListeners()`
4. Consumer 使用新值重建

默认值定义在 `lib/utils/constants.dart` 的 `DefaultSettings` 中。

### Platform Notes
- Android 端通过 `SystemChannels.textInput` 处理终端输入
- `SettingsProvider` 必须先调用 `init()`，app 在 `initialized` 为 true 前显示 loading 界面

## ADB On-Device Debugging

When the user's Android device is connected via USB with developer mode enabled, use `adb` to directly execute commands on the device instead of asking the user to type them manually.

### Basic Patterns

```bash
# Check device connection
adb devices

# Run command as the app user (access app's private data)
adb shell "run-as com.dpterm <command>"

# Run with Termux environment (for Termux binaries like id, grep, proot-distro)
adb shell "run-as com.dpterm /data/data/com.dpterm/files/usr/bin/bash -c '
  export LD_LIBRARY_PATH=/data/data/com.dpterm/files/usr/lib
  export PATH=/data/data/com.dpterm/files/usr/bin:/system/bin
  export HOME=/data/data/com.dpterm/files/home
  export PREFIX=/data/data/com.dpterm/files/usr
  export TMPDIR=/data/data/com.dpterm/files/usr/tmp
  export TERM=xterm-256color
  <your command here>
'"
```

### Key Notes

- **`run-as com.dpterm`** — required to access `/data/data/com.dpterm/` (app sandbox). Without it, Permission denied.
- **`/system/bin/sh` vs Termux bash** — `/system/bin/sh` is Android's minimal shell, does NOT support `<(...)` process substitution. Use Termux's bash (`/data/data/com.dpterm/files/usr/bin/bash`) for advanced shell features.
- **`/system/bin/sh` heredoc limitation** — `cat << EOF` may fail with "can't create temporary file" because `TMPDIR` is not set. Always use Termux bash or set `TMPDIR` first.
- **Environment variables** — `run-as` starts with a minimal environment. Always export `LD_LIBRARY_PATH`, `PATH`, `PREFIX`, `TMPDIR` when running Termux binaries.
- **Process GIDs** — `run-as` has different supplementary GIDs than the actual app process. Use `cat /proc/$(pidof com.dpterm)/status | grep Groups` to see the app's real GIDs.
- **Timeouts** — long-running commands (e.g., `proot-distro install`) may need extended timeouts (up to 600000ms).
- **Reading files** — `adb shell "run-as com.dpterm cat <path>"` to read files inside the app sandbox.
- **Writing files** — use Termux bash with `cat >` or `sed -i` instead of `/system/bin/sh` heredoc.

## Error Handling

When a tool or approach fails (e.g., file too large, API error), do NOT repeat the same failing approach. Immediately propose 2-3 alternative strategies and let the user choose.
