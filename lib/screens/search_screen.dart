import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wisataAnywhere/screens/detail_screen.dart'; 
import 'package:intl/intl.dart'; 

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _searchPosts(String query) async {
    if (query.isEmpty) return [];

    setState(() => _isLoading = true);
    
    try {
      final result = await FirebaseFirestore.instance
          .collection('posts')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: '${query}z')
          .orderBy('title')
          .limit(10)
          .get();

      return result.docs.map((doc) {
        final data = doc.data();
        final createdAt = DateTime.parse(data['createdAt']);
        return {
          'id': doc.id,
          'title': data['title'],
          'description': data['description'],
          'image': data['image'],
          'fullName': data['fullName'] ?? 'Anonymous',
          'createdAt': createdAt,
        };
      }).toList();
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by title...',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchText = '');
              },
            ),
          ),
          onChanged: (value) {
            setState(() => _searchText = value.trim());
          },
          onSubmitted: (value) {
            setState(() => _searchText = value.trim());
          },
        ),
      ),
      body: Column(
        children: [
          // Auto-search as user types (remove the search button)
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _searchPosts(_searchText),
              builder: (context, snapshot) {
                if (_searchText.isEmpty) {
                  return const Center(
                    child: Text('Enter a title to search'),
                  );
                }

                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No posts found'));
                }

                final posts = snapshot.data!;

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(post['title']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post['description']),
                            const SizedBox(height: 4),
                            Text(
                              'Posted by ${post['fullName']} on ${_formatDate(post['createdAt'])}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        leading: post['image'] != null
                            ? Image.memory(
                                base64Decode(post['image']),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailPostScreen(
                                postId: post['id'],
                                imageBase64: post['image'],
                                description: post['description'],
                                createdAt: post['createdAt'],
                                fullName: post['fullName'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}