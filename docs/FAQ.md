# Frequently Asked Questions

## General

### What is Deep Thought?

Deep Thought is a terminal emulator for Android that provides a full Linux command-line environment. It uses Termux's bootstrap packages to offer bash, package management via apt, and thousands of available packages.

### Why is it called "Deep Thought"?

Named after the supercomputer in Douglas Adams' *The Hitchhiker's Guide to the Galaxy*, Deep Thought aims to be your thoughtful companion for computing tasks on mobile devices.

### Is Deep Thought the same as Termux?

No. Deep Thought is an independent project inspired by Termux. While it uses Termux's bootstrap packages for the Linux environment, it has its own terminal emulator implementation built with Flutter.

Key differences:
- Built with Flutter (cross-platform potential)
- Different UI/UX design
- Custom terminal implementation
- Different app architecture

### Is Deep Thought open source?

Yes! Deep Thought is open source software licensed under the MIT License.

## Installation

### What Android version do I need?

Android 7.0 (API level 24) or higher.

### What device architectures are supported?

- ARM64 (aarch64) - Most modern Android devices
- x86_64 - Some tablets and emulators

ARM32 (armeabi-v7a) is not currently supported.

### Why does the first launch take so long?

On first launch, Deep Thought extracts and sets up the complete Linux environment including bash, coreutils, apt, and other essential tools. This typically takes 30 seconds to 2 minutes depending on your device speed.

### Why does the app need storage permission?

Storage permission allows Deep Thought to:
- Access files on your device from the terminal
- Save data to accessible locations

The core terminal functionality works without storage permission, but file access is limited.

## Usage

### How do I copy text from the terminal?

1. Long press on the terminal to start selection
2. Drag the selection handles to select text
3. Tap "Copy" in the floating toolbar

### How do I paste text?

Open the menu (three dots in toolbar) and tap "Paste".

### How do I type Ctrl+C?

Three options:
1. Use the extra keys row: tap CTRL, then C
2. Use volume keys: hold Volume Up + tap C
3. Hardware keyboard: Ctrl+C directly

### How do I use Tab completion?

Press the TAB key in the extra keys row. Tab completion works for:
- Command names
- File and directory names
- Package names (with apt)

### Can I use multiple terminal sessions?

Yes! Swipe from the left edge (or tap the menu icon) to open the session drawer. Tap "New Session" to create additional sessions.

### How do I change the font size?

Two ways:
1. Pinch-to-zoom on the terminal
2. Settings > Appearance > Font Size

### Why are some characters displayed incorrectly?

This usually happens with special characters, CJK text, or emoji. Deep Thought includes a custom wcwidth implementation for proper character width calculation. If you still see issues:
- Try a different Nerd Font
- Report the issue with specific characters that fail

## Packages

### How do I install packages?

Use apt, the package manager:

```bash
apt update        # Update package lists
apt install vim   # Install a package
```

### What packages are available?

Thousands of packages from Termux repositories including:
- Editors (vim, nano, emacs)
- Development tools (git, python, nodejs, gcc)
- Network tools (curl, wget, openssh, nmap)
- Utilities (tmux, htop, zip, tar)

Search for packages: `apt search <keyword>`

### Why does apt update fail?

Common causes:
1. No internet connection
2. DNS issues - try `ping 8.8.8.8` to test
3. Repository temporarily unavailable

### Can I add custom repositories?

Yes, but be careful with repository compatibility. Edit sources at `$PREFIX/etc/apt/sources.list`.

## SSH

### How do I connect to an SSH server?

1. Go to Settings > SSH Manager
2. Add your server details
3. Create New Session > Select your server

### Does Deep Thought support SSH keys?

Yes. Generate keys with `ssh-keygen` and configure your server's authorized_keys file.

### How do I transfer files via SSH?

Use `scp` or `sftp`:

```bash
# Copy file to server
scp file.txt user@host:/path/

# Copy file from server
scp user@host:/path/file.txt ./

# Interactive SFTP
sftp user@host
```

## Troubleshooting

### The terminal is blank or shows errors

Try these steps:
1. Close and reopen the app
2. Clear app data and restart (will re-extract bootstrap)
3. Check if bash exists: restart should show error if missing

### Commands are not found

The PATH might not be set correctly. Try:
```bash
export PATH="$PREFIX/bin:$PATH"
```

If this fixes it, add the line to your `~/.bashrc`.

### The app crashes on launch

1. Ensure your device meets requirements (Android 7.0+, ARM64/x86_64)
2. Try clearing app data
3. Report the issue with device details

### Keyboard doesn't appear

1. Tap directly on the terminal area
2. Check Android keyboard settings
3. Try a different keyboard app

### Screen flickers or has display issues

1. Try disabling any battery saver/optimization for the app
2. Update your device's system WebView
3. Try a different theme

## Advanced

### Can I use zsh instead of bash?

Yes! Install zsh and set it as your shell:

```bash
apt install zsh
chsh -s zsh
```

Note: You may need to restart the app for changes to take effect.

### Can I run graphical applications?

Deep Thought is a terminal emulator without graphical display support. For graphical applications, you would need X11 or VNC setup, which is complex on Android.

### Is root access supported?

Deep Thought itself doesn't require or provide root access. If your device is rooted, you can use `su` from the terminal (assuming proper root management app is installed).

### Can I use Deep Thought for development?

Yes! Install your preferred development tools:

```bash
# Python
apt install python

# Node.js
apt install nodejs

# Git
apt install git

# Compilers
apt install clang make
```

### Where is data stored?

App data is stored in the Android app data directory, typically:
`/data/data/com.example.deep_thought/`

The home directory (`~`) points to a subdirectory within this location.

## Getting Help

### Where do I report bugs?

Open an issue on our [GitHub Issues](https://github.com/user/deep-thought/issues) page with:
- Device model and Android version
- Steps to reproduce the issue
- Error messages if any
- Screenshots if applicable

### Where can I ask questions?

- [GitHub Discussions](https://github.com/user/deep-thought/discussions)
- Open a GitHub issue for technical questions

### How can I contribute?

See our [Development Guide](Development.md) for contribution guidelines. We welcome:
- Bug reports and fixes
- Feature suggestions and implementations
- Documentation improvements
- Translations
