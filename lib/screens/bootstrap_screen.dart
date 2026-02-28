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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // 自动开始安装
    _startInstallation();
  }

  Future<void> _startInstallation() async {
    setState(() {
      _hasError = false;
    });

    // 可以在这里静默请求权限，或者让 TermuxBootstrap 内部处理
    // 为了不打扰用户，我们只显示一个简单的加载动画
    
    final success = await TermuxBootstrap.initialize(
      onProgress: (status, progress, message) {
        // 我们不再更新 UI 显示具体的进度消息，保持界面简洁
        // 只在后台记录日志
        debugPrint('Bootstrap: $status - $message ($progress)');
      },
    );

    if (success) {
      // 延迟一下让用户看到完成状态
      await Future.delayed(const Duration(milliseconds: 500));
      // 使用 addPostFrameCallback 确保在 widget 还在时调用
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onComplete();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branded Loading View
                if (!_hasError) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: theme.colorScheme.primary.withAlpha(150),
                        ),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: const DecorationImage(
                            image: AssetImage('assets/icon/playstore_icon.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Initializing environment...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preparing your powerful terminal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Initialization failed',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please check your storage permissions and try again.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _startInstallation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}