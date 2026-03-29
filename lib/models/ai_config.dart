import 'package:flutter/material.dart';

/// AI 配置模型
/// 存储用户的 AI API 配置信息
class AiConfig {
  final String apiKey;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final bool enabled;
  final bool autoErrorDiagnosis;
  final bool showInlineBar;
  final String systemPrompt;
  final List<String>
      commandRules; // e.g. ["allow:ls:*", "ask:git push", "deny:rm -rf /*"]

  const AiConfig({
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini',
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.enabled = false,
    this.autoErrorDiagnosis = false,
    this.showInlineBar = true,
    this.systemPrompt = defaultSystemPrompt,
    this.commandRules = const [],
  });

  bool get isConfigured => apiKey.isNotEmpty && baseUrl.isNotEmpty;

  static const defaultSystemPrompt =
      'You are an AI assistant integrated into a terminal emulator. '
      'You help users with shell commands, error diagnosis, and general terminal tasks. '
      'When generating commands, output ONLY the command with no explanation unless asked. '
      'The current shell is {shell_type} and the working directory is {cwd}.';

  /// 替换系统提示词中的模板变量
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
    String? apiKey,
    String? baseUrl,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? enabled,
    bool? autoErrorDiagnosis,
    bool? showInlineBar,
    String? systemPrompt,
    List<String>? commandRules,
  }) {
    return AiConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
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
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'model': model,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'enabled': enabled,
        'autoErrorDiagnosis': autoErrorDiagnosis,
        'showInlineBar': showInlineBar,
        'systemPrompt': systemPrompt,
        'commandRules': commandRules,
      };

  factory AiConfig.fromJson(Map<String, dynamic> json) => AiConfig(
        apiKey: json['apiKey'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
        model: json['model'] as String? ?? 'gpt-4o-mini',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        maxTokens: json['maxTokens'] as int? ?? 2048,
        enabled: json['enabled'] as bool? ?? false,
        autoErrorDiagnosis: json['autoErrorDiagnosis'] as bool? ?? false,
        showInlineBar: json['showInlineBar'] as bool? ?? true,
        systemPrompt: json['systemPrompt'] as String? ?? defaultSystemPrompt,
        commandRules:
            (json['commandRules'] as List<dynamic>?)?.cast<String>() ??
                const [],
      );

  /// 常见供应商预设
  /// 国际
  static const internationalPresets = <String, AiPreset>{
    'openai': AiPreset(
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4o-mini',
    ),
    'anthropic': AiPreset(
      name: 'Anthropic',
      baseUrl: 'https://api.anthropic.com/v1',
      defaultModel: 'claude-sonnet-4-20250514',
    ),
    'groq': AiPreset(
      name: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'llama-3.3-70b-versatile',
    ),
    'ollama': AiPreset(
      name: 'Ollama',
      baseUrl: 'http://localhost:11434/v1',
      defaultModel: 'qwen2.5-coder:7b',
    ),
    'mistral': AiPreset(
      name: 'Mistral AI',
      baseUrl: 'https://api.mistral.ai/v1',
      defaultModel: 'mistral-small-latest',
    ),
    'cohere': AiPreset(
      name: 'Cohere',
      baseUrl: 'https://api.cohere.ai/v1',
      defaultModel: 'command-r-plus',
    ),
  };

  /// 国内
  static const chinaPresets = <String, AiPreset>{
    'deepseek': AiPreset(
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      defaultModel: 'deepseek-chat',
    ),
    'minimax': AiPreset(
      name: 'MiniMax',
      baseUrl: 'https://api.minimaxi.com/anthropic/v1',
      defaultModel: 'MiniMax-M2.7',
    ),
    'minimax_openai': AiPreset(
      name: 'MiniMax (OpenAI)',
      baseUrl: 'https://api.minimaxi.com/v1',
      defaultModel: 'MiniMax-Text-01',
    ),
    'siliconflow': AiPreset(
      name: '硅基流动',
      baseUrl: 'https://api.siliconflow.cn/v1',
      defaultModel: 'deepseek-ai/DeepSeek-V3',
    ),
    'qwen': AiPreset(
      name: '通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      defaultModel: 'qwen-plus',
    ),
    'volcengine': AiPreset(
      name: '火山引擎',
      baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      defaultModel: 'doubao-pro-32k',
    ),
    'moonshot': AiPreset(
      name: 'Moonshot (Kimi)',
      baseUrl: 'https://api.moonshot.cn/v1',
      defaultModel: 'moonshot-v1-8k',
    ),
    'zhipu': AiPreset(
      name: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      defaultModel: 'glm-4-flash',
    ),
    'yi': AiPreset(
      name: '零一万物',
      baseUrl: 'https://api.lingyiwanwu.com/v1',
      defaultModel: 'yi-large',
    ),
    'stepfun': AiPreset(
      name: '阶跃星辰',
      baseUrl: 'https://api.stepfun.com/v1',
      defaultModel: 'step-1v-8k',
    ),
    'baidu': AiPreset(
      name: '百度文心',
      baseUrl: 'https://qianfan.baidubce.com/v2',
      defaultModel: 'ernie-4.0-8k-latest',
    ),
  };

  /// 自定义供应商预设（占位）
  static const customPreset = AiPreset(
    name: '自定义',
    baseUrl: '',
    defaultModel: '',
    isCustom: true,
  );

  /// 所有预设（国际 + 国内）
  static Map<String, AiPreset> get allPresets => {
        ...internationalPresets,
        ...chinaPresets,
        'custom': customPreset,
      };
}

/// AI 供应商预设
class AiPreset {
  final String name;
  final String baseUrl;
  final String defaultModel;
  final String? region;
  final bool isCustom;

  const AiPreset({
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.region,
    this.isCustom = false,
  });

  /// 获取预设对应的品牌颜色
  Color get color {
    switch (name) {
      case 'OpenAI':
        return const Color(0xFF10A37F);
      case 'Anthropic':
        return const Color(0xFFEF5B5B);
      case 'DeepSeek':
        return const Color(0xFF6767F2);
      case 'MiniMax':
        return const Color(0xFF00D8C6);
      case 'MiniMax (OpenAI)':
      case 'Groq':
        return const Color(0xFFE53E3E);
      case 'Ollama':
        return const Color(0xFF1A1A1A);
      case 'Mistral AI':
        return const Color(0xFFE84A4A);
      case 'Cohere':
        return const Color(0xFF2D68C4);
      case '硅基流动':
        return const Color(0xFF6366F1);
      case '通义千问':
        return const Color(0xFFFF6B35);
      case '火山引擎':
        return const Color(0xFFFF4D4D);
      case 'Moonshot (Kimi)':
        return const Color(0xFF8B5CF6);
      case '智谱 GLM':
        return const Color(0xFF00C7B7);
      case '零一万物':
        return const Color(0xFFF59E0B);
      case '阶跃星辰':
        return const Color(0xFF3B82F6);
      case '百度文心':
        return const Color(0xFF2932E1);
      case '自定义':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF64748B);
    }
  }
}
