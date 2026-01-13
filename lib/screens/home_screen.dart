import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import 'player_screen.dart';
import 'package:just_audio_background/just_audio_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Song> songs = [];
  bool isLoading = true;
  final AudioPlayer _player = AudioPlayer();
  Song? currentSong;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    fetchSongs();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state.playing;
        });
      }
    });
  }

  Future<void> fetchSongs() async {
    // Nhớ thay IP nếu dùng máy thật
    final url = Uri.parse('http://10.0.2.2:3000/songs');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          songs = data.map((json) => Song.fromJson(json)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print("Lỗi: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> playMusic(Song song) async {
    try {
      if (currentSong?.id != song.id) {
        setState(() => currentSong = song);
        final audioSource = AudioSource.uri(
          Uri.parse(song.audioUrl),
          tag: MediaItem(
            id: song.id,
            album: "My Music App",
            title: song.title,
            artist: song.artist,
            artUri: Uri.parse(song.imageUrl),
          ),
        );

        await _player.setAudioSource(audioSource);
        _player.play();
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(song: song, player: _player),
          ),
        );
      }
    } catch (e) {
      print("Lỗi phát nhạc: $e");
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
          ? const Center(child: CircularProgressIndicator())
          : songs.isEmpty
          ? const Center(child: Text("Chưa có bài hát nào"))
          : ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(song.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
            ),
            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(song.artist),
            onTap: () => playMusic(song),
          );
        },
      ),
    );
  }
}