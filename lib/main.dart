import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'models/song_model.dart';
import 'screens/player_screen.dart';
import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Spotify',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Biến lưu danh sách bài hát
  List<Song> songs = [];
  bool isLoading = true;

  // Trình phát nhạc
  final AudioPlayer _player = AudioPlayer();
  Song? currentSong; // Bài đang phát
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    fetchSongs(); // Gọi API ngay khi mở màn hình

    // Lắng nghe trạng thái phát nhạc để đổi icon Play/Pause
    _player.playerStateStream.listen((state) {
      setState(() {
        isPlaying = state.playing;
      });
    });
  }

  // Hàm gọi lên Server lấy dữ liệu
  Future<void> fetchSongs() async {
    // QUAN TRỌNG: Nếu dùng máy ảo Android thì phải là 10.0.2.2
    // Nếu dùng máy thật thì phải thay bằng IP máy tính (VD: 192.168.1.x)
    final url = Uri.parse('http://10.0.2.2:3000/songs');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          songs = data.map((json) => Song.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        print("Lỗi server: ${response.statusCode}");
      }
    } catch (e) {
      print("Lỗi kết nối: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Hàm phát nhạc
  Future<void> playMusic(Song song) async {
    try {
      // Nếu chọn bài mới thì load nhạc
      if (currentSong?.id != song.id) {
        setState(() {
          currentSong = song;
        });
        await _player.setUrl(song.audioUrl);
        _player.play();
      }
      // Nếu bài cũ đang pause thì play lại
      else if (!isPlaying) {
        _player.play();
      }

      // --- MỞ MÀN HÌNH PLAYER MỚI ---
      // Dùng Navigator.push để mở trang mới đè lên trang cũ
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
                song: song,
                player: _player // Truyền cái máy phát nhạc sang trang kia
            ),
          ),
        );
      }

    } catch (e) {
      print("Lỗi: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kho Nhạc Của Tôi")),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Xoay xoay khi đang tải
          : songs.isEmpty
          ? const Center(child: Text("Chưa có bài hát nào trên Server"))
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final isActive = currentSong?.id == song.id;

                return ListTile(
                  leading: Image.network(
                    song.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.music_note),
                  ),
                  title: Text(
                    song.title,
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(song.artist),
                  trailing: Icon(
                    isActive && isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: isActive ? Colors.green : Colors.white,
                  ),
                  onTap: () => playMusic(song),
                );
              },
            ),
      // Thanh điều khiển mini ở dưới cùng
      bottomNavigationBar: currentSong != null
          ? Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(10),
              child: SafeArea(
                child: Row(
                  children: [
                    // Ảnh bìa
                    ClipRRect(
                      // Bo tròn ảnh tí cho đẹp
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        currentSong!.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.music_note, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Tên bài hát + Ca sĩ (Dùng Expanded để chiếm hết chỗ trống còn lại)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong!.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1, // Chỉ hiện 1 dòng
                            overflow: TextOverflow
                                .ellipsis, // Dài quá thì hiện dấu ...
                          ),
                          Text(
                            currentSong!.artist,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Nút Play/Pause
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 35,
                      ),
                      onPressed: () {
                        if (currentSong != null) playMusic(currentSong!);
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
