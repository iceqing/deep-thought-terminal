import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_config.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';

/// AI 设置页面
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  late TextEditingController _systemPromptController;
  late TextEditingController _commandRulesController;
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final config = context.read<AiProvider>().config;
    _apiKeyController = TextEditingController(text: config.apiKey);
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _modelController = TextEditingController(text: config.model);
    _systemPromptController = TextEditingController(text: config.systemPrompt);
    _commandRulesController = TextEditingController(
      text: config.commandRules.join('\n'),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _systemPromptController.dispose();
    _commandRulesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<AiProvider>();
    final rules = _commandRulesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await provider.updateConfig(provider.config.copyWith(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      systemPrompt: _systemPromptController.text,
      commandRules: rules,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI settings saved')),
      );
    }
  }

  Future<void> _testConnection() async {
    await _save();
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final config = context.read<AiProvider>().config;
    final error = await AiService.validateConnection(config);

    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = error == null ? 'Connection successful!' : error;
      });
    }
  }

  void _applyPreset(String key) {
    final preset = AiConfig.allPresets[key];
    if (preset == null) return;

    if (preset.isCustom) {
      _showCustomProviderDialog();
      return;
    }

    setState(() {
      _baseUrlController.text = preset.baseUrl;
      _modelController.text = preset.defaultModel;
    });
  }

  void _showCustomProviderDialog() {
    final urlController = TextEditingController();
    final modelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义供应商'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '输入 OpenAI 兼容 API 的 Base URL 和模型名称',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://api.example.com/v1',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(
                labelText: '模型名称',
                hintText: 'e.g. gpt-4o, deepseek-chat',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              final model = modelController.text.trim();
              if (url.isEmpty || model.isEmpty) return;
              setState(() {
                _baseUrlController.text = url;
                _modelController.text = model;
              });
              Navigator.pop(ctx);
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiProvider = context.watch<AiProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Enable toggle
          _Section(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome),
                title: const Text('Enable AI'),
                subtitle: const Text('Turn on AI assistant features'),
                value: aiProvider.isEnabled,
                onChanged: (v) => aiProvider.setEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // API Configuration
          _Section(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'API Configuration',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              // Presets - International
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'International',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: AiConfig.internationalPresets.entries.map((e) {
                    return ActionChip(
                      label: Text(e.value.name),
                      onPressed: () => _applyPreset(e.key),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 4),

              // Presets - 国内
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '国内',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: AiConfig.chinaPresets.entries.map((e) {
                    return ActionChip(
                      label: Text(e.value.name),
                      onPressed: () => _applyPreset(e.key),
                    );
                  }).toList(),
                ),
              ),

              // Custom
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('自定义'),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  side: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  onPressed: _showCustomProviderDialog,
                ),
              ),
              const SizedBox(height: 8),

              // API Key
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Base URL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(height: 12),

              // Model
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'gpt-4o-mini',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.model_training),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Temperature
              ListTile(
                leading: const Icon(Icons.thermostat),
                title: Text(
                    'Temperature: ${aiProvider.config.temperature.toStringAsFixed(1)}'),
                subtitle: Slider(
                  value: aiProvider.config.temperature,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  label: aiProvider.config.temperature.toStringAsFixed(1),
                  onChanged: (v) {
                    context.read<AiProvider>().updateConfig(
                          aiProvider.config.copyWith(temperature: v),
                        );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Test Connection
          _Section(
            children: [
              ListTile(
                leading: const Icon(Icons.wifi_tethering),
                title: const Text('Test Connection'),
                subtitle: _testing
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Testing...'),
                        ],
                      )
                    : _testResult != null
                        ? Text(
                            _testResult!,
                            style: TextStyle(
                              color: _testResult!.contains('successful')
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          )
                        : null,
                trailing: const Icon(Icons.play_arrow),
                onTap: _testing ? null : _testConnection,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Command Permission Rules (Claude Code style)
          _Section(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Command Rules',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '参考 Claude Code 权限规则语法',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      tooltip: 'Add example rules',
                      onPressed: () {
                        final current = _commandRulesController.text.trim();
                        final examples = [
                          '# 自动允许（无需确认）',
                          'allow:ls:*',
                          'allow:cat *',
                          'allow:pwd',
                          'allow:echo *',
                          '# 询问确认（默认）',
                          'ask:git push',
                          'ask:npm install *',
                          '# 禁止执行',
                          'deny:rm -rf /',
                          'deny:dd if=*',
                        ].join('\n');
                        _commandRulesController.text =
                            current.isEmpty ? examples : '$current\n$examples';
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'allow:ls:* = 自动执行\n'
                  'ask:git push = 弹窗确认\n'
                  'deny:rm -rf / = 禁止执行',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _commandRulesController,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'allow:ls:*\nask:git push\ndeny:rm -rf /',
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Features
          _Section(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Features',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bug_report_outlined),
                title: const Text('Auto Error Diagnosis'),
                subtitle: const Text('Automatically analyze failed commands'),
                value: aiProvider.config.autoErrorDiagnosis,
                onChanged: aiProvider.isEnabled
                    ? (v) => aiProvider.updateConfig(
                        aiProvider.config.copyWith(autoErrorDiagnosis: v))
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.input),
                title: const Text('Show Inline Bar'),
                subtitle: const Text('Show quick AI input bar below terminal'),
                value: aiProvider.config.showInlineBar,
                onChanged: aiProvider.isEnabled
                    ? (v) => aiProvider.updateConfig(
                        aiProvider.config.copyWith(showInlineBar: v))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // System Prompt
          _Section(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'System Prompt',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _systemPromptController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Customize the AI system prompt...',
                    helperText:
                        'Variables: {shell_type}, {cwd}, {last_command}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Danger zone
          _Section(
            children: [
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text('Clear Chat History',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear Chat History?'),
                      content:
                          const Text('This will delete all AI chat history.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await context.read<AiProvider>().clearHistory();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}
