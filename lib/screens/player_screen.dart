import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';

class PlayerScreen extends StatefulWidget {
  final AudioPlayer player;
  final List<Playlist> playlists; // Nhận List playlist từ API
  final Function(Song, Playlist) onAddToPlaylist;

  const PlayerScreen({
    super.key,
    required this.player,
    required this.playlists,
    required this.onAddToPlaylist,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final Color mikuColor = const Color(0xFF39C5BB);
  final Color darkGrey = const Color(0xFF424242);

  Song? get currentSong {
    final sequenceState = widget.player.sequenceState;
    if (sequenceState?.currentSource == null) return null;
    final mediaItem = (sequenceState!.currentSource!.tag as MediaItem);
    return Song(
      id: mediaItem.id,
      title: mediaItem.title,
      artist: mediaItem.artist ?? "Unknown",
      imageUrl: mediaItem.artUri.toString(),
      audioUrl: "",
    );
  }

  String formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _showAddToPlaylist() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          // Giới hạn chiều cao popup
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              Text("Thêm vào Playlist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGrey)),
              const SizedBox(height: 15),
              if (widget.playlists.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Text("Bạn chưa tạo playlist nào!")),

              Expanded(
                child: ListView.builder(
                  itemCount: widget.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = widget.playlists[index];
                    return ListTile(
                      leading: Icon(Icons.queue_music, color: mikuColor),
                      title: Text(playlist.name),
                      subtitle: Text("${playlist.songs.length} bài hát"),
                      onTap: () {
                        if (currentSong != null) {
                          widget.onAddToPlaylist(currentSong!, playlist);
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SequenceState?>(
      stream: widget.player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state?.currentSource == null) return const SizedBox();
        final song = currentSong!;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            leading: IconButton(
              icon: Icon(Icons.keyboard_arrow_down, color: darkGrey, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.playlist_add, color: darkGrey, size: 28),
                onPressed: _showAddToPlaylist,
              ),
            ],
          ),
          body: Stack(
            children: [
              // 1. NỀN BLUR
              Container(
                decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(song.imageUrl), fit: BoxFit.cover)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(color: Colors.white.withOpacity(0.7)),
                ),
              ),

              // 2. NỘI DUNG CHÍNH (Đã bọc SingleChildScrollView)
              SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        // Đĩa nhạc
                        Hero(
                          tag: "mini_img",
                          child: Container(
                            height: 300, width: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: mikuColor.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 15))],
                              image: DecorationImage(image: NetworkImage(song.imageUrl), fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(song.title, textAlign: TextAlign.center, style: TextStyle(color: darkGrey, fontSize: 24, fontWeight: FontWeight.bold), maxLines: 1),
                        const SizedBox(height: 8),
                        Text(song.artist, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                        const SizedBox(height: 30),

                        // Slider
                        StreamBuilder<Duration>(
                          stream: widget.player.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final duration = widget.player.duration ?? Duration.zero;
                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(thumbColor: mikuColor, activeTrackColor: mikuColor, inactiveTrackColor: Colors.grey[300], trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                                  child: Slider(min: 0, max: duration.inSeconds.toDouble(), value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()), onChanged: (val) => widget.player.seek(Duration(seconds: val.toInt()))),
                                ),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(formatTime(position), style: TextStyle(color: Colors.grey[600])), Text(formatTime(duration), style: TextStyle(color: Colors.grey[600]))])
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: Icon(Icons.shuffle, color: Colors.grey[400]), onPressed: () {}),
                            IconButton(icon: Icon(Icons.skip_previous_rounded, color: darkGrey, size: 45), onPressed: widget.player.seekToPrevious),
                            StreamBuilder<PlayerState>(
                              stream: widget.player.playerStateStream,
                              builder: (context, snapshot) {
                                final playing = snapshot.data?.playing ?? false;
                                return Container(
                                  width: 70, height: 70,
                                  decoration: BoxDecoration(color: mikuColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: mikuColor.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))]),
                                  child: IconButton(icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 35), onPressed: playing ? widget.player.pause : widget.player.play),
                                );
                              },
                            ),
                            IconButton(icon: Icon(Icons.skip_next_rounded, color: darkGrey, size: 45), onPressed: widget.player.seekToNext),
                            IconButton(icon: Icon(Icons.repeat, color: Colors.grey[400]), onPressed: () {}),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}