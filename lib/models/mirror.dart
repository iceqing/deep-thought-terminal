/// Termux 镜像源模型
class TermuxMirror {
  final String id;
  final String name;
  final String url;
  final String region;
  final String description;

  const TermuxMirror({
    required this.id,
    required this.name,
    required this.url,
    required this.region,
    this.description = '',
  });

  /// 生成 sources.list 内容
  String get sourcesListContent =>
      AvailableMirrors.sourcesListContentForUrl(url);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TermuxMirror &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 可用的 Termux 镜像源列表
class AvailableMirrors {
  AvailableMirrors._();

  static String sourcesListContentForUrl(String url) {
    return 'deb $url stable main\n';
  }

  /// 默认镜像 (CloudFlare CDN)
  static const defaultMirror = TermuxMirror(
    id: 'default',
    name: 'Default (CloudFlare)',
    url: 'https://packages-cf.termux.dev/apt/termux-main',
    region: 'Global',
    description: 'Official Termux repository with CloudFlare CDN',
  );

  /// 所有可用镜像
  static const List<TermuxMirror> all = [
    defaultMirror,

    // 官方镜像
    TermuxMirror(
      id: 'packages',
      name: 'Termux Packages',
      url: 'https://packages.termux.dev/apt/termux-main',
      region: 'Global',
      description: 'Official Termux packages server',
    ),

    // 中国镜像
    TermuxMirror(
      id: 'tuna',
      name: 'TUNA (清华大学)',
      url: 'https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main',
      region: 'China',
      description: 'Tsinghua University Open Source Mirror',
    ),
    TermuxMirror(
      id: 'bfsu',
      name: 'BFSU (北京外国语)',
      url: 'https://mirrors.bfsu.edu.cn/termux/apt/termux-main',
      region: 'China',
      description: 'Beijing Foreign Studies University Mirror',
    ),
    TermuxMirror(
      id: 'ustc',
      name: 'USTC (中科大)',
      url: 'https://mirrors.ustc.edu.cn/termux/apt/termux-main',
      region: 'China',
      description: 'University of Science and Technology of China',
    ),
    TermuxMirror(
      id: 'aliyun',
      name: 'Aliyun (阿里云)',
      url: 'https://mirrors.aliyun.com/termux/apt/termux-main',
      region: 'China',
      description: 'Alibaba Cloud Mirror',
    ),
    TermuxMirror(
      id: 'nju',
      name: 'NJU (南京大学)',
      url: 'https://mirror.nju.edu.cn/termux/apt/termux-main',
      region: 'China',
      description: 'Nanjing University Mirror',
    ),

    // 欧洲镜像
    TermuxMirror(
      id: 'mwt',
      name: 'MWT Mirror',
      url: 'https://mirror.mwt.me/termux/main',
      region: 'Europe',
      description: 'European mirror',
    ),
    TermuxMirror(
      id: 'sahilister',
      name: 'Sahilister',
      url: 'https://termux.sahilister.in/apt/termux-main',
      region: 'Europe/India',
      description: 'Community mirror',
    ),

    // 北美镜像
    TermuxMirror(
      id: 'librehat',
      name: 'Librehat',
      url: 'https://termux.librehat.com/apt/termux-main',
      region: 'North America',
      description: 'US-based community mirror',
    ),
    TermuxMirror(
      id: 'astra',
      name: 'Astra ISP',
      url: 'https://termux.astra.in.ua/apt/termux-main',
      region: 'Europe',
      description: 'Ukraine-based mirror',
    ),
  ];

  /// 按地区分组的镜像
  static Map<String, List<TermuxMirror>> get byRegion {
    final map = <String, List<TermuxMirror>>{};
    for (final mirror in all) {
      map.putIfAbsent(mirror.region, () => []).add(mirror);
    }
    return map;
  }

  /// 根据 ID 获取镜像
  static TermuxMirror? getById(String id) {
    try {
      return all.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 根据 URL 获取镜像
  static TermuxMirror? getByUrl(String url) {
    try {
      return all.firstWhere((m) => m.url == url);
    } catch (_) {
      return null;
    }
  }
}
