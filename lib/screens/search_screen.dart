import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
          .where('description', isGreaterThanOrEqualTo: query)
          .where('description', isLessThan: query + 'z')
          .limit(10)
          .get();

      return result.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'description': data['description'],
          'image': data['image'],
          'fullName': data['fullName'] ?? 'Anonymous',
          'createdAt': data['createdAt'],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search posts...',
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
          if (_searchText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _searchPosts(_searchText),
                child: const Text('Search'),
              ),
            ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _searchPosts(_searchText),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No results found'));
                      }

                      final posts = snapshot.data!;

                      return ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return ListTile(
                            title: Text(post['description']),
                            subtitle: Text(post['fullName']),
                            // Tambahan: bisa menambahkan onTap untuk navigasi ke detail post
                            onTap: () {
                              // Navigator.push(...);
                            },
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