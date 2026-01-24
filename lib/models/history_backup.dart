/// 命令历史备份数据模型

class HistoryBackup {
  final int version;
  final DateTime createdAt;
  final String shellType;
  final int entryCount;
  final String? appVersion;
  final List<String> commands;

  HistoryBackup({
    this.version = 1,
    required this.createdAt,
    required this.shellType,
    required this.entryCount,
    this.appVersion,
    required this.commands,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'createdAt': createdAt.toIso8601String(),
        'shellType': shellType,
        'entryCount': entryCount,
        'appVersion': appVersion,
        'commands': commands,
      };

  factory HistoryBackup.fromJson(Map<String, dynamic> json) {
    return HistoryBackup(
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
      shellType: json['shellType'] as String? ?? 'bash',
      entryCount: json['entryCount'] as int? ?? 0,
      appVersion: json['appVersion'] as String?,
      commands: (json['commands'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
