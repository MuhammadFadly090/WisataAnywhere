import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wisataAnywhere/screens/detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Format time for display
  String _formatTime(DateTime dateTime) {
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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Search posts by title
  Future<void> _searchPosts(String query) async {
    setState(() {
      _isSearching = true;
      _searchQuery = query.toLowerCase();
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Get all posts and filter by title
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();

      final filteredDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final title = (data['title'] as String?) ?? '';
        return title.toLowerCase().contains(_searchQuery);
      }).toList();

      setState(() {
        _searchResults = filteredDocs;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showErrorSnackBar('Error searching: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _navigateToDetailScreen(
    String postId,
    String? imageBase64,
    String? title,
    String? description,
    DateTime createdAt,
    String fullName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailPostScreen(
          postId: postId,
          imageBase64: imageBase64,
          title: title,
          description: description,
          createdAt: createdAt,
          fullName: fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Posts'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchPosts('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                _searchPosts(value);
              },
            ),
          ),
          
          // Results
          Expanded(
            child: _isSearching 
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchQuery.isNotEmpty
                    ? _buildEmptyResults(isDarkMode)
                    : _buildSearchResults(isDarkMode, themeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResults(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDarkMode ? Colors.grey[400] : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No posts found with title "$_searchQuery"',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDarkMode, Color themeColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final postDoc = _searchResults[index];
        final postId = postDoc.id;
        final data = postDoc.data() as Map<String, dynamic>;
        final imageBase64 = data['image'] as String?;
        final title = data['title'] as String? ?? 'Untitled';
        final description = data['description'] as String? ?? '';
        final createdAtStr = data['createdAt'] as String;
        final fullName = data['fullName'] as String? ?? 'Anonymous';
        final createdAt = DateTime.parse(createdAtStr);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateToDetailScreen(
              postId, imageBase64, title, description, createdAt, fullName),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageBase64 != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                    child: Image.memory(
                      base64Decode(imageBase64),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: themeColor.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode 
                                      ? Colors.white 
                                      : Colors.black,
                                ),
                              ),
                              Text(
                                _formatTime(createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode 
                                      ? Colors.grey[400] 
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode 
                              ? Colors.white 
                              : Colors.black,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode 
                                  ? Colors.grey[300] 
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}