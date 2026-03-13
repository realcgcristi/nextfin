class JellyfinUser {
  const JellyfinUser({
    required this.id,
    required this.name,
    required this.primaryImageTag,
  });

  final String id;
  final String name;
  final String? primaryImageTag;

  factory JellyfinUser.fromJson(Map<String, dynamic> json) => JellyfinUser(
    id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
    name: json['Name']?.toString() ?? json['name']?.toString() ?? 'User',
    primaryImageTag: json['PrimaryImageTag']?.toString(),
  );
}
