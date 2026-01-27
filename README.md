# Deep Thought

[中文文档](README_zh.md)

<p align="center">
  <img src="assets/icon/app_icon_pure.svg" alt="Deep Thought Logo" width="128" height="128">
</p>

<p align="center">
  <strong>A powerful terminal emulator for Android, inspired by Termux</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#installation">Installation</a> •
  <a href="#building">Building</a> •
  <a href="#usage">Usage</a> •
  <a href="#contributing">Contributing</a>
</p>

---

## Overview

Deep Thought is a feature-rich terminal emulator built with Flutter, designed to bring the full Linux command-line experience to Android devices. It uses Termux's bootstrap packages to provide a complete Linux environment with package management, development tools, and more.

**Why "Deep Thought"?** Named after the supercomputer in *The Hitchhiker's Guide to the Galaxy*, this terminal aims to be your thoughtful companion for computing tasks on mobile devices.

## Features

### Core Terminal Features
- **Full Linux Environment** - Powered by Termux bootstrap packages (bash, coreutils, apt, etc.)
- **Multiple Sessions** - Create and manage multiple terminal sessions simultaneously
- **Font Support** - Built-in Mutipul Fonts 

### User Experience
- **Pinch-to-Zoom** - Adjust font size with intuitive two-finger gestures
- **Extra Keys Row** - Quick access to Ctrl, Alt, Tab, Esc, and arrow keys
- **Volume Key Modifiers** - Use volume keys as Ctrl (up) and Alt (down)
- **Custom Themes** - Multiple terminal color themes (Monokai, Dracula, Nord, Solarized, etc.)
- **Keep Screen On** - Prevent screen timeout during long-running tasks

### Advanced Features
- **SSH Manager** - Save and quickly connect to SSH hosts
- **Task/Script Shortcuts** - Define custom commands for quick execution
- **Command History** - Searchable history with persistent storage
- **Text Selection** - Long-press to select, with copy support
- **Internationalization** - English and Chinese language support

### Technical Highlights
- **Custom wcwidth Implementation** - Termux-compatible character width calculation for proper CJK and emoji display
- **Proper Resize Handling** - Correct SIGWINCH signal propagation for vim, htop, etc.
- **Alt Buffer Support** - Proper handling of full-screen applications

## Screenshots

*Coming soon*

## Installation

### Requirements
- Android 7.0 (API 24) or higher
- ARM64 (aarch64) or x86_64 architecture

### Download
Download the latest APK from the [Releases](https://github.com/user/deep-thought/releases) page.

### First Launch
On first launch, Deep Thought will automatically:
1. Extract the Termux bootstrap environment
2. Set up the Linux filesystem
3. Configure bash and basic utilities

This process takes about 30 seconds to 2 minutes depending on your device.

## Building

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Android SDK with NDK
- For Linux builds: GTK 3.0 development libraries

### Build Steps

```bash
# Clone the repository
git clone https://github.com/user/deep-thought.git
cd deep-thought

# Get dependencies
flutter pub get

# Build for Android
flutter build apk --release

# Build for Linux (desktop)
flutter build linux --release

# Run in development mode
flutter run -d android
```

### Project Structure

```
lib/
├── main.dart              # App entry point
├── bootstrap/             # Termux bootstrap extraction
├── core/                  # Custom terminal & wcwidth implementation
├── l10n/                  # Internationalization
├── models/                # Data models
├── providers/             # State management (Provider pattern)
├── screens/               # Main screens (Terminal, Settings, SSH)
├── services/              # Platform services (volume keys, etc.)
├── shell/                 # Shell session management
├── themes/                # Terminal color themes
├── utils/                 # Constants and utilities
└── widgets/               # Reusable UI components
```

## Usage

### Basic Operations

| Action | Gesture/Key |
|--------|-------------|
| Open keyboard | Tap on terminal |
| Hide keyboard | Tap keyboard icon in toolbar |
| Select text | Long press and drag |
| Copy selection | Tap "Copy" in selection toolbar |
| Paste | Menu → Paste |
| Zoom in/out | Pinch with two fingers |
| Ctrl+C | Volume Up + C (or Extra Keys → Ctrl + C) |
| Alt+key | Volume Down + key |

### Session Management

- **New Session**: Menu → New Session (choose Local or SSH)
- **Switch Sessions**: Swipe from left edge or tap menu icon
- **Close Session**: Swipe session item in drawer or type `exit`
- **Rename Session**: Tap session title in toolbar

### Package Management

Deep Thought uses apt for package management:

```bash
# Update package lists
apt update

# Install packages
apt install vim git python

# Search packages
apt search <keyword>

# Upgrade all packages
apt upgrade
```

### SSH Connections

1. Go to **Menu → Settings → SSH Manager**
2. Add a new host with connection details
3. Quick connect from **Menu → New Session → [Your SSH Host]**

## Configuration

### Settings

Access settings via **Menu → Settings**:

- **Appearance**: Theme, font size, font family
- **Behavior**: Keep screen on, vibration feedback
- **Extra Keys**: Show/hide extra keys row
- **Advanced**: Debug info display

### Custom Fonts

The app includes several Nerd Font Mono variants:
- JetBrains Mono
- Fira Code
- Hack
- Source Code Pro
- Ubuntu Mono
- Cascadia Code

### Shell Configuration

User shell configuration files:
- `~/.bashrc` - Bash configuration
- `~/.profile` - Login profile
- `~/.bash_history` - Command history

## Known Issues

- Some packages may require additional configuration for Deep Thought's environment
- Hardware keyboard support is limited on some devices

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `flutter analyze` to check for issues
5. Submit a pull request

### Code Style

This project follows the [Dart style guide](https://dart.dev/guides/language/effective-dart/style) and uses `flutter_lints` for code analysis.

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3) - see the [LICENSE](LICENSE) file for details.

## Bootstrap & Licensing

This application uses the **Termux bootstrap packages** to provide the underlying Linux environment.

*   **Deep Thought App**: The application code (Flutter/Dart) is licensed under **GPLv3**, sharing the same license as the upstream Termux application to ensure full compatibility and freedom.
*   **Termux Packages**: The binary bootstrap environment downloaded/extracted by this app is derived from the [Termux](https://termux.dev/) project and its package ecosystem, which are governed by their respective open-source licenses (primarily GPLv3).

## Acknowledgments

- [Termux](https://termux.dev/) - For the bootstrap packages, directory structure standards, and inspiration.
- [xterm.dart](https://pub.dev/packages/xterm) - Terminal emulation library.
- [flutter_pty](https://pub.dev/packages/flutter_pty) - PTY support for Flutter.
- [Nerd Fonts](https://www.nerdfonts.com/) - Patched fonts with icons.

## Support

- **Issues**: [GitHub Issues](https://github.com/user/deep-thought/issues)
- **Discussions**: [GitHub Discussions](https://github.com/user/deep-thought/discussions)

---

<p align="center">
  Made with ❤️ using Flutter
</p>