class Song {
  final String id;
  final String title;
  final String artist;
  final String imageUrl;
  final String audioUrl;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.audioUrl,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      // 👇 Ưu tiên lấy _id (của MongoDB), nếu không có thì lấy id, nếu không có nữa thì là rỗng
      id: (json['_id'] ?? json['id'] ?? "").toString(),
      title: json['title'] ?? "Unknown Title",
      artist: json['artist'] ?? "Unknown Artist",
      imageUrl: json['imageUrl'] ?? "https://via.placeholder.com/150",
      audioUrl: json['audioUrl'] ?? "",
    );
  }

  // Khi gửi lên Server, ta gửi kèm _id để Server biết đây là bài nào
  Map<String, dynamic> toJson() {
    return {
      '_id': id, // Quan trọng: Gửi đúng key _id
      'title': title,
      'artist': artist,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
    };
  }
}