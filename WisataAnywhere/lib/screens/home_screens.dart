import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wisataAnywhere/screens/add_post_screen.dart';
import 'package:wisataAnywhere/screens/detail_screen.dart';
import 'package:wisataAnywhere/screens/sign_in_screen.dart';
import 'package:wisataAnywhere/screens/theme_provider.dart';
import 'package:wisataAnywhere/screens/favorite_screen.dart';
import 'package:wisataAnywhere/screens/search_screen.dart';
import 'package:wisataAnywhere/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

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
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (route) => false,
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

  void _onItemTapped(int index) {
    // Handle special cases for navigation to separate screens
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AddPostScreen()),
      ).then((_) {
        setState(() => _selectedIndex = 0);
        _pageController.jumpToPage(0);
      });
      return;
    }
    
    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      ).then((_) {
        setState(() => _selectedIndex = 0);
        _pageController.jumpToPage(0);
      });
      return;
    }
    
    // Normal navigation for other tabs
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index == 3 ? 2 : index);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WisataAnywhere'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(!isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Home Page (Index 0)
          _buildHomeContent(isDarkMode, themeColor),
          
          // Placeholder for Add Post (Index 1)
          Container(),
          
          // Favorites Page (Index 2)
          const FavoriteScreen(),
          
          // Profile Page is handled separately via Navigator
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home Button
              _buildNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                isSelected: _selectedIndex == 0,
                isDarkMode: isDarkMode,
                themeColor: themeColor,
              ),
              
              // Favorites Button
              _buildNavItem(
                icon: Icons.favorite,
                label: 'Favorites',
                index: 2,
                isSelected: _selectedIndex == 2,
                isDarkMode: isDarkMode,
                themeColor: themeColor,
              ),
              
              // Spacer for FAB
              const SizedBox(width: 40),
              
              // Search Button
              _buildNavItem(
                icon: Icons.search,
                label: 'Search',
                index: 1,
                isSelected: _selectedIndex == 1,
                isDarkMode: isDarkMode,
                themeColor: themeColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                ),
              ),
              
              // Profile Button
              _buildNavItem(
                icon: Icons.person,
                label: 'Profile',
                index: 3,
                isSelected: _selectedIndex == 3,
                isDarkMode: isDarkMode,
                themeColor: themeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required bool isDarkMode,
    required Color themeColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected 
                ? themeColor 
                : isDarkMode ? Colors.grey[400] : Colors.grey[600],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected 
                  ? themeColor 
                  : isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(bool isDarkMode, Color themeColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return _buildErrorState(isDarkMode, 'Error loading posts');
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final postDoc = posts[index];
            final postId = postDoc.id;
            final data = postDoc.data() as Map<String, dynamic>;
            final imageBase64 = data['image'] as String?;
            final title = data['title'] as String?;
            final description = data['description'] as String?;
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
                          if (title != null && title.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode 
                                      ? Colors.white 
                                      : Colors.black,
                                ),
                              ),
                            ),
                          if (description != null && description.isNotEmpty)
                            Text(
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(bool isDarkMode, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add, size: 50, 
              color: isDarkMode ? Colors.grey[400] : Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No posts available',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to create a post!',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}