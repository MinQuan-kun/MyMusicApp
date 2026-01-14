import 'song_model.dart';

class Playlist {
  final String id;
  final String name;
  final List<Song> songs;

  Playlist({required this.id, required this.name, required this.songs});

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      // 👇 SỬA ĐOẠN NÀY: Ưu tiên lấy _id, nếu không có thì lấy id, nếu không có nữa thì rỗng
      id: (json['_id'] ?? json['id'] ?? "").toString(), 
      name: json['name'] ?? "No Name",
      songs: (json['songs'] as List?)?.map((e) => Song.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'songs': songs.map((e) => e.toJson()).toList(),
    };
  }
}