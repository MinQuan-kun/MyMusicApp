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

  // Hàm này giúp biến đổi dữ liệu JSON từ Server thành dạng Song của Flutter
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['_id'] ?? '', // MongoDB dùng _id thay vì id
      title: json['title'] ?? 'Không tên',
      artist: json['artist'] ?? 'Unknown',
      imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/150',
      audioUrl: json['audioUrl'] ?? '',
    );
  }
}