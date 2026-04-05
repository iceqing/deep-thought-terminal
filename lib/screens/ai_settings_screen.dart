import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_config.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import '../widgets/provider_icon.dart';

/// AI 设置页面 — 支持多厂商配置
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

  /// 当前正在编辑的 provider key
  late String _editingKey;
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final aiProvider = context.read<AiProvider>();
    _editingKey = aiProvider.activeProviderKey;

    final pc = aiProvider.allProviderConfigs[_editingKey];
    final preset = AiConfig.allPresets[_editingKey];
    _apiKeyController = TextEditingController(text: pc?.apiKey ?? '');
    _baseUrlController =
        TextEditingController(text: preset?.baseUrl ?? '');
    _modelController =
        TextEditingController(text: preset?.defaultModel ?? '');
    _systemPromptController =
        TextEditingController(text: aiProvider.config.systemPrompt);
    _commandRulesController =
        TextEditingController(text: aiProvider.config.commandRules.join('\n'));
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

  /// 切换编辑的 provider，刷新表单
  void _switchEditing(String key) {
    if (key == _editingKey) return;
    // 先静默保存当前编辑中的
    _saveCurrentProviderSilently();

    final aiProvider = context.read<AiProvider>();
    final pc = aiProvider.allProviderConfigs[key];
    final preset = AiConfig.allPresets[key];

    setState(() {
      _editingKey = key;
      // 优先使用 preset 的默认值（如用户未手动修改过），避免旧数据干扰
      _apiKeyController.text = pc?.apiKey ?? '';
      _baseUrlController.text = preset?.baseUrl ?? '';
      _modelController.text = preset?.defaultModel ?? '';
      _testResult = null;
    });
  }

  void _saveCurrentProviderSilently() {
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    if (apiKey.isEmpty && baseUrl.isEmpty) return;

    final aiProvider = context.read<AiProvider>();
    aiProvider.updateProviderConfig(AiProviderConfig(
      providerKey: _editingKey,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
    ));
  }

  Future<void> _save() async {
    final aiProvider = context.read<AiProvider>();

    // 保存当前编辑的 provider
    final pc = AiProviderConfig(
      providerKey: _editingKey,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );
    await aiProvider.updateProviderConfig(pc);

    // 保存全局设置
    final rules = _commandRulesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await aiProvider.updateConfig(aiProvider.config.copyWith(
      systemPrompt: _systemPromptController.text,
      commandRules: rules,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _saveAndActivate() async {
    final aiProvider = context.read<AiProvider>();
    final pc = AiProviderConfig(
      providerKey: _editingKey,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );
    await aiProvider.saveAndSwitchProvider(pc);

    // 保存全局设置
    final rules = _commandRulesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await aiProvider.updateConfig(aiProvider.config.copyWith(
      systemPrompt: _systemPromptController.text,
      commandRules: rules,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Switched to ${AiConfig.allPresets[_editingKey]?.name ?? _editingKey}')),
      );
    }
  }

  Future<void> _testConnection() async {
    await _save();
    setState(() {
      _testing = true;
      _testResult = null;
    });

    if (!mounted) return;
    final config = context.read<AiProvider>().config;
    final error = await AiService.validateConnection(config);

    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = error ?? 'Connection successful!';
      });
    }
  }

  void _showProviderPicker() {
    final aiProvider = context.read<AiProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProviderPickerSheet(
        selectedKey: _editingKey,
        activeKey: aiProvider.activeProviderKey,
        configuredKeys: aiProvider.configuredProviderKeys.toSet(),
        onSelected: (key) {
          Navigator.pop(ctx);
          if (AiConfig.allPresets[key]?.isCustom == true) {
            _showCustomProviderDialog();
          } else {
            _switchEditing(key);
          }
        },
      ),
    );
  }

  void _showCustomProviderDialog() {
    final urlController = TextEditingController(text: _baseUrlController.text);
    final modelController = TextEditingController(text: _modelController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                labelText: 'Model',
                hintText: 'e.g. gpt-4o',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              final model = modelController.text.trim();
              if (url.isEmpty || model.isEmpty) return;
              setState(() {
                _editingKey = 'custom';
                _baseUrlController.text = url;
                _modelController.text = model;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiProvider = context.watch<AiProvider>();
    final editingPreset = AiConfig.allPresets[_editingKey] ??
        AiConfig.customPreset;
    final isActive = _editingKey == aiProvider.activeProviderKey;
    final isConfigured = aiProvider.configuredProviderKeys.contains(_editingKey);
    final configuredKeys = aiProvider.configuredProviderKeys;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Enable toggle ──
          _Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('Enable AI'),
              subtitle: const Text('Turn on AI assistant features'),
              value: aiProvider.isEnabled,
              onChanged: (v) => aiProvider.setEnabled(v),
            ),
          ),
          const SizedBox(height: 12),

          // ── Configured providers quick bar ──
          if (configuredKeys.length > 1) ...[
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: configuredKeys.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final key = configuredKeys[i];
                  final preset = AiConfig.allPresets[key];
                  if (preset == null) return const SizedBox.shrink();
                  final isActiveChip = key == aiProvider.activeProviderKey;
                  final isEditing = key == _editingKey;
                  return _ConfiguredProviderChip(
                    providerKey: key,
                    preset: preset,
                    model: aiProvider.allProviderConfigs[key]?.model ?? '',
                    isActive: isActiveChip,
                    isEditing: isEditing,
                    onTap: () => _switchEditing(key),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Provider editor ──
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        'Provider',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _ProviderBanner(
                    providerKey: _editingKey,
                    preset: editingPreset,
                    model: _modelController.text.trim(),
                    onTap: _showProviderPicker,
                  ),
                ),
                const SizedBox(height: 16),

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
                      prefixIcon: const Icon(Icons.key, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Base URL
                TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link, size: 20),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),

                // Model
                LayoutBuilder(builder: (ctx, _) {
                  final preset = AiConfig.allPresets[_editingKey];
                  final suggestions = preset?.commonModels ?? [];
                  return Autocomplete<String>(
                    key: ValueKey('model_$_editingKey'),
                    initialValue: TextEditingValue(
                      text: _modelController.text,
                      selection: TextSelection.collapsed(
                          offset: _modelController.text.length),
                    ),
                    optionsBuilder: (textEditingValue) {
                      // Always show all suggestions in the dropdown so user can switch
                      return suggestions;
                    },
                    fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                      controller.addListener(() {
                        if (controller.text != _modelController.text) {
                          _modelController.text = controller.text;
                        }
                      });
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Model',
                          hintText: suggestions.isNotEmpty
                              ? suggestions.first
                              : 'Enter model name',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.model_training, size: 20),
                          suffixIcon: suggestions.isNotEmpty
                              ? Icon(Icons.arrow_drop_down,
                                  color: theme.colorScheme.onSurfaceVariant)
                              : null,
                        ),
                      );
                    },
                    optionsViewBuilder: (ctx, onSelect, options) {
                      final screenW = MediaQuery.of(ctx).size.width;
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 200,
                              maxWidth: screenW - 64,
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (ctx, i) {
                                final opt = options.elementAt(i);
                                return InkWell(
                                  onTap: () => onSelect(opt),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(Icons.model_training,
                                            size: 16,
                                            color: theme.colorScheme.primary),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(opt,
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (model) {
                      _modelController.text = model;
                    },
                  );
                }),
                const SizedBox(height: 12),

                // Advanced settings
                ExpansionTile(
                  leading: const Icon(Icons.tune, size: 20),
                  title: const Text('Advanced'),
                  subtitle: const Text('Temperature'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Row(
                      children: [
                        Text('Temperature',
                            style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        Text(
                          aiProvider.config.temperature.toStringAsFixed(1),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: aiProvider.config.temperature,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      onChanged: (v) {
                        aiProvider.updateConfig(
                            aiProvider.config.copyWith(temperature: v));
                      },
                    ),
                  ],
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label:
                              Text(_testing ? 'Testing...' : 'Test'),
                        ),
                      ),
                      if (!isActive) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveAndActivate,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text('Activate'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (isConfigured && !isActive)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Remove provider?'),
                              content: Text(
                                  'Remove saved config for ${editingPreset.name}?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove')),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            await aiProvider.removeProviderConfig(_editingKey);
                            _switchEditing(aiProvider.activeProviderKey);
                          }
                        },
                        icon: Icon(Icons.delete_outline,
                            size: 16, color: theme.colorScheme.error),
                        label: Text('Remove this provider',
                            style: TextStyle(
                                color: theme.colorScheme.error, fontSize: 12)),
                      ),
                    ),
                  ),

                if (_testResult != null)
                  _TestResultBanner(result: _testResult!),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Feature toggles ──
          _Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.bug_report_outlined),
                  title: const Text('Auto Error Diagnosis'),
                  subtitle:
                      const Text('Analyze failed commands automatically'),
                  value: aiProvider.config.autoErrorDiagnosis,
                  onChanged: aiProvider.isEnabled
                      ? (v) => aiProvider.updateConfig(
                          aiProvider.config.copyWith(autoErrorDiagnosis: v))
                      : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.input),
                  title: const Text('Show Inline Bar'),
                  subtitle: const Text('Quick AI input bar below terminal'),
                  value: aiProvider.config.showInlineBar,
                  onChanged: aiProvider.isEnabled
                      ? (v) => aiProvider.updateConfig(
                          aiProvider.config.copyWith(showInlineBar: v))
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Advanced config ──
          _Card(
            child: Column(
              children: [
                ExpansionTile(
                  leading: const Icon(Icons.rule_folder_outlined, size: 20),
                  title: const Text('Command Rules'),
                  subtitle: const Text('Permissions and confirmations'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'allow:ls:* = auto-run\n'
                            'ask:git push = confirm\n'
                            'deny:rm -rf / = block',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.add_circle_outline, size: 20),
                          tooltip: 'Add example rules',
                          onPressed: () {
                            final current =
                                _commandRulesController.text.trim();
                            const examples =
                                '# Auto-allow\nallow:ls:*\nallow:cat *\n'
                                'allow:pwd\nallow:echo *\n# Ask\n'
                                'ask:git push\nask:npm install *\n'
                                '# Deny\ndeny:rm -rf /\ndeny:dd if=*';
                            _commandRulesController.text = current.isEmpty
                                ? examples
                                : '$current\n$examples';
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commandRulesController,
                      maxLines: 8,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'allow:ls:*\nask:git push\ndeny:rm -rf /',
                        hintStyle: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  leading:
                      const Icon(Icons.psychology_alt_outlined, size: 20),
                  title: const Text('System Prompt'),
                  subtitle: const Text('Advanced behavior tuning'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextField(
                      controller: _systemPromptController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Customize the AI system prompt...',
                        helperText:
                            'Variables: {shell_type}, {cwd}, {last_command}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Danger zone ──
          _Card(
            child: ListTile(
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
                if (!mounted) return;
                if (confirmed == true) {
                  await context.read<AiProvider>().clearHistory();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Private widgets
// ═══════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Horizontal chip for configured providers quick-bar
class _ConfiguredProviderChip extends StatelessWidget {
  final String providerKey;
  final AiPreset preset;
  final String model;
  final bool isActive;
  final bool isEditing;
  final VoidCallback onTap;

  const _ConfiguredProviderChip({
    required this.providerKey,
    required this.preset,
    required this.model,
    required this.isActive,
    required this.isEditing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isEditing
        ? preset.color
        : isActive
            ? Colors.green
            : Colors.transparent;
    final bgColor = isEditing
        ? preset.color.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHigh;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProviderIcon(
                  providerKey: providerKey, color: preset.color, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    preset.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  if (model.isNotEmpty)
                    Text(
                      model,
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider banner (tap to open picker)
class _ProviderBanner extends StatelessWidget {
  final String providerKey;
  final AiPreset preset;
  final String model;
  final VoidCallback onTap;

  const _ProviderBanner({
    required this.providerKey,
    required this.preset,
    required this.model,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              preset.color.withValues(alpha: 0.15),
              preset.color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: preset.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ProviderIcon(
                providerKey: providerKey, color: preset.color, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (model.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(model,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: preset.color, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Icon(Icons.swap_horiz_rounded,
                color: theme.colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Test result banner
class _TestResultBanner extends StatelessWidget {
  final String result;
  const _TestResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final ok = result.contains('successful');
    final color = ok ? Colors.green : Theme.of(context).colorScheme.error;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(result, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Provider picker bottom sheet
// ═══════════════════════════════════════════════════════════

class _ProviderPickerSheet extends StatelessWidget {
  final String selectedKey;
  final String activeKey;
  final Set<String> configuredKeys;
  final ValueChanged<String> onSelected;

  const _ProviderPickerSheet({
    required this.selectedKey,
    required this.activeKey,
    required this.configuredKeys,
    required this.onSelected,
  });

  static const _internationalKeys = [
    'openai', 'anthropic', 'openrouter', 'groq', 'ollama', 'mistral', 'cohere',
  ];
  static const _chinaKeys = [
    'deepseek', 'xiaomi', 'minimax', 'minimax_openai', 'siliconflow',
    'qwen', 'volcengine', 'moonshot', 'zhipu', 'yi', 'stepfun', 'baidu',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    // Show configured providers first if any
    final hasConfigured = configuredKeys.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text('Select Provider',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (hasConfigured) ...[
                      _SectionHeader(
                          label:
                              'Configured (${configuredKeys.length})'),
                      const SizedBox(height: 8),
                      _buildGrid(context,
                          configuredKeys.toList()..sort()),
                      const SizedBox(height: 20),
                    ],
                    _SectionHeader(label: 'International'),
                    const SizedBox(height: 8),
                    _buildGrid(context, _internationalKeys),
                    const SizedBox(height: 20),
                    _SectionHeader(label: 'China'),
                    const SizedBox(height: 8),
                    _buildGrid(context, _chinaKeys),
                    const SizedBox(height: 20),
                    _SectionHeader(label: 'Other'),
                    const SizedBox(height: 8),
                    _buildGrid(context, const ['custom']),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<String> keys) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 500 ? 4 : 3;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: keys.map((key) {
          final preset = AiConfig.allPresets[key];
          if (preset == null) return const SizedBox.shrink();
          final isSelected = key == selectedKey;
          final isConfigured = configuredKeys.contains(key);
          final isActiveProvider = key == activeKey;
          final itemWidth =
              (constraints.maxWidth - (columns - 1) * 10) / columns;
          return SizedBox(
            width: itemWidth,
            child: _ProviderChip(
              providerKey: key,
              preset: preset,
              isSelected: isSelected,
              isConfigured: isConfigured,
              isActive: isActiveProvider,
              onTap: () => onSelected(key),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(label,
            style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
            child: Divider(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ],
    );
  }
}

/// Single provider chip in the grid
class _ProviderChip extends StatelessWidget {
  final String providerKey;
  final AiPreset preset;
  final bool isSelected;
  final bool isConfigured;
  final bool isActive;
  final VoidCallback onTap;

  const _ProviderChip({
    required this.providerKey,
    required this.preset,
    required this.isSelected,
    required this.isConfigured,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? preset.color.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? preset.color.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProviderIcon(
                    providerKey: providerKey,
                    color: isSelected
                        ? preset.color
                        : theme.colorScheme.onSurfaceVariant,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preset.name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? preset.color
                          : theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!preset.isCustom) ...[
                    const SizedBox(height: 2),
                    Text(
                      preset.defaultModel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Configured badge
            if (isConfigured && !isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : preset.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            if (isActive && isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle,
                    color: Colors.green, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}
