class SSHHost {
  final String id;
  String alias;
  String host;
  int port;
  String username;
  String args;

  SSHHost({
    required this.id,
    this.alias = '',
    required this.host,
    this.port = 22,
    this.username = '',
    this.args = '',
  });

  String get displayName => alias.isNotEmpty ? alias : '$username@$host';

  String get command {
    final sb = StringBuffer('ssh');
    if (port != 22) {
      sb.write(' -p $port');
    }
    if (args.isNotEmpty) {
      sb.write(' $args');
    }
    if (username.isNotEmpty) {
      sb.write(' $username@$host');
    } else {
      sb.write(' $host');
    }
    return sb.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alias': alias,
      'host': host,
      'port': port,
      'username': username,
      'args': args,
    };
  }

  factory SSHHost.fromJson(Map<String, dynamic> json) {
    return SSHHost(
      id: json['id'],
      alias: json['alias'] ?? '',
      host: json['host'],
      port: json['port'] ?? 22,
      username: json['username'] ?? '',
      args: json['args'] ?? '',
    );
  }

  SSHHost copyWith({
    String? alias,
    String? host,
    int? port,
    String? username,
    String? args,
  }) {
    return SSHHost(
      id: id,
      alias: alias ?? this.alias,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      args: args ?? this.args,
    );
  }
}
