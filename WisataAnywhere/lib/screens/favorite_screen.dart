import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Map<String, dynamic>> favorites = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final favList = querySnapshot.docs.map((doc) {
        final data = doc.data();

        // Amankan tiap field, jika null beri default yang aman
        final postId = data['postId']?.toString() ?? '';
        final title = data['title']?.toString() ?? '';
        final description = data['description']?.toString() ?? '';
        final image = data['image']?.toString(); // image bisa null, nanti cek saat decode
        final fullName = data['fullName']?.toString() ?? '';

        // Tangani field tanggal dengan aman
        DateTime originalPostCreatedAt;
        final originalDateRaw = data['originalPostCreatedAt'];

        if (originalDateRaw == null) {
          // Jika null, bisa set default (misal sekarang) atau null, sesuaikan kebutuhan
          originalPostCreatedAt = DateTime.now();
        } else if (originalDateRaw is Timestamp) {
          originalPostCreatedAt = originalDateRaw.toDate();
        } else if (originalDateRaw is String) {
          try {
            originalPostCreatedAt = DateTime.parse(originalDateRaw);
          } catch (e) {
            originalPostCreatedAt = DateTime.now();
          }
        } else {
          originalPostCreatedAt = DateTime.now();
        }

        return {
          'postId': postId,
          'title': title,
          'description': description,
          'image': image,
          'fullName': fullName,
          'originalPostCreatedAt': originalPostCreatedAt,
        };
      }).toList();

      setState(() {
        favorites = favList;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error fetching favorites: $e');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load favorites. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : favorites.isEmpty
                  ? const Center(child: Text('You have no favorites yet.'))
                  : ListView.builder(
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final fav = favorites[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(10),
                            leading: (fav['image'] != null && fav['image']!.isNotEmpty)
                                ? Image.memory(
                                    base64Decode(fav['image']),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image_not_supported),
                            title: Text(fav['title']),
                            subtitle: Text(
                              fav['description'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailPostScreen(
                                    title: fav['title'],
                                    description: fav['description'],
                                    imageBase64: fav['image'],
                                    createdAt: fav['originalPostCreatedAt'],
                                    fullName: fav['fullName'],
                                    postId: fav['postId'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
