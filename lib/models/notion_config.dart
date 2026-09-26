class NotionConfig {
  final String token;
  final String databaseId;
  final String proxyUrl;

  const NotionConfig({
    required this.token,
    required this.databaseId,
    this.proxyUrl = '',
  });

  bool get isValid => token.isNotEmpty && databaseId.isNotEmpty;
  bool get hasProxy => proxyUrl.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'token': token,
    'databaseId': databaseId,
    'proxyUrl': proxyUrl,
  };

  factory NotionConfig.fromMap(Map<String, dynamic> map) => NotionConfig(
    token: map['token'] as String? ?? '',
    databaseId: map['databaseId'] as String? ?? '',
    proxyUrl: map['proxyUrl'] as String? ?? '',
  );
}
