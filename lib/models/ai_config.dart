import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
//  Per-provider credential record
// ═══════════════════════════════════════════════════════════

class AiProviderConfig {
  final String providerKey;
  final String apiKey;
  final String baseUrl;
  final String model;

  const AiProviderConfig({
    required this.providerKey,
    this.apiKey = '',
    this.baseUrl = '',
    this.model = '',
  });

  bool get isConfigured => apiKey.isNotEmpty && baseUrl.isNotEmpty;

  AiProviderConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) =>
      AiProviderConfig(
        providerKey: providerKey,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
      );

  Map<String, dynamic> toJson() => {
        'providerKey': providerKey,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'model': model,
      };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) =>
      AiProviderConfig(
        providerKey: json['providerKey'] as String? ?? 'custom',
        apiKey: json['apiKey'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        model: json['model'] as String? ?? '',
      );
}

// ═══════════════════════════════════════════════════════════
//  Provider registry (multi-provider store)
// ═══════════════════════════════════════════════════════════

class AiProviderRegistry {
  final Map<String, AiProviderConfig> providers;
  final String activeProviderKey;

  const AiProviderRegistry({
    this.providers = const {},
    this.activeProviderKey = 'openai',
  });

  AiProviderConfig? get activeProvider => providers[activeProviderKey];

  List<String> get configuredKeys =>
      providers.entries.where((e) => e.value.isConfigured).map((e) => e.key).toList();

  AiProviderRegistry copyWith({
    Map<String, AiProviderConfig>? providers,
    String? activeProviderKey,
  }) =>
      AiProviderRegistry(
        providers: providers ?? this.providers,
        activeProviderKey: activeProviderKey ?? this.activeProviderKey,
      );

  Map<String, dynamic> toJson() => {
        'activeProviderKey': activeProviderKey,
        'providers': providers.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory AiProviderRegistry.fromJson(Map<String, dynamic> json) {
    final rawProviders = json['providers'] as Map<String, dynamic>? ?? {};
    final providers = rawProviders.map((k, v) =>
        MapEntry(k, AiProviderConfig.fromJson(v as Map<String, dynamic>)));
    return AiProviderRegistry(
      activeProviderKey: json['activeProviderKey'] as String? ?? 'openai',
      providers: providers,
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  AiConfig (composite: registry + global settings)
// ═══════════════════════════════════════════════════════════

class AiConfig {
  final AiProviderRegistry providerRegistry;
  final double temperature;
  final int maxTokens;
  final bool enabled;
  final bool autoErrorDiagnosis;
  final bool showInlineBar;
  final String systemPrompt;
  final List<String> commandRules;

  const AiConfig({
    this.providerRegistry = const AiProviderRegistry(),
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.enabled = false,
    this.autoErrorDiagnosis = false,
    this.showInlineBar = true,
    this.systemPrompt = defaultSystemPrompt,
    this.commandRules = const [],
  });

  // ── Computed getters (backward-compat) ──
  String get apiKey => providerRegistry.activeProvider?.apiKey ?? '';
  String get baseUrl =>
      providerRegistry.activeProvider?.baseUrl ?? 'https://api.openai.com/v1';
  String get model =>
      providerRegistry.activeProvider?.model ?? 'gpt-4o-mini';
  bool get isConfigured =>
      providerRegistry.activeProvider?.isConfigured ?? false;
  String get activeProviderKey => providerRegistry.activeProviderKey;
  List<String> get configuredProviderKeys => providerRegistry.configuredKeys;

  static const defaultSystemPrompt =
      'You are an AI assistant integrated into a terminal emulator. '
      'You help users with shell commands, error diagnosis, and general terminal tasks. '
      'When generating commands, output ONLY the command with no explanation unless asked. '
      'The current shell is {shell_type} and the working directory is {cwd}.';

  String resolveSystemPrompt({
    String? shellType,
    String? cwd,
    String? lastCommand,
  }) {
    return systemPrompt
        .replaceAll('{shell_type}', shellType ?? 'bash')
        .replaceAll('{cwd}', cwd ?? '~')
        .replaceAll('{last_command}', lastCommand ?? '(none)');
  }

  AiConfig copyWith({
    AiProviderRegistry? providerRegistry,
    double? temperature,
    int? maxTokens,
    bool? enabled,
    bool? autoErrorDiagnosis,
    bool? showInlineBar,
    String? systemPrompt,
    List<String>? commandRules,
  }) {
    return AiConfig(
      providerRegistry: providerRegistry ?? this.providerRegistry,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      enabled: enabled ?? this.enabled,
      autoErrorDiagnosis: autoErrorDiagnosis ?? this.autoErrorDiagnosis,
      showInlineBar: showInlineBar ?? this.showInlineBar,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      commandRules: commandRules ?? this.commandRules,
    );
  }

  Map<String, dynamic> toJson() => {
        'providerRegistry': providerRegistry.toJson(),
        'temperature': temperature,
        'maxTokens': maxTokens,
        'enabled': enabled,
        'autoErrorDiagnosis': autoErrorDiagnosis,
        'showInlineBar': showInlineBar,
        'systemPrompt': systemPrompt,
        'commandRules': commandRules,
      };

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    // ── Migration: detect legacy single-provider format ──
    AiProviderRegistry registry;
    if (json.containsKey('providerRegistry')) {
      registry = AiProviderRegistry.fromJson(
          json['providerRegistry'] as Map<String, dynamic>);
    } else {
      // Legacy flat config
      final apiKey = json['apiKey'] as String? ?? '';
      final baseUrl =
          json['baseUrl'] as String? ?? 'https://api.openai.com/v1';
      final model = json['model'] as String? ?? 'gpt-4o-mini';

      String detectedKey = 'custom';
      for (final entry in AiConfig.allPresets.entries) {
        if (!entry.value.isCustom && entry.value.baseUrl == baseUrl) {
          detectedKey = entry.key;
          break;
        }
      }

      registry = AiProviderRegistry(
        activeProviderKey: detectedKey,
        providers: {
          detectedKey: AiProviderConfig(
            providerKey: detectedKey,
            apiKey: apiKey,
            baseUrl: baseUrl,
            model: model,
          ),
        },
      );
    }

    return AiConfig(
      providerRegistry: registry,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] as int? ?? 2048,
      enabled: json['enabled'] as bool? ?? false,
      autoErrorDiagnosis: json['autoErrorDiagnosis'] as bool? ?? false,
      showInlineBar: json['showInlineBar'] as bool? ?? true,
      systemPrompt: json['systemPrompt'] as String? ?? defaultSystemPrompt,
      commandRules:
          (json['commandRules'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  Provider presets
  // ═══════════════════════════════════════════════════════════

  static const internationalPresets = <String, AiPreset>{
    'openai': AiPreset(
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4o-mini',
      commonModels: ['gpt-4o-mini', 'gpt-4o', 'gpt-4o-realtime-preview'],
    ),
    'anthropic': AiPreset(
      name: 'Anthropic',
      baseUrl: 'https://api.anthropic.com/v1',
      defaultModel: 'claude-sonnet-4-20250514',
      commonModels: [
        'claude-sonnet-4-20250514',
        'claude-opus-4-5',
        'claude-3-5-sonnet-latest',
        'claude-3-opus-latest',
        'claude-3-haiku-latest',
      ],
    ),
    'openrouter': AiPreset(
      name: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      defaultModel: 'anthropic/claude-sonnet-4',
      commonModels: [
        'anthropic/claude-sonnet-4',
        'anthropic/claude-3.5-sonnet',
        'openai/gpt-4o-mini',
        'google/gemini-pro-1.5',
        'meta-llama/llama-3-70b-instruct',
        'deepseek/deepseek-chat-v3',
      ],
    ),
    'groq': AiPreset(
      name: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'llama-3.3-70b-versatile',
      commonModels: [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
        'mixtral-8x7b-32768',
        'gemma2-9b-it',
      ],
    ),
    'ollama': AiPreset(
      name: 'Ollama',
      baseUrl: 'http://localhost:11434/v1',
      defaultModel: 'qwen2.5-coder:7b',
      commonModels: ['qwen2.5-coder:7b', 'qwen2.5:14b', 'llama3.1:8b', 'codellama:7b', 'mistral:7b'],
    ),
    'mistral': AiPreset(
      name: 'Mistral AI',
      baseUrl: 'https://api.mistral.ai/v1',
      defaultModel: 'mistral-small-latest',
      commonModels: ['mistral-small-latest', 'mistral-large-latest', 'mistral-nemo', 'codestral-latest'],
    ),
    'cohere': AiPreset(
      name: 'Cohere',
      baseUrl: 'https://api.cohere.ai/v1',
      defaultModel: 'command-r-plus',
      commonModels: ['command-r-plus', 'command-r7b', 'command', 'c4ai-llama3-70b'],
    ),
  };

  static const chinaPresets = <String, AiPreset>{
    'deepseek': AiPreset(
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      defaultModel: 'deepseek-chat',
      commonModels: ['deepseek-chat', 'deepseek-coder', 'deepseek-reasoner'],
    ),
    'xiaomi': AiPreset(
      name: '小米 MiMo',
      baseUrl: 'https://api.xiaomi.com/v1',
      defaultModel: 'MiMo-7B-RL',
      commonModels: ['MiMo-7B-RL', 'MiMo-14B', 'MiMo-72B'],
    ),
    'minimax': AiPreset(
      name: 'MiniMax',
      baseUrl: 'https://api.minimaxi.com/anthropic/v1',
      defaultModel: 'MiniMax-M2.7',
      commonModels: ['MiniMax-M2.7', 'MiniMax-M2', 'MiniMax-Speech-02'],
    ),
    'minimax_openai': AiPreset(
      name: 'MiniMax (OpenAI)',
      baseUrl: 'https://api.minimaxi.com/v1',
      defaultModel: 'MiniMax-Text-01',
      commonModels: ['MiniMax-Text-01'],
    ),
    'siliconflow': AiPreset(
      name: '硅基流动',
      baseUrl: 'https://api.siliconflow.cn/v1',
      defaultModel: 'deepseek-ai/DeepSeek-V3',
      commonModels: [
        'deepseek-ai/DeepSeek-V3',
        'deepseek-ai/DeepSeek-Coder-V2',
        'Qwen/Qwen2.5-72B-Instruct',
        'THUDM/glm-4-9b-chat',
      ],
    ),
    'qwen': AiPreset(
      name: '通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      defaultModel: 'qwen-plus',
      commonModels: [
        'qwen-plus',
        'qwen-max',
        'qwen-turbo',
        'qwen2.5-72b-instruct',
        'qwen2.5-coder-32b',
      ],
    ),
    'volcengine': AiPreset(
      name: '火山引擎',
      baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      defaultModel: 'doubao-pro-32k',
      commonModels: ['doubao-pro-32k', 'doubao-pro-128k', 'doubao-lite-32k', 'skylark2-pro-4k'],
    ),
    'moonshot': AiPreset(
      name: 'Moonshot (Kimi)',
      baseUrl: 'https://api.moonshot.cn/v1',
      defaultModel: 'moonshot-v1-8k',
      commonModels: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
    ),
    'zhipu': AiPreset(
      name: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      defaultModel: 'glm-4-flash',
      commonModels: ['glm-4-flash', 'glm-4', 'glm-4-plus', 'glm-4v-flash', 'glm-4v-plus'],
    ),
    'yi': AiPreset(
      name: '零一万物',
      baseUrl: 'https://api.lingyiwanwu.com/v1',
      defaultModel: 'yi-large',
      commonModels: ['yi-large', 'yi-large-rag', 'yi-medium', 'yi-spark'],
    ),
    'stepfun': AiPreset(
      name: '阶跃星辰',
      baseUrl: 'https://api.stepfun.com/v1',
      defaultModel: 'step-1v-8k',
      commonModels: ['step-1v-8k', 'step-1o-mini', 'step-1o'],
    ),
    'baidu': AiPreset(
      name: '百度文心',
      baseUrl: 'https://qianfan.baidubce.com/v2',
      defaultModel: 'ernie-4.0-8k-latest',
      commonModels: ['ernie-4.0-8k-latest', 'ernie-4.0-128k', 'ernie-3.5-8k', 'ernie-speed-128k'],
    ),
  };

  static const customPreset = AiPreset(
    name: 'Custom',
    baseUrl: '',
    defaultModel: '',
    isCustom: true,
  );

  static Map<String, AiPreset> get allPresets => {
        ...internationalPresets,
        ...chinaPresets,
        'custom': customPreset,
      };
}

// ═══════════════════════════════════════════════════════════
//  Preset definition
// ═══════════════════════════════════════════════════════════

class AiPreset {
  final String name;
  final String baseUrl;
  final String defaultModel;
  final String? region;
  final bool isCustom;
  final List<String> commonModels;

  const AiPreset({
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.region,
    this.isCustom = false,
    this.commonModels = const [],
  });

  Color get color {
    switch (name) {
      case 'OpenAI':
        return const Color(0xFF10A37F);
      case 'Anthropic':
        return const Color(0xFFD97757);
      case 'OpenRouter':
        return const Color(0xFF6366F1);
      case 'DeepSeek':
        return const Color(0xFF4D6BFE);
      case '小米 MiMo':
        return const Color(0xFFFF6900);
      case 'MiniMax':
      case 'MiniMax (OpenAI)':
        return const Color(0xFF00D8C6);
      case 'Groq':
        return const Color(0xFFF55036);
      case 'Ollama':
        return const Color(0xFF1A1A1A);
      case 'Mistral AI':
        return const Color(0xFFFF7000);
      case 'Cohere':
        return const Color(0xFF39594D);
      case '硅基流动':
        return const Color(0xFF6366F1);
      case '通义千问':
        return const Color(0xFF615CEA);
      case '火山引擎':
        return const Color(0xFF3370FF);
      case 'Moonshot (Kimi)':
        return const Color(0xFF000000);
      case '智谱 GLM':
        return const Color(0xFF3366FF);
      case '零一万物':
        return const Color(0xFF0A0A0A);
      case '阶跃星辰':
        return const Color(0xFF5B5BF0);
      case '百度文心':
        return const Color(0xFF2932E1);
      case 'Custom':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF64748B);
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  Slash commands
// ═══════════════════════════════════════════════════════════

class SlashCommand {
  final String command;
  final String description;
  final IconData icon;
  /// If true, this command needs a sub-argument picked from a list
  final bool hasSubItems;

  const SlashCommand({
    required this.command,
    required this.description,
    required this.icon,
    this.hasSubItems = false,
  });

  static const all = [
    SlashCommand(
      command: '/switch',
      description: 'Switch AI provider',
      icon: Icons.swap_horiz_rounded,
      hasSubItems: true,
    ),
    SlashCommand(
      command: '/model',
      description: 'Change model for current provider',
      icon: Icons.model_training,
      hasSubItems: true,
    ),
    SlashCommand(
      command: '/mode',
      description: 'Switch mode (chat / agent / plan)',
      icon: Icons.tune,
      hasSubItems: true,
    ),
    SlashCommand(
      command: '/clear',
      description: 'Clear chat history',
      icon: Icons.delete_sweep,
    ),
    SlashCommand(
      command: '/providers',
      description: 'List configured providers',
      icon: Icons.list_alt,
    ),
  ];
}
