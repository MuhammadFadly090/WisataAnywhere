import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fasum/screens/detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
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

  void _navigateToDetailScreen(String postId, String? imageBase64, String? description, DateTime createdAt, String fullName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailPostScreen(
          postId: postId,
          imageBase64: imageBase64,
          description: description,
          createdAt: createdAt,
          fullName: fullName,
        ),
      ),
    ).then((_) {
      // Refresh the favorite list when coming back from detail screen
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text('Please sign in to view your favorites'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Favorites"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('favorites')
            .where('userId', isEqualTo: currentUser.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No favorites yet'));
          }

          final favorites = snapshot.data!.docs;

          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favoriteDoc = favorites[index];
              final favoriteId = favoriteDoc.id;
              final data = favoriteDoc.data() as Map<String, dynamic>;
              final postId = data['postId'] as String;
              final imageBase64 = data['image'] as String?;
              final description = data['description'] as String?;
              final createdAtStr = data['createdAt'] as String;
              final fullName = data['fullName'] as String? ?? 'Anonim';

              // Parse ke DateTime
              final createdAt = DateTime.parse(createdAtStr);

              return Card(
                margin: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageBase64 != null)
                      GestureDetector(
                        onTap: () {
                          _navigateToDetailScreen(
                            postId,
                            imageBase64,
                            description,
                            createdAt,
                            fullName,
                          );
                        },
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10)),
                          child: Image.memory(
                            base64Decode(imageBase64),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        _navigateToDetailScreen(
                          postId,
                          imageBase64,
                          description,
                          createdAt,
                          fullName,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatTime(createdAt),
                                  style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tombol Remove from favorites
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('Remove', style: TextStyle(color: Colors.red)),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('favorites')
                                  .doc(favoriteId)
                                  .delete();
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Removed from favorites')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}