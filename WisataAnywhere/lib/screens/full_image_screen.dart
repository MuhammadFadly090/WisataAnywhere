import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullscreenImageScreen extends StatefulWidget {
  final String imageBase64;
  final String? title;

  const FullscreenImageScreen({
    super.key, 
    required this.imageBase64,
    this.title,
  });

  @override
  State<FullscreenImageScreen> createState() => _FullscreenImageScreenState();
}

class _FullscreenImageScreenState extends State<FullscreenImageScreen> with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  final double _minScale = 0.8;
  final double _maxScale = 4.0;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });
    
    // Hide status bar for immersive experience
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    // Restore system UI when leaving
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    super.dispose();
  }

  void _resetTransformation() {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward(from: 0);
  }
  
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls ? AppBar(
        backgroundColor: Colors.black54,
        automaticallyImplyLeading: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.title != null 
          ? Text(
              widget.title!,
              style: const TextStyle(color: Colors.white),
            )
          : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetTransformation,
            tooltip: 'Reset zoom',
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur berbagi akan segera hadir')),
              );
            },
            tooltip: 'Bagikan',
          ),
        ],
      ) : null,
      body: Stack(
        children: [
          // Background blurred version of the image for aesthetic effect
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Opacity(
                opacity: 0.3,
                child: Image.memory(
                  base64Decode(widget.imageBase64),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          
          // Main image with InteractiveViewer
          GestureDetector(
            onTap: _toggleControls,
            child: Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: _minScale,
                maxScale: _maxScale,
                onInteractionEnd: (details) {
                  // Double tap to reset handled separately
                },
                child: Hero(
                  tag: 'imageHero${widget.imageBase64.hashCode}',
                  child: Image.memory(
                    base64Decode(widget.imageBase64),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom controls
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildControlButton(
                      icon: Icons.zoom_out,
                      label: 'Zoom Out',
                      onPressed: () {
                        final Matrix4 newMatrix = Matrix4.copy(_transformationController.value)
                          ..scale(0.8, 0.8);
                        _transformationController.value = newMatrix;
                      },
                    ),
                    _buildControlButton(
                      icon: Icons.fit_screen,
                      label: 'Fit',
                      onPressed: _resetTransformation,
                    ),
                    _buildControlButton(
                      icon: Icons.zoom_in,
                      label: 'Zoom In',
                      onPressed: () {
                        final Matrix4 newMatrix = Matrix4.copy(_transformationController.value)
                          ..scale(1.25, 1.25);
                        _transformationController.value = newMatrix;
                      },
                    ),
                    _buildControlButton(
                      icon: Icons.save_alt,
                      label: 'Save',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fitur simpan akan segera hadir')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
          // Instruction hint that fades out
          if (_showControls)
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 80,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 0.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    if (value == 0.0) return const SizedBox.shrink();
                    return Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Cubit untuk memperbesar, ketuk untuk menyembunyikan kontrol",
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      // Double tap detection is better handled with a floating action button
      floatingActionButton: _showControls ? FloatingActionButton(
        onPressed: _resetTransformation,
        backgroundColor: Colors.black54,
        mini: true,
        child: const Icon(Icons.center_focus_strong, color: Colors.white),
      ) : null,
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}