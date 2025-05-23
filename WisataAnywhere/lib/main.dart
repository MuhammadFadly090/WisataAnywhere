import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/home_screens.dart';
import 'screens/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeProvider,
      child: const MyApp(),
    ),
  );
}

// ✅ Fungsi untuk kirim notifikasi ke topic "news"
Future<void> sendNotificationToTopic(String title, String body) async {
  const String url = 'https://wisataanywherecloud.vercel.app/send-to-topic';
  const String topic = 'news';

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'topic': topic,
        'notification': {
          'title': title,
          'body': body,
        },
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Notifikasi berhasil dikirim ke topic $topic');
    } else {
      print('❌ Gagal mengirim notifikasi: ${response.body}');
    }
  } catch (e) {
    print('❌ Error kirim notifikasi: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WisataAnywhere',
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const FCMWrapper(),
    );
  }
}

class FCMWrapper extends StatefulWidget {
  const FCMWrapper({super.key});

  @override
  State<FCMWrapper> createState() => _FCMWrapperState();
}

class _FCMWrapperState extends State<FCMWrapper> {
  @override
  void initState() {
    super.initState();

    // Dengarkan login user
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        // 🔐 Ambil token
        String? token = await FirebaseMessaging.instance.getToken();
        print('🔐 FCM Token: $token');

        // 📢 Subscribe ke topic 'news'
        await FirebaseMessaging.instance.subscribeToTopic('news');
        print('✅ Subscribed to topic "news"');

        if (token != null) {
          // 💾 Simpan token ke Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'fcm_token': token,
                'updated_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          print('✅ Token disimpan di Firestore');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const SignInScreen();
      },
    );
  }
}