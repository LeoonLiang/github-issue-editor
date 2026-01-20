/// 应用配置数据模型
class AppConfig {
  final GitHubConfig github;
  final List<OSSConfig> ossList; // 支持多个OSS配置
  final String displayDomain; // 全局图片回显域名

  AppConfig({
    required this.github,
    required this.ossList,
    this.displayDomain = '',
  });

  factory AppConfig.empty() {
    return AppConfig(
      github: GitHubConfig.empty(),
      ossList: [],
      displayDomain: '',
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      github: GitHubConfig.fromJson(json['github'] ?? {}),
      ossList: (json['ossList'] as List<dynamic>?)
              ?.map((e) => OSSConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      displayDomain: json['displayDomain'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'github': github.toJson(),
      'ossList': ossList.map((e) => e.toJson()).toList(),
      'displayDomain': displayDomain,
    };
  }

  AppConfig copyWith({
    GitHubConfig? github,
    List<OSSConfig>? ossList,
    String? displayDomain,
  }) {
    return AppConfig(
      github: github ?? this.github,
      ossList: ossList ?? this.ossList,
      displayDomain: displayDomain ?? this.displayDomain,
    );
  }

  bool get isConfigured => github.isValid && ossList.any((oss) => oss.enabled);

  /// 获取所有启用的OSS配置
  List<OSSConfig> get enabledOSSList => ossList.where((oss) => oss.enabled).toList();
}

/// GitHub 配置
class GitHubConfig {
  final String owner;
  final String repo;
  final String token;

  GitHubConfig({
    required this.owner,
    required this.repo,
    required this.token,
  });

  factory GitHubConfig.empty() {
    return GitHubConfig(
      owner: '',
      repo: '',
      token: '',
    );
  }

  factory GitHubConfig.fromJson(Map<String, dynamic> json) {
    return GitHubConfig(
      owner: json['owner'] ?? '',
      repo: json['repo'] ?? '',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'owner': owner,
      'repo': repo,
      'token': token,
    };
  }

  GitHubConfig copyWith({
    String? owner,
    String? repo,
    String? token,
  }) {
    return GitHubConfig(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      token: token ?? this.token,
    );
  }

  bool get isValid => owner.isNotEmpty && repo.isNotEmpty && token.isNotEmpty;
}

/// OSS 配置（S3兼容）
class OSSConfig {
  final String id; // 唯一标识
  final String name; // 配置名称（用户自定义）
  final String endpoint; // S3 endpoint
  final String region; // S3 region
  final String accessKeyId; // Access Key ID
  final String secretAccessKey; // Secret Access Key
  final String bucket; // Bucket名称
  final String publicDomain; // 公网访问域名（可选）
  final bool enabled; // 是否启用

  OSSConfig({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.region,
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.bucket,
    this.publicDomain = '',
    this.enabled = true,
  });

  factory OSSConfig.empty() {
    return OSSConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      endpoint: '',
      region: '',
      accessKeyId: '',
      secretAccessKey: '',
      bucket: '',
      publicDomain: '',
      enabled: true,
    );
  }

  factory OSSConfig.fromJson(Map<String, dynamic> json) {
    return OSSConfig(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      endpoint: json['endpoint'] ?? '',
      region: json['region'] ?? '',
      accessKeyId: json['accessKeyId'] ?? '',
      secretAccessKey: json['secretAccessKey'] ?? '',
      bucket: json['bucket'] ?? '',
      publicDomain: json['publicDomain'] ?? '',
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'endpoint': endpoint,
      'region': region,
      'accessKeyId': accessKeyId,
      'secretAccessKey': secretAccessKey,
      'bucket': bucket,
      'publicDomain': publicDomain,
      'enabled': enabled,
    };
  }

  OSSConfig copyWith({
    String? id,
    String? name,
    String? endpoint,
    String? region,
    String? accessKeyId,
    String? secretAccessKey,
    String? bucket,
    String? publicDomain,
    bool? enabled,
  }) {
    return OSSConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      secretAccessKey: secretAccessKey ?? this.secretAccessKey,
      bucket: bucket ?? this.bucket,
      publicDomain: publicDomain ?? this.publicDomain,
      enabled: enabled ?? this.enabled,
    );
  }

  bool get isValid {
    return name.isNotEmpty &&
        endpoint.isNotEmpty &&
        region.isNotEmpty &&
        accessKeyId.isNotEmpty &&
        secretAccessKey.isNotEmpty &&
        bucket.isNotEmpty;
  }
}
