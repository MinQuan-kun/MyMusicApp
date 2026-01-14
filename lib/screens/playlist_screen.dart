import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import 'player_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  final AudioPlayer player;
  final String baseUrl;
  final VoidCallback onUpdate;

  const PlaylistScreen({
    super.key,
    required this.playlist,
    required this.player,
    required this.baseUrl,
    required this.onUpdate,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final Color mikuColor = const Color(0xFF39C5BB);
  final Color textDark = const Color(0xFF2D3436);

  // Danh sách bài hát cục bộ để xử lý giao diện mượt mà
  late List<Song> _localSongs;
  
  Song? currentSong;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Copy danh sách bài hát từ widget vào biến cục bộ
    _localSongs = List.from(widget.playlist.songs);

    // 1. Lắng nghe bài hát đang phát để đổi màu tên bài
    widget.player.currentIndexStream.listen((index) {
      if (index != null && widget.player.sequenceState?.sequence != null) {
        final sequence = widget.player.sequenceState!.sequence;
        if (index < sequence.length) {
          final tag = sequence[index].tag as MediaItem;
          // Kiểm tra xem bài đang phát có nằm trong playlist này không
          if (_localSongs.any((s) => s.id == tag.id)) {
            if (mounted) {
              setState(() {
                currentSong = Song(
                  id: tag.id,
                  title: tag.title,
                  artist: tag.artist ?? "",
                  imageUrl: tag.artUri.toString(),
                  audioUrl: "",
                );
              });
            }
          }
        }
      }
    });

    // 2. Lắng nghe trạng thái Play/Pause để hiện icon sóng nhạc
    widget.player.playerStateStream.listen((state) {
      if (mounted) setState(() => isPlaying = state.playing);
    });
  }

  // --- CHỨC NĂNG XÓA BÀI HÁT ---
  Future<void> _removeSong(Song song) async {
    // 1. Xóa trên giao diện trước (Optimistic UI Update)
    setState(() {
      _localSongs.removeWhere((s) => s.id == song.id);
    });

    try {
      // 2. Gửi lệnh cập nhật lên Server
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/playlists/${widget.playlist.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': widget.playlist.name,
          'songs': _localSongs.map((s) => s.toJson()).toList()
        }),
      );

      if (response.statusCode == 200) {
        widget.onUpdate(); // Báo cho Home Screen cập nhật ngầm
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Đã xóa bài hát!"), duration: Duration(seconds: 1))
        );
      } else {
        // Nếu Server lỗi, hoàn tác lại trên giao diện
        setState(() => _localSongs.add(song));
        print("Lỗi server: ${response.body}");
      }
    } catch (e) {
      // Nếu lỗi mạng, hoàn tác lại
      setState(() => _localSongs.add(song));
      print("Lỗi kết nối: $e");
    }
  }

  // --- CHỨC NĂNG XÓA PLAYLIST ---
  Future<void> _deletePlaylist() async {
    try {
      final response = await http.delete(Uri.parse('${widget.baseUrl}/playlists/${widget.playlist.id}'));
      if (response.statusCode == 200) {
        widget.onUpdate();
        if (mounted) {
          Navigator.pop(context); // Đóng Dialog
          Navigator.pop(context); // Về Home
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa Playlist!")));
        }
      }
    } catch (e) { print("Lỗi xóa playlist: $e"); }
  }

  // --- CHỨC NĂNG PHÁT NHẠC (ĐÃ SỬA LỖI URL) ---
  Future<void> playPlaylistMusic(int index) async {
    try {
      // 1. Dừng nhạc đang phát để tránh xung đột
      if (widget.player.playing) {
        await widget.player.stop();
      }

      // 2. Tạo danh sách phát
      final playlistSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: _localSongs.map((song) {
          // 👇 QUAN TRỌNG: Mã hóa URL để xử lý dấu cách và ký tự đặc biệt
          // Ví dụ: "song name.mp3" -> "song%20name.mp3"
          String encodedUrl = Uri.encodeFull(song.audioUrl);

          return AudioSource.uri(
            Uri.parse(encodedUrl), 
            tag: MediaItem(
              id: song.id,
              album: widget.playlist.name,
              title: song.title,
              artist: song.artist,
              artUri: Uri.parse(song.imageUrl),
            ),
          );
        }).toList(),
      );

      // 3. Nạp danh sách và phát
      await widget.player.setAudioSource(playlistSource, initialIndex: index);
      widget.player.play();
      
      // 4. Mở màn hình Player (nếu chưa mở)
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              player: widget.player, 
              playlists: const [], // Trong playlist screen không cần load list playlist để add nữa
              onAddToPlaylist: (s, p) {}
            )
          )
        );
      }
    } catch (e) {
      print("Lỗi phát: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi phát nhạc: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      
      // HEADER
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Text(widget.playlist.name, style: TextStyle(color: textDark, fontWeight: FontWeight.bold)), centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () => showDialog(
              context: context, 
              builder: (ctx) => AlertDialog(
                title: const Text("Xóa Playlist?"), 
                actions: [
                  TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Hủy")), 
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: _deletePlaylist, child: const Text("Xóa", style: TextStyle(color: Colors.white)))
                ]
              )
            )
          )
        ],
      ),

      // NÚT PHÁT NGAY (FLOATING BUTTON)
      floatingActionButton: _localSongs.isEmpty ? null : FloatingActionButton.extended(
        onPressed: () => playPlaylistMusic(0), // Phát từ bài đầu tiên
        backgroundColor: mikuColor,
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
        label: const Text("Phát Ngay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),

      // DANH SÁCH BÀI HÁT
      body: _localSongs.isEmpty 
          ? Center(child: Text("Playlist trống", style: TextStyle(color: Colors.grey[400]))) 
          : ListView.builder(
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 100), // Padding dưới để tránh nút FAB che mất bài cuối
              itemCount: _localSongs.length,
              itemBuilder: (context, index) {
                final song = _localSongs[index];
                // Kiểm tra bài này có đang phát không
                final isActive = currentSong?.id == song.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12), 
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(12),
                    // Viền xanh nếu đang phát
                    border: isActive ? Border.all(color: mikuColor, width: 1.5) : null 
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8), 
                      child: Image.network(
                        song.imageUrl, width: 50, height: 50, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(width: 50, height: 50, color: Colors.grey, child: const Icon(Icons.music_note)),
                      )
                    ),
                    title: Text(
                      song.title, 
                      style: TextStyle(
                        color: isActive ? mikuColor : textDark, // Chữ xanh nếu đang phát
                        fontWeight: FontWeight.bold
                      )
                    ), 
                    subtitle: Text(song.artist),
                    
                    // Nếu đang phát thì hiện Icon sóng nhạc, nếu không thì hiện nút Xóa
                    trailing: isActive && isPlaying
                        ? Icon(Icons.graphic_eq, color: mikuColor)
                        : IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), 
                            onPressed: () => _removeSong(song)
                          ),
                    onTap: () => playPlaylistMusic(index),
                  ),
                );
              },
            ),
    );
  }
}