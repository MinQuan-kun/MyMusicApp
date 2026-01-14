import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
// 👇 QUAN TRỌNG: Import file HomeScreen mới (Miku Style)
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo dịch vụ chạy nền (Giữ nguyên như cũ để không lỗi)
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.minh.my_music_app.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
    print("✅ Init Audio Service Success");
  } catch (e) {
    print("❌ Init Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Miku Music',
      // Setup Theme sáng sủa cho hợp với Miku Style
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF39C5BB), // Màu Miku
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      // 👇 GỌI HOMESCREEN MỚI TỪ FILE 'screens/home_screen.dart'
      home: const HomeScreen(),
    );
  }
}