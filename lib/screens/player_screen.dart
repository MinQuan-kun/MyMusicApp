import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';

class PlayerScreen extends StatefulWidget {
  final Song song;
  final AudioPlayer player;

  const PlayerScreen({super.key, required this.song, required this.player});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Hàm chuyển đổi giây thành phút:giây (VD: 200s -> 03:20)
  String formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Nền đen cho ngầu
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Nút đóng màn hình
        ),
        title: const Text("Đang phát", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. ẢNH BÌA (Lấy từ Cloudinary)
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                ],
                image: DecorationImage(
                  image: NetworkImage(widget.song.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 2. TÊN BÀI HÁT & CA SĨ
            Text(
              widget.song.title,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              widget.song.artist,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 30),

            // 3. THANH TUA NHẠC (SLIDER) + THỜI GIAN
            StreamBuilder<Duration>(
              stream: widget.player.positionStream, // Lắng nghe vị trí hiện tại
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = widget.player.duration ?? Duration.zero;

                return Column(
                  children: [
                    Slider(
                      min: 0,
                      max: duration.inSeconds.toDouble(),
                      value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()),
                      activeColor: Colors.green, // Màu xanh Spotify
                      inactiveColor: Colors.grey[800],
                      onChanged: (value) {
                        // Khi người dùng kéo thanh trượt -> Tua nhạc
                        widget.player.seek(Duration(seconds: value.toInt()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatTime(position), style: const TextStyle(color: Colors.grey)),
                          Text(formatTime(duration), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // 4. CÁC NÚT ĐIỀU KHIỂN (Play/Pause)
            StreamBuilder<PlayerState>(
              stream: widget.player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final processingState = playerState?.processingState;
                final playing = playerState?.playing;

                if (processingState == ProcessingState.loading ||
                    processingState == ProcessingState.buffering) {
                  return const CircularProgressIndicator(color: Colors.green);
                } else if (playing != true) {
                  return IconButton(
                    iconSize: 80,
                    icon: const Icon(Icons.play_circle_filled, color: Colors.white),
                    onPressed: widget.player.play,
                  );
                } else {
                  return IconButton(
                    iconSize: 80,
                    icon: const Icon(Icons.pause_circle_filled, color: Colors.green),
                    onPressed: widget.player.pause,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}