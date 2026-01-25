# User Guide

## Terminal Basics

### Opening the Keyboard

- **Tap** anywhere on the terminal to show the keyboard
- **Tap the keyboard icon** in the toolbar to hide it

### Text Input

Type commands using the on-screen keyboard. The terminal supports full UTF-8 input including:
- Latin characters
- CJK (Chinese, Japanese, Korean) characters
- Emoji
- Special symbols

### Extra Keys Row

The extra keys row provides quick access to special keys:

| Key | Function |
|-----|----------|
| ESC | Escape key |
| CTRL | Control modifier |
| ALT | Alt modifier |
| TAB | Tab key |
| - | Dash/minus |
| / | Forward slash |
| ~ | Tilde (home directory) |
| Arrow keys | Navigation |

Toggle the extra keys row in **Settings > Extra Keys**.

### Volume Key Shortcuts

Use hardware volume buttons as modifiers:

- **Volume Up + Key** = Ctrl + Key
- **Volume Down + Key** = Alt + Key

Examples:
- Volume Up + C = Ctrl+C (interrupt)
- Volume Up + D = Ctrl+D (EOF)
- Volume Up + Z = Ctrl+Z (suspend)

## Text Selection

### Select Text

1. **Long press** on the terminal to start selection
2. **Drag** the selection handles to adjust
3. Use the floating toolbar to **Copy**

### Paste Text

1. Open the menu (three dots)
2. Tap **Paste**

Or use keyboard shortcut: Ctrl+Shift+V (if supported)

## Session Management

### Create New Session

1. Open the drawer (swipe from left or tap menu icon)
2. Tap **New Session**
3. Choose session type:
   - **Local** - New bash shell
   - **SSH** - Connect to saved SSH host

### Switch Sessions

- **Swipe from left edge** to open drawer
- **Tap** on a session to switch to it

### Close Session

- **Swipe** session item in drawer to delete
- Or type `exit` in the terminal

### Rename Session

1. Tap the session title in the toolbar
2. Enter new name
3. Tap OK

## Zoom and Font Size

### Pinch to Zoom

Use two fingers to pinch in/out on the terminal to adjust font size.

### Settings

Set a specific font size in **Settings > Appearance > Font Size**.

## Package Management

Deep Thought uses apt for package management, compatible with Termux packages.

### Basic Commands

```bash
# Update package lists
apt update

# Upgrade all packages
apt upgrade

# Install a package
apt install <package>

# Remove a package
apt remove <package>

# Search for packages
apt search <keyword>

# Show package info
apt show <package>
```

### Popular Packages

```bash
# Editors
apt install vim nano

# Version control
apt install git

# Network tools
apt install curl wget openssh

# Programming languages
apt install python nodejs ruby

# File tools
apt install zip unzip tar
```

## SSH Connections

### Add SSH Host

1. Go to **Settings > SSH Manager**
2. Tap **Add Host**
3. Enter connection details:
   - Nickname (display name)
   - Host (IP or domain)
   - Port (default: 22)
   - Username
   - Authentication method

### Connect to SSH Host

1. Create **New Session**
2. Select your SSH host from the list
3. Enter password if prompted

### SSH Authentication

Supported methods:
- Password authentication
- Private key authentication

For key-based auth:
1. Generate key: `ssh-keygen`
2. Copy public key to server
3. Add host with private key path

## Shell Tips

### Command History

- **Up/Down arrows** - Navigate history
- **Ctrl+R** - Search history (reverse search)
- History is saved in `~/.bash_history`

### Tab Completion

Press **Tab** to auto-complete:
- Commands
- File names
- Directory names

### Useful Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+C | Interrupt current command |
| Ctrl+D | End of input / Exit shell |
| Ctrl+Z | Suspend current process |
| Ctrl+L | Clear screen |
| Ctrl+A | Move to beginning of line |
| Ctrl+E | Move to end of line |
| Ctrl+U | Delete line before cursor |
| Ctrl+K | Delete line after cursor |
| Ctrl+W | Delete word before cursor |

### Running Background Tasks

```bash
# Run command in background
command &

# List background jobs
jobs

# Bring job to foreground
fg %1

# Continue suspended job in background
bg %1
```

## Working with Files

### Navigate Filesystem

```bash
# Print current directory
pwd

# Change directory
cd /path/to/dir

# Go to home directory
cd ~

# List files
ls -la

# Show file tree (if installed)
tree
```

### File Operations

```bash
# Copy file
cp source dest

# Move/rename file
mv old new

# Delete file
rm file

# Create directory
mkdir dirname

# Delete directory
rm -r dirname
```

### View and Edit Files

```bash
# View file
cat file
less file

# Edit file (vim)
vim file

# Edit file (nano)
nano file
```
