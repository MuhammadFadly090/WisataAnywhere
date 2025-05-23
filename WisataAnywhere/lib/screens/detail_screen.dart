import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';

import 'package:wisataAnywhere/screens/check_location.dart';

class DetailPostScreen extends StatefulWidget {
  final String? imageBase64;
  final String? title;
  final String? description;
  final DateTime createdAt;
  final String fullName;
  final String postId;

  const DetailPostScreen({
    Key? key,
    required this.title,
    required this.imageBase64,
    required this.description,
    required this.createdAt,
    required this.fullName,
    required this.postId,
  }) : super(key: key);

  factory DetailPostScreen.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parsedCreatedAt;
    if (data['createdAt'] is Timestamp) {
      parsedCreatedAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return DetailPostScreen(
      postId: doc.id,
      imageBase64: data['image'],
      title: data['title'],
      description: data['description'],
      createdAt: parsedCreatedAt,
      fullName: data['fullName'] ?? 'Anonymous',
    );
  }

  @override
  State<DetailPostScreen> createState() => _DetailPostScreenState();
}

class _DetailPostScreenState extends State<DetailPostScreen> {
  bool isLiked = false;
  bool isLoading = true;
  bool _showCommentBox = false;

  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> comments = [];

  final Map<String, bool> _showReplyBox = {};
  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _checkIfPostIsLiked();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return '${diff.inSeconds} secs ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    if (diff.inHours < 48) return '1 day ago';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

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
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchComments() async {
    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('comments')
          .where('postId', isEqualTo: widget.postId)
          .orderBy('createdAt', descending: true)
          .get();

      final fetchedComments = commentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'text': data['text'],
          'userName': data['userName'],
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();

      setState(() => comments = fetchedComments);
    } catch (e) {
      print('Error fetching comments: $e');
    }
  }

  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    setState(() => isLiked = !isLiked);

    try {
      if (isLiked) {
        await FirebaseFirestore.instance.collection('favorites').add({
          'userId': currentUser.uid,
          'postId': widget.postId,
          'createdAt': FieldValue.serverTimestamp(),
          'fullName': widget.fullName,
          'title': widget.title,
          'description': widget.description,
          'image': widget.imageBase64,
          'originalPostCreatedAt': widget.createdAt.toIso8601String(),
        });
      } else {
        final query = await FirebaseFirestore.instance
            .collection('favorites')
            .where('userId', isEqualTo: currentUser.uid)
            .where('postId', isEqualTo: widget.postId)
            .get();

        for (var doc in query.docs) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      setState(() => isLiked = !isLiked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

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

    await FirebaseFirestore.instance.collection('comments').add({
      'postId': widget.postId,
      'userId': currentUser.uid,
      'userName': userName,
      'text': _commentController.text.trim(),
      'createdAt': Timestamp.now(),
    });

    _commentController.clear();
    await _fetchComments();
  }

  Future<void> _addReply(String commentId) async {
    final replyText = _replyControllers[commentId]?.text.trim();
    if (replyText == null || replyText.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to reply')),
      );
      return;
    }

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

    await FirebaseFirestore.instance
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add({
      'userId': currentUser.uid,
      'userName': userName,
      'text': replyText,
      'createdAt': Timestamp.now(),
    });

    _replyControllers[commentId]?.clear();
  }

  Future<void> _sharePost() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to share posts')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Location permission is required to share location')),
          );
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();

      final googleMapsUrl =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';

      String shareText =
          '${widget.title ?? 'Check this post'}\n\n${widget.description ?? ''}\n\nLocation: $googleMapsUrl';

      if (widget.imageBase64 != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/shared_image.png');

        final decodedBytes = base64Decode(widget.imageBase64!);
        await file.writeAsBytes(decodedBytes);

        await Share.shareXFiles([XFile(file.path)], text: shareText);
      } else {
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
        title: Text(widget.title ?? "Detail Post"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.imageBase64 != null)
                    Stack(
                      children: [
                        Image.memory(
                          base64Decode(widget.imageBase64!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CheckLocationScreen(postId: widget.postId),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
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
                        if (widget.title != null && widget.title!.isNotEmpty)
                          Text(
                            widget.title!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (widget.description != null &&
                            widget.description!.isNotEmpty)
                          Text(
                            widget.description!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Column(
                                children: [
                                  Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isLiked ? Colors.red : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Like',
                                    style: TextStyle(
                                      color:
                                          isLiked ? Colors.red : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                        if (_showCommentBox) ...[
                          const SizedBox(height: 16),
                          const Divider(),
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
                                  maxLength: 200,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _addComment,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...comments.map(_buildCommentItem),
                          if (comments.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                    'No comments yet. Be the first to comment!'),
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
    final commentId = comment['id'] as String;
    _replyControllers.putIfAbsent(
        commentId, () => TextEditingController());
    _showReplyBox.putIfAbsent(commentId, () => false);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment['userName'] ?? 'Anonymous',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTime(comment['createdAt']),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment['text'] ?? ''),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showReplyBox[commentId] =
                                  !_showReplyBox[commentId]!;
                            });
                          },
                          child: const Text('Reply'),
                        ),
                      ],
                    ),
                    if (_showReplyBox[commentId] == true) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyControllers[commentId],
                                decoration: const InputDecoration(
                                  hintText: 'Write a reply...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, size: 20),
                              onPressed: () async {
                                await _addReply(commentId);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('comments')
                            .doc(commentId)
                            .collection('replies')
                            .orderBy('createdAt', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox();
                          }
                          final replies = snapshot.data!.docs;
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: replies.length,
                            itemBuilder: (context, index) {
                              final replyData = replies[index].data()
                                  as Map<String, dynamic>;
                              final replyTime = (replyData['createdAt']
                                      as Timestamp)
                                  .toDate();
                              return Container(
                                margin: const EdgeInsets.only(
                                    top: 4.0, left: 32.0),
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          replyData['userName'] ??
                                              'Anonymous',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatTime(replyTime),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      replyData['text'] ?? '',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}