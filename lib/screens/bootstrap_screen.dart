import 'package:flutter/material.dart';
import '../bootstrap/termux_bootstrap.dart';

/// Bootstrap 初始化屏幕
/// 显示安装进度和状态
class BootstrapScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const BootstrapScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  BootstrapStatus _status = BootstrapStatus.notInstalled;
  double _progress = 0.0;
  String _message = 'Checking installation status...';
  bool _isInstalling = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // 自动开始安装
    _startInstallation();
  }

  Future<void> _startInstallation() async {
    if (_isInstalling) return;

    setState(() {
      _isInstalling = true;
      _hasError = false;
      _message = 'Starting installation...';
      _progress = 0.0;
    });

    final success = await TermuxBootstrap.initialize(
      onProgress: (status, progress, message) {
        if (mounted) {
          setState(() {
            _status = status;
            _progress = progress;
            _message = message;
            _hasError = status == BootstrapStatus.error;
          });
        }
      },
    );

    if (success) {
      // 延迟一下让用户看到完成状态
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onComplete();
    } else {
      setState(() {
        _isInstalling = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/图标
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.terminal,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),

              // 标题
              Text(
                'Deep Thought Terminal',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'A Termux-like terminal for Android',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),

              // 状态消息
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _hasError
                      ? Colors.red.withAlpha(30)
                      : Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_isInstalling) ...[
                      // 进度条
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white.withAlpha(20),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 状态图标
                    if (_hasError)
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      )
                    else if (_status == BootstrapStatus.installed)
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 48,
                      )
                    else if (_isInstalling)
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),

                    const SizedBox(height: 16),

                    // 消息文本
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _hasError ? Colors.red[300] : Colors.white70,
                        fontSize: 14,
                      ),
                    ),

                    if (_isInstalling) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 按钮
              if (!_isInstalling) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startInstallation,
                    icon: Icon(_hasError ? Icons.refresh : Icons.download),
                    label: Text(_hasError ? 'Retry Installation' : 'Install Environment'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

              ],

              const Spacer(),

              // 底部说明
              Text(
                'Extract ~30MB of Linux tools\nincluding bash, apt, ssh, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
