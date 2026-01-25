# Deep Thought (深思终端)

<p align="center">
  <img src="assets/icon/app_icon_pure.svg" alt="Deep Thought Logo" width="128" height="128">
</p>

<p align="center">
  <strong>受 Termux 启发，基于 Flutter 构建的强大 Android 终端模拟器</strong>
</p>

<p align="center">
  <a href="#特性">特性</a> •
  <a href="#截图">应用截图</a> •
  <a href="#安装">安装指南</a> •
  <a href="#编译">源码编译</a> •
  <a href="#使用说明">使用说明</a> •
  <a href="#开源协议">开源协议</a>
</p>

---

## 项目简介

**Deep Thought** 是一款功能丰富的终端模拟器，采用 Flutter 框架开发，致力于在 Android 设备上提供完整的 Linux 命令行体验。它利用 Termux 的 bootstrap 引导包构建了一个完整的 Linux 环境，内置了包管理器、开发工具及常用的终端实用程序。

**为什么叫 "Deep Thought"？** 名字取自《银河系漫游指南》中的超级计算机“深思”。我们希望这款终端能成为您在移动设备上进行深度计算和开发任务的可靠伙伴。

## 特性

### 核心终端功能
- **完整 Linux 环境**：由 Termux bootstrap 提供支持（包含 bash, coreutils, apt 等）。
- **多会话管理**：支持同时创建和切换多个终端会话。
- **Nerd Font 支持**：内置多种 Nerd Fonts，完美显示 Powerline 图标及 p10k 皮肤。
- **完美的 p10k 兼容性**：针对 Powerlevel10k 进行了特殊优化，解决字符宽度和行高对齐问题。

### 交互体验
- **双指缩放**：通过直观的双指手势实时调节字体大小。
- **扩展按键栏**：快速访问 Ctrl, Alt, Tab, Esc 以及方向键。
- **音量键修饰符**：支持将音量上键作为 Ctrl，音量下键作为 Alt 使用。
- **自定义主题**：内置多种经典配色（Monokai, Dracula, Nord, Solarized 等）。
- **屏幕常亮**：在执行长时间任务时防止系统休眠。

### 高阶功能
- **SSH 管理器**：保存常用 SSH 主机信息，一键连接。
- **任务/脚本快捷键**：预定义常用命令脚本，一键执行。
- **命令历史**：具备持久化存储的可搜索命令历史记录。
- **文本选择**：优化了触摸选择体验，支持水滴手柄扩选及复制。
- **多语言支持**：原生支持中文和英文。

### 技术亮点
- **自定义 wcwidth 实现**：兼容 Termux 的字符宽度计算逻辑，确保中日韩（CJK）字符和 Emoji 不错位。
- **精准的调整监听**：正确传播 SIGWINCH 信号，完美适配 vim, htop 等全屏交互应用。
- **Alt Buffer 支持**：完整处理全屏切换逻辑。

## 应用截图

*即将推出*

## 安装

### 系统要求
- Android 7.0 (API 24) 或更高版本。
- 架构支持：ARM64 (aarch64) 或 x86_64。

### 下载
前往 [Releases](https://github.com/user/deep-thought/releases) 页面下载最新的 APK 安装包。

### 首次启动
首次启动时，Deep Thought 会自动执行以下初始化：
1. 解压 Termux 引导环境 (Bootstrap)。
2. 建立 Linux 文件系统结构。
3. 配置 Bash 及基础工具。

根据设备性能，此过程通常需要 30 秒到 2 分钟。

## 编译

### 前置条件
- Flutter SDK 3.0.0 或更高版本。
- 安装了 NDK 的 Android SDK。
- Linux 编译需要：GTK 3.0 开发库。

### 编译步骤

```bash
# 克隆仓库
git clone https://github.com/user/deep-thought.git
cd deep-thought

# 获取依赖
flutter pub get

# 编译 Android APK
flutter build apk --release

# 编译 Linux 桌面版
flutter build linux --release

# 调试模式运行
flutter run -d android
```

## 使用说明

### 基础操作

| 动作 | 手势/按键 |
|--------|-------------|
| 唤起键盘 | 点击终端屏幕区域 |
| 隐藏键盘 | 点击工具栏的键盘图标 |
| 选择文本 | 长按并拖动水滴手柄 |
| 复制选区 | 点击弹出菜单中的“复制” |
| 粘贴 | 更多菜单 → 粘贴 |
| 缩放字体 | 双指捏合/张开 |
| Ctrl+C | 音量上键 + C (或扩展栏 Ctrl + C) |
| Alt+键 | 音量下键 + 对应键 |

### 软件包管理

Deep Thought 使用 `apt` 进行软件包管理：

```bash
# 更新软件源
apt update

# 安装软件包
apt install vim git python

# 搜索软件包
apt search <关键词>

# 升级所有软件包
apt upgrade
```

### SSH 连接

1. 进入 **菜单 → 设置 → SSH 管理器**。
2. 添加新的主机连接详情。
3. 在 **菜单 → 新建会话 → [您的 SSH 主机]** 中快速连接。

## 开源协议

本项目采用 **GNU General Public License v3.0 (GPLv3)** 协议开源。详情请参阅 [LICENSE](LICENSE) 文件。

### 引导环境与授权说明

本应用使用 **Termux bootstrap packages** 提供底层 Linux 环境：

*   **Deep Thought App**: 应用层代码（Flutter/Dart）采用 **GPLv3** 协议，与上游 Termux 项目保持一致，以确保最大的兼容性和自由度。
*   **Termux Packages**: 应用下载并解压的引导环境衍生自 [Termux](https://termux.dev/) 项目，这些组件保留其原始开源许可（主要是 GPLv3 及其各自软件包的许可）。

## 致谢

- [Termux](https://termux.dev/) - 提供引导环境、文件系统标准及项目灵感。
- [xterm.dart](https://pub.dev/packages/xterm) - 核心终端模拟库。
- [flutter_pty](https://pub.dev/packages/flutter_pty) - Flutter PTY 支持。
- [Nerd Fonts](https://www.nerdfonts.com/) - 提供美观的图标补丁字体。

---

<p align="center">
  使用 ❤️ 和 Flutter 构建
</p>
