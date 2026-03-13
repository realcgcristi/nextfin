import '../../core/compatibility/server_capabilities.dart';

class ServerAccount {
  const ServerAccount({
    required this.id,
    required this.serverUrl,
    required this.serverName,
    required this.userId,
    required this.username,
    required this.accessToken,
    required this.capabilities,
  });

  final String id;
  final String serverUrl;
  final String serverName;
  final String userId;
  final String username;
  final String accessToken;
  final ServerCapabilities capabilities;

  ServerAccount copyWith({
    String? id,
    String? serverUrl,
    String? serverName,
    String? userId,
    String? username,
    String? accessToken,
    ServerCapabilities? capabilities,
  }) {
    return ServerAccount(
      id: id ?? this.id,
      serverUrl: serverUrl ?? this.serverUrl,
      serverName: serverName ?? this.serverName,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      accessToken: accessToken ?? this.accessToken,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'serverUrl': serverUrl,
    'serverName': serverName,
    'userId': userId,
    'username': username,
    'accessToken': accessToken,
    'capabilities': capabilities.toJson(),
  };

  factory ServerAccount.fromJson(Map<String, dynamic> json) => ServerAccount(
    id: json['id']?.toString() ?? '',
    serverUrl: json['serverUrl']?.toString() ?? '',
    serverName: json['serverName']?.toString() ?? 'Jellyfin',
    userId: json['userId']?.toString() ?? '',
    username: json['username']?.toString() ?? '',
    accessToken: json['accessToken']?.toString() ?? '',
    capabilities: ServerCapabilities.fromJson(
      (json['capabilities'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    ),
  );
}
