/// Perfil social com listas públicas.
class SocialUser {
  const SocialUser({required this.username, required this.playlistCount});

  final String username;
  final int playlistCount;

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    return SocialUser(
      username: json['username'] as String? ?? '',
      playlistCount: (json['playlistCount'] as num?)?.toInt() ?? 0,
    );
  }
}
