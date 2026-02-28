/// SSH config 文件中的一个 Host 配置块
class SshConfigEntry {
  String hostPattern;

  // 保活
  int? serverAliveInterval;
  int? serverAliveCountMax;

  // 连接
  int? connectTimeout;
  int? connectionAttempts;
  int? port;
  String? user;

  // 认证
  String? identityFile;
  String? preferredAuthentications;

  // 安全
  String? strictHostKeyChecking;

  // 其他
  String? compression;
  String? forwardAgent;
  String? tcpKeepAlive;

  // 未识别的指令（round-trip 保留）
  Map<String, String> rawDirectives;

  // Host 块前的注释行
  List<String> precedingComments;

  SshConfigEntry({
    required this.hostPattern,
    this.serverAliveInterval,
    this.serverAliveCountMax,
    this.connectTimeout,
    this.connectionAttempts,
    this.port,
    this.user,
    this.identityFile,
    this.preferredAuthentications,
    this.strictHostKeyChecking,
    this.compression,
    this.forwardAgent,
    this.tcpKeepAlive,
    Map<String, String>? rawDirectives,
    List<String>? precedingComments,
  })  : rawDirectives = rawDirectives ?? {},
        precedingComments = precedingComments ?? [];

  /// 是否为全局配置块 (Host *)
  bool get isGlobal => hostPattern.trim() == '*';

  /// 显示名称
  String get displayName => isGlobal ? 'Global (*)' : hostPattern;

  /// 从指令名（小写）设置对应字段值
  void setDirective(String key, String value) {
    switch (key.toLowerCase()) {
      case 'serveraliveinterval':
        serverAliveInterval = int.tryParse(value);
      case 'serveralivecountmax':
        serverAliveCountMax = int.tryParse(value);
      case 'connecttimeout':
        connectTimeout = int.tryParse(value);
      case 'connectionattempts':
        connectionAttempts = int.tryParse(value);
      case 'port':
        port = int.tryParse(value);
      case 'user':
        user = value;
      case 'identityfile':
        identityFile = value;
      case 'preferredauthentications':
        preferredAuthentications = value;
      case 'stricthostkeychecking':
        strictHostKeyChecking = value;
      case 'compression':
        compression = value;
      case 'forwardagent':
        forwardAgent = value;
      case 'tcpkeepalive':
        tcpKeepAlive = value;
      default:
        rawDirectives[key] = value;
    }
  }

  /// 将所有已设置的指令序列化为 key-value 列表
  List<MapEntry<String, String>> toDirectives() {
    final directives = <MapEntry<String, String>>[];

    void add(String key, dynamic value) {
      if (value != null) {
        directives.add(MapEntry(key, value.toString()));
      }
    }

    add('ServerAliveInterval', serverAliveInterval);
    add('ServerAliveCountMax', serverAliveCountMax);
    add('ConnectTimeout', connectTimeout);
    add('ConnectionAttempts', connectionAttempts);
    add('Port', port);
    add('User', user);
    add('IdentityFile', identityFile);
    add('PreferredAuthentications', preferredAuthentications);
    add('StrictHostKeyChecking', strictHostKeyChecking);
    add('Compression', compression);
    add('ForwardAgent', forwardAgent);
    add('TCPKeepAlive', tcpKeepAlive);

    // 未识别的指令
    for (final entry in rawDirectives.entries) {
      directives.add(entry);
    }

    return directives;
  }
}
