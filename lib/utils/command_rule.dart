/// 命令权限规则匹配器
/// 参考 Claude Code 的权限规则系统: Tool(specifier) 格式
///
/// 规则格式: commandName 或 commandName:pattern
///   ls          → 匹配所有以 "ls " 开头的命令
///   ls:*        → 同上，匹配 ls 开头的任意参数
///   npm run:*   → 匹配 "npm run xxx" 任意命令
///   docker:*    → 匹配所有 docker 命令
///
/// 优先级: deny → ask → allow (第一个匹配生效)
enum CommandRuleAction { deny, ask, allow }

/// 命令权限规则
class CommandRule {
  final String command;
  final CommandRuleAction action;

  const CommandRule({
    required this.command,
    required this.action,
  });

  /// 解析规则字符串 "ls:*" -> CommandRule(rule: "ls:*", action: ask)
  /// "allow:ls:*" -> CommandRule(rule: "ls:*", action: allow)
  static CommandRule? parse(String raw) {
    raw = raw.trim();
    if (raw.isEmpty || raw.startsWith('#')) return null;

    CommandRuleAction action;
    if (raw.startsWith('allow:')) {
      action = CommandRuleAction.allow;
      raw = raw.substring(6);
    } else if (raw.startsWith('ask:')) {
      action = CommandRuleAction.ask;
      raw = raw.substring(4);
    } else if (raw.startsWith('deny:')) {
      action = CommandRuleAction.deny;
      raw = raw.substring(5);
    } else {
      action = CommandRuleAction.ask;
    }

    raw = raw.trim();
    if (raw.isEmpty) return null;

    return CommandRule(command: raw, action: action);
  }

  /// 判断命令是否匹配此规则
  bool matches(String command) {
    return _matchRule(this.command, command);
  }

  @override
  String toString() {
    final prefix = switch (action) {
      CommandRuleAction.allow => 'allow:',
      CommandRuleAction.ask => 'ask:',
      CommandRuleAction.deny => 'deny:',
    };
    return '$prefix$command';
  }
}

/// 命令权限规则匹配引擎
class CommandRuleMatcher {
  final List<CommandRule> _rules;

  CommandRuleMatcher(List<String> ruleStrings) : _rules = [] {
    for (final s in ruleStrings) {
      final rule = CommandRule.parse(s);
      if (rule != null) _rules.add(rule);
    }
  }

  /// 检查命令的权限动作
  /// 规则顺序: deny → ask → allow（第一个匹配生效）
  CommandRuleAction check(String command) {
    for (final rule in _rules) {
      if (rule.action == CommandRuleAction.deny && rule.matches(command)) {
        return CommandRuleAction.deny;
      }
    }
    for (final rule in _rules) {
      if (rule.action == CommandRuleAction.ask && rule.matches(command)) {
        return CommandRuleAction.ask;
      }
    }
    for (final rule in _rules) {
      if (rule.action == CommandRuleAction.allow && rule.matches(command)) {
        return CommandRuleAction.allow;
      }
    }
    // 默认: 询问
    return CommandRuleAction.ask;
  }

  /// 列出所有规则
  List<CommandRule> get rules => List.unmodifiable(_rules);
}

/// 内部匹配逻辑
bool _matchRule(String rule, String command) {
  command = command.trim();
  rule = rule.trim();

  // 精确匹配
  if (rule == command) return true;

  // 带 * 通配符的匹配
  if (rule.endsWith(':*')) {
    final prefix = rule.substring(0, rule.length - 2);
    // "ls:*" 匹配 "ls " 开头的命令
    return command.startsWith('$prefix ') ||
        command.startsWith('$prefix\t') ||
        command == prefix;
  }

  // 前缀匹配: "npm run" 匹配 "npm run build"
  if (command.startsWith(rule)) {
    // 确保是完整命令开头（不是子串误匹配）
    if (command.length == rule.length) return true;
    final next = command[rule.length];
    return next == ' ' || next == '\t' || next == '-';
  }

  return false;
}
