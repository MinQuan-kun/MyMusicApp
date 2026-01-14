import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart'; // Đảm bảo đã có file model này
import 'player_screen.dart';
import 'playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color mikuColor = const Color(0xFF39C5BB);
  final Color bgLight = const Color(0xFFF5F7FA);
  final Color textDark = const Color(0xFF2D3436);
  // IP Server (Dùng 10.0.2.2 cho máy ảo Android)
  final String baseUrl = 'http://10.0.2.2:3000';

  List<Song> songs = [];
  List<Song> filteredSongs = [];
  // 👇 Đổi từ Map sang List<Playlist> để hứng dữ liệu Server
  List<Playlist> playlists = [];

  bool isLoading = true;
  final AudioPlayer _player = AudioPlayer();
  Song? currentSong;
  bool isPlaying = false;
  final TextEditingController _searchController = TextEditingController();
  ConcatenatingAudioSource? _currentPlaylistSource;

  @override
  void initState() {
    super.initState();
    // Gọi API lấy dữ liệu khi mở app
    fetchData();

    _player.currentIndexStream.listen((index) {
      if (index != null && _currentPlaylistSource != null) {
        final sequence = _player.sequenceState?.sequence;
        if (sequence != null && index < sequence.length) {
          final tag = sequence[index].tag as MediaItem;
          if (mounted) {
            setState(() {
              currentSong = Song(id: tag.id, title: tag.title, artist: tag.artist ?? "", imageUrl: tag.artUri.toString(), audioUrl: "");
            });
          }
        }
      }
    });

    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => isPlaying = state.playing);
    });
  }

  // --- CÁC HÀM GỌI API SERVER ---

  Future<void> fetchData() async {
    await Future.wait([fetchSongs(), fetchPlaylists()]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchSongs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/songs'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          songs = data.map((json) => Song.fromJson(json)).toList();
          filteredSongs = songs;
        });
      }
    } catch (e) { print("Lỗi tải nhạc: $e"); }
  }

  // 👇 Hàm lấy Playlist từ Server
  Future<void> fetchPlaylists() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/playlists'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          playlists = data.map((json) => Playlist.fromJson(json)).toList();
        });
      }
    } catch (e) { print("Lỗi tải playlist: $e"); }
  }

  // 👇 Hàm tạo Playlist mới lên Server
  Future<void> createPlaylistOnServer(String name) async {
    try {
      final newPlaylist = {'name': name, 'songs': []};
      final response = await http.post(
        Uri.parse('$baseUrl/playlists'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newPlaylist),
      );
      if (response.statusCode == 201) {
        fetchPlaylists(); // Load lại danh sách ngay lập tức
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tạo playlist thành công!")));
      }
    } catch (e) { print("Lỗi tạo playlist: $e"); }
  }

  // 👇 Hàm thêm nhạc vào Playlist
  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Ẩn thông báo cũ nếu có
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating, // Nổi lên trên cho đẹp
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // 👇 HÀM THÊM NHẠC ĐÃ CÓ CHECK LỖI KỸ CÀNG
  Future<void> addSongToPlaylist(Song song, Playlist playlistArg) async {
    // 👇 LOGIC FIX LỖI: Tìm Playlist mới nhất trong danh sách đã tải về từ Server
    // Vì playlistArg có thể là dữ liệu cũ (lúc chưa xóa bài)
    Playlist targetPlaylist;
    try {
      targetPlaylist = playlists.firstWhere((p) => p.id == playlistArg.id);
    } catch (e) {
      // Nếu không tìm thấy (trường hợp hiếm), dùng tạm cái cũ
      targetPlaylist = playlistArg;
    }

    // 👇 Kiểm tra trùng trên Playlist MỚI NHẤT
    if (targetPlaylist.songs.any((s) => s.id == song.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bài hát đã có trong playlist!")));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/playlists/${playlistArg.id}/add-song'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(song.toJson()),
      );

      if (response.statusCode == 200) {
        // 👇 QUAN TRỌNG: Gọi fetchPlaylists() xong phải đợi nó chạy xong
        await fetchPlaylists();

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Đã thêm vào ${playlistArg.name}"), backgroundColor: mikuColor)
        );
      } else {
        print("Lỗi Server: ${response.body}");
      }
    } catch (e) {
      print("Lỗi kết nối: $e");
    }
  }

  // --- UI ---

  void _runFilter(String keyword) {
    List<Song> results = keyword.isEmpty ? songs : songs.where((song) => song.title.toLowerCase().contains(keyword.toLowerCase())).toList();
    setState(() => filteredSongs = results);
  }

  void _showCreatePlaylistDialog() {
    String newName = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tạo Playlist Mới"),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: "Nhập tên playlist...", focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: mikuColor))),
          onChanged: (value) => newName = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: mikuColor),
            onPressed: () {
              if (newName.isNotEmpty) createPlaylistOnServer(newName); // Gọi hàm tạo Server
              Navigator.pop(context);
            },
            child: const Text("Tạo", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Mở màn hình chi tiết Playlist
  void _openPlaylistDetails(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistScreen(
          playlist: playlist,
          player: _player,
          baseUrl: baseUrl,
          onUpdate: fetchPlaylists, // Callback cập nhật
        ),
      ),
    ).then((_) {
      fetchPlaylists();
    });
  }

  Future<void> playMusic(int index) async {
    try {
      // 1. Tạo danh sách phát
      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: filteredSongs.map((song) {
          // Kiểm tra URL an toàn
          if (song.audioUrl.isEmpty || !song.audioUrl.startsWith('http')) {
             print("❌ Bỏ qua bài lỗi URL: ${song.title}");
          }
          
          return AudioSource.uri(
            Uri.parse(song.audioUrl), 
            tag: MediaItem(
              id: song.id, 
              album: "Tất Cả Bài Hát", 
              title: song.title, 
              artist: song.artist, 
              artUri: Uri.parse(song.imageUrl),
            ),
          );
        }).toList(),
      );

      // 👇 CÁC DÒNG QUAN TRỌNG BỊ THIẾU 👇
      
      // 2. Nạp danh sách vào Player
      await _player.setAudioSource(playlist, initialIndex: index);
      _currentPlaylistSource = playlist; // Lưu lại nguồn phát hiện tại
      
      // 3. Cập nhật trạng thái bài hát hiện tại ngay lập tức
      setState(() {
        currentSong = filteredSongs[index];
        isPlaying = true;
      });

      // 4. Bắt đầu phát
      _player.play();

      // 5. Mở màn hình PlayerScreen
      _openPlayerScreen();

    } catch (e) { 
      print("Lỗi Play: $e"); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi phát nhạc: $e")));
    }
  }

  void _openPlayerScreen() {
    if (currentSong == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PlayerScreen(
          player: _player,
          playlists: playlists, // Truyền danh sách Server sang
          onAddToPlaylist: addSongToPlaylist,
        ),
        transitionsBuilder: (_, a, __, c) => SlideTransition(position: a.drive(Tween(begin: const Offset(0, 1), end: Offset.zero).chain(CurveTween(curve: Curves.ease))), child: c),
      ),
    );
  }

  @override
  void dispose() { _player.dispose(); _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Xin chào,", style: TextStyle(color: Colors.grey[500])), Text("Minh Music 🎧", style: TextStyle(color: textDark, fontSize: 24, fontWeight: FontWeight.bold))]),
                  CircleAvatar(backgroundColor: mikuColor.withOpacity(0.1), child: Icon(Icons.person, color: mikuColor))
                ]),
                const SizedBox(height: 20),
                Container(decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(15)), child: TextField(controller: _searchController, onChanged: _runFilter, decoration: InputDecoration(hintText: "Tìm kiếm...", prefixIcon: Icon(Icons.search, color: mikuColor), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 15)))),
              ]),
            ),
            // PLAYLIST LIST UI
            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Playlist", style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.bold)), GestureDetector(onTap: _showCreatePlaylistDialog, child: Text("+ Tạo mới", style: TextStyle(color: mikuColor, fontWeight: FontWeight.bold)))])),
            SizedBox(
              height: 120,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return GestureDetector(
                    onTap: () => _openPlaylistDetails(playlist),
                    child: Container(
                      width: 140, margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [mikuColor, mikuColor.withOpacity(0.6)]), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: mikuColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                      child: Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [const Icon(Icons.library_music, color: Colors.white, size: 30), const Spacer(), Text(playlist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), Text("${playlist.songs.length} bài hát", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12))])),
                    ),
                  );
                },
              ),
            ),
            // SONG LIST UI
            Expanded(
              child: isLoading ? Center(child: CircularProgressIndicator(color: mikuColor)) : ListView.builder(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100), itemCount: filteredSongs.length,
                itemBuilder: (context, index) {
                  final song = filteredSongs[index];
                  final isActive = currentSong?.id == song.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: isActive ? Border.all(color: mikuColor) : null),
                    child: ListTile(
                      leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(song.imageUrl, width: 55, height: 55, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[300], child: const Icon(Icons.music_note)))),
                      title: Text(song.title, style: TextStyle(color: isActive ? mikuColor : textDark, fontWeight: FontWeight.bold)),
                      subtitle: Text(song.artist),
                      trailing: isActive && isPlaying ? Icon(Icons.graphic_eq, color: mikuColor) : const Icon(Icons.play_circle_outline, color: Colors.grey),
                      onTap: () => playMusic(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: currentSong != null ? GestureDetector(onTap: _openPlayerScreen, child: Container(margin: const EdgeInsets.all(15), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: mikuColor.withOpacity(0.2), blurRadius: 15)]), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(50), child: Image.network(currentSong!.imageUrl, width: 45, height: 45, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const SizedBox())), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(currentSong!.title, style: TextStyle(color: textDark, fontWeight: FontWeight.bold), maxLines: 1), Text(currentSong!.artist, style: const TextStyle(color: Colors.grey, fontSize: 11))])), IconButton(icon: const Icon(Icons.skip_previous, color: Colors.grey), onPressed: _player.seekToPrevious), IconButton(icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle, color: mikuColor, size: 35), onPressed: () => isPlaying ? _player.pause() : _player.play()), IconButton(icon: const Icon(Icons.skip_next, color: Colors.grey), onPressed: _player.seekToNext)]))) : null,
    );
  }
}