# Configuration Guide

## App Settings

Access settings via the menu icon > **Settings**.

### Appearance

#### Theme

Choose from multiple terminal color themes:
- **Monokai** - Dark theme with vibrant colors
- **Dracula** - Popular dark theme
- **Nord** - Arctic-inspired dark theme
- **Solarized Dark** - Precision colors for machines and people
- **Solarized Light** - Light variant
- **One Dark** - Atom-inspired theme
- **Gruvbox Dark** - Retro groove colors
- **Material Dark** - Material Design inspired
- **Tomorrow Night** - Tomorrow theme family
- **Ayu Dark** - Modern, elegant theme

#### Font Family

Select from included Nerd Font Mono variants:
- **JetBrains Mono** - Developer-focused font by JetBrains
- **Fira Code** - Programming font with ligatures support
- **Hack** - Designed for source code
- **Source Code Pro** - Adobe's monospace font
- **Ubuntu Mono** - Ubuntu's terminal font
- **Cascadia Code** - Microsoft's new monospace font

All fonts include Nerd Font symbols for Powerline and icon support.

#### Font Size

Adjust terminal font size (8-32 points). Can also be changed via pinch-to-zoom.

### Behavior

#### Keep Screen On

Prevent screen from turning off while the terminal is active. Useful for:
- Long-running commands
- SSH sessions
- Monitoring tasks

#### Vibration Feedback

Enable haptic feedback for key presses and interactions.

### Extra Keys

Toggle visibility of the extra keys row above the keyboard.

Configure which keys appear:
- ESC, TAB, CTRL, ALT
- Arrow keys
- Special characters (-, /, ~)

### Language

Switch between supported languages:
- English
- Chinese (Simplified)

## Shell Configuration

### Bash Configuration Files

| File | Purpose |
|------|---------|
| `~/.bashrc` | Executed for interactive shells |
| `~/.profile` | Executed for login shells |
| `~/.bash_history` | Command history storage |
| `~/.bash_logout` | Executed on logout |

### Customizing .bashrc

```bash
# Edit bash configuration
nano ~/.bashrc

# Example customizations:

# Custom prompt
export PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '

# Aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Environment variables
export EDITOR=vim
export VISUAL=vim

# History settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups

# Apply changes
source ~/.bashrc
```

### Environment Variables

Deep Thought sets these environment variables:

| Variable | Description |
|----------|-------------|
| `HOME` | Home directory path |
| `PATH` | Command search paths |
| `TERM` | Terminal type (xterm-256color) |
| `SHELL` | Path to bash |
| `PREFIX` | Termux prefix directory |
| `TMPDIR` | Temporary files directory |
| `LANG` | Locale setting |
| `LS_COLORS` | Directory colors for ls |

### Custom Environment Variables

Add to `~/.bashrc`:

```bash
# Custom paths
export PATH="$HOME/bin:$PATH"

# Development settings
export JAVA_HOME="/path/to/java"
export NODE_PATH="/path/to/node_modules"

# Application settings
export MY_CONFIG="/path/to/config"
```

## SSH Configuration

### SSH Config File

Create `~/.ssh/config` for connection aliases:

```
Host myserver
    HostName 192.168.1.100
    User admin
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host webserver
    HostName example.com
    User deploy
    Port 2222
```

Then connect with: `ssh myserver`

### SSH Key Management

```bash
# Generate new SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Or RSA key
ssh-keygen -t rsa -b 4096

# Copy public key to server
ssh-copy-id user@host

# Manual copy
cat ~/.ssh/id_ed25519.pub
# Paste into server's ~/.ssh/authorized_keys
```

### Known Hosts

SSH remembers server fingerprints in `~/.ssh/known_hosts`.

```bash
# Remove old entry if server changed
ssh-keygen -R hostname
```

## Git Configuration

```bash
# Set identity
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# Useful settings
git config --global core.editor vim
git config --global init.defaultBranch main
git config --global pull.rebase false

# Aliases
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
```

## Package Manager Configuration

### APT Sources

Package sources are configured in `/etc/apt/sources.list`.

### Proxy Configuration

For APT through proxy:

```bash
# Create/edit apt.conf
nano $PREFIX/etc/apt/apt.conf

# Add:
Acquire::http::Proxy "http://proxy:port";
Acquire::https::Proxy "http://proxy:port";
```

For curl/wget:

```bash
# Add to ~/.bashrc
export http_proxy="http://proxy:port"
export https_proxy="http://proxy:port"
```

## Startup Scripts

### Run Commands on Shell Start

Add to `~/.bashrc`:

```bash
# Display system info
echo "Welcome to Deep Thought!"
date
uptime

# Run startup script
if [ -f ~/startup.sh ]; then
    source ~/startup.sh
fi
```

### Task Shortcuts

Use the Task Manager in settings to define quick command shortcuts that appear in the session menu.
