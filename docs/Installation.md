# Installation Guide

## System Requirements

### Android
- **Android Version**: 7.0 (API 24) or higher
- **Architecture**: ARM64 (aarch64) or x86_64
- **Storage**: At least 500MB free space for bootstrap and packages
- **Permissions**: Storage permission for accessing files

### Linux Desktop (Development)
- **OS**: Linux with GTK 3.0
- **Flutter**: SDK 3.0.0 or higher

## Installation Methods

### Method 1: Download APK (Recommended)

1. Go to the [Releases](https://github.com/user/deep-thought/releases) page
2. Download the latest APK file for your architecture:
   - `deep-thought-arm64-v8a-release.apk` for most modern devices
   - `deep-thought-x86_64-release.apk` for x86 devices/emulators
3. Install the APK on your device
   - You may need to enable "Install from unknown sources" in settings

### Method 2: Build from Source

See the [Development Guide](Development.md) for build instructions.

## First Launch Setup

When you launch Deep Thought for the first time:

1. **Bootstrap Extraction**
   - The app will extract the Termux bootstrap environment
   - This includes bash, coreutils, apt, and other essential tools
   - Progress is shown on screen

2. **Environment Setup**
   - Linux filesystem hierarchy is created
   - Shell configuration files are initialized
   - Package manager is configured

3. **Ready to Use**
   - Once setup completes, a terminal prompt appears
   - You can start running commands immediately

The initial setup typically takes 30 seconds to 2 minutes depending on your device speed.

## Post-Installation

### Update Package Lists

```bash
apt update
```

### Install Additional Packages

```bash
# Install common tools
apt install vim git curl wget

# Install development tools
apt install python nodejs

# Search for packages
apt search <keyword>
```

### Configure Your Shell

Edit `~/.bashrc` to customize your shell:

```bash
# Example customizations
export PS1='\u@\h:\w\$ '
alias ll='ls -la'
alias la='ls -A'
```

## Troubleshooting

### Bootstrap Extraction Fails

1. Ensure you have sufficient storage space
2. Check that storage permissions are granted
3. Try restarting the app

### Shell Doesn't Start

1. Check if bootstrap extraction completed successfully
2. Verify bash exists: the app should show an error if bash is missing
3. Try reinstalling the app

### Packages Won't Install

1. Run `apt update` first
2. Check internet connectivity
3. Verify package name with `apt search`

## Uninstallation

To completely remove Deep Thought:

1. Uninstall the app through Android settings
2. Delete the data directory if needed:
   - Usually at `/data/data/com.example.deep_thought/`

Note: Uninstalling removes all installed packages and configurations.
