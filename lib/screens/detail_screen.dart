import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class DetailPostScreen extends StatefulWidget {
  final String? imageBase64;
  final String? description;
  final DateTime createdAt;
  final String fullName;
  final String postId; // Perlu menambahkan postId untuk referensi ke database

  const DetailPostScreen({
    super.key,
    required this.imageBase64,
    required this.description,
    required this.createdAt,
    required this.fullName,
    required this.postId,
  });

  @override
  State<DetailPostScreen> createState() => _DetailPostScreenState();
}

class _DetailPostScreenState extends State<DetailPostScreen> {
  bool isLiked = false;
  final TextEditingController _commentController = TextEditingController();
  bool _showCommentBox = false;
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkIfPostIsLiked();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} secs ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hrs ago';
    } else if (diff.inHours < 48) {
      return '1 day ago';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  // Memeriksa apakah post sudah disukai
  Future<void> _checkIfPostIsLiked() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: currentUser.uid)
          .where('postId', isEqualTo: widget.postId)
          .get();

      setState(() {
        isLiked = doc.docs.isNotEmpty;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Mengambil komentar dari database
  Future<void> _fetchComments() async {
    final commentsSnapshot = await FirebaseFirestore.instance
        .collection('comments')
        .where('postId', isEqualTo: widget.postId)
        .orderBy('createdAt', descending: true)
        .get();

    List<Map<String, dynamic>> fetchedComments = [];
    for (var doc in commentsSnapshot.docs) {
      final data = doc.data();
      fetchedComments.add({
        'id': doc.id,
        'text': data['text'],
        'userName': data['userName'],
        'createdAt': (data['createdAt'] as Timestamp).toDate(),
      });
    }

    setState(() {
      comments = fetchedComments;
    });
  }

  // Menyimpan like ke database
  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    setState(() {
      isLiked = !isLiked;
    });

    if (isLiked) {
      // Tambahkan ke koleksi favorites
      await FirebaseFirestore.instance.collection('favorites').add({
        'userId': currentUser.uid,
        'postId': widget.postId,
        'createdAt': DateTime.now().toIso8601String(),
        'fullName': widget.fullName,
        'description': widget.description,
        'image': widget.imageBase64,
      });
    } else {
      // Hapus dari koleksi favorites
      final doc = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: currentUser.uid)
          .where('postId', isEqualTo: widget.postId)
          .get();

      for (var document in doc.docs) {
        await document.reference.delete();
      }
    }
  }

  // Menyimpan komentar ke database
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    // Dapatkan nama user
    String userName = 'Anonymous';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (userData != null && userData['fullName'] != null) {
        userName = userData['fullName'];
      }
    }

    // Simpan komentar ke database
    await FirebaseFirestore.instance.collection('comments').add({
      'postId': widget.postId,
      'userId': currentUser.uid,
      'userName': userName,
      'text': _commentController.text.trim(),
      'createdAt': Timestamp.now(),
    });

    // Bersihkan text field dan update UI
    _commentController.clear();
    await _fetchComments();
  }

  // Fungsi untuk berbagi
  // Replace your current _sharePost() method with this updated version
Future<void> _sharePost() async {
  try {
    String shareText = widget.description ?? 'Check out this post!';
    
    if (widget.imageBase64 != null) {
      // Simpan gambar sementara untuk dibagikan
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/shared_image.png');
      
      final decodedBytes = base64Decode(widget.imageBase64!);
      await file.writeAsBytes(decodedBytes);
      
      // Use the correct sharing method based on your share_plus version
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
      );
    } else {
      // Hanya bagikan teks jika tidak ada gambar
      await Share.share(shareText);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to share: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Post"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with full height
                if (widget.imageBase64 != null)
                  Image.memory(
                    base64Decode(widget.imageBase64!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                
                // Post details
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User and time info
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            child: Icon(Icons.person),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formatTime(widget.createdAt),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      if (widget.description != null && widget.description!.isNotEmpty)
                        Text(
                          widget.description!,
                          style: const TextStyle(fontSize: 16),
                        ),
                        
                      const SizedBox(height: 20),
                      
                      // Interaction buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Like button
                          GestureDetector(
                            onTap: _toggleLike,
                            child: Column(
                              children: [
                                Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : null,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Like',
                                  style: TextStyle(
                                    color: isLiked ? Colors.red : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Comment button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showCommentBox = !_showCommentBox;
                              });
                            },
                            child: Column(
                              children: [
                                const Icon(Icons.comment_outlined),
                                const SizedBox(height: 4),
                                Text('Comment (${comments.length})'),
                              ],
                            ),
                          ),
                          
                          // Share button
                          GestureDetector(
                            onTap: _sharePost,
                            child: const Column(
                              children: [
                                Icon(Icons.share_outlined),
                                SizedBox(height: 4),
                                Text('Share'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Comment section
                      if (_showCommentBox) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        
                        // Comment input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: const InputDecoration(
                                  hintText: 'Add a comment...',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _addComment,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Comment list
                        ...comments.map((comment) => _buildCommentItem(comment)),
                        if (comments.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No comments yet. Be the first to comment!'),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
  
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            child: Icon(Icons.person, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['userName'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatTime(comment['createdAt']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment['text']),
              ],
            ),
          ),
        ],
      ),
    );
  }
}