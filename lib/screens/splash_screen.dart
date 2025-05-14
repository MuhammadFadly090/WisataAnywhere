import 'dart:async';
import 'package:wisataAnywhere/screens/home_screens.dart';
import 'package:wisataAnywhere/screens/sign_in_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with SingleTickerProviderStateMixin {
  // Constants
  static const _splashDelay = Duration(seconds: 3);
  static const _animationDuration = Duration(seconds: 2);
  
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isCheckingAuth = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _checkAuthStatus();
  }

  void _initializeAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    _animation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(_splashDelay);
    
    if (mounted) {
      setState(() => _isCheckingAuth = true);
    }

    try {
      // Give some time for animation to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      final user = FirebaseAuth.instance.currentUser;
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => user != null 
                ? const HomeScreen() 
                : const SignInScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memeriksa autentikasi. Coba lagi nanti.';
          _isCheckingAuth = false;
        });
        
        // Retry after 3 seconds if error occurs
        Timer(const Duration(seconds: 3), _checkAuthStatus);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _animation,
                  child: Image.asset(
                    'assets/fasum_icon.png',
                    width: 150,
                    height: 150,
                  ),
                ),
                const SizedBox(height: 20),
                if (_isCheckingAuth)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}