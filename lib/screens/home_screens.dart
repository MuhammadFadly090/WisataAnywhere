import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fasum/screens/add_post_screen.dart';
import 'package:fasum/screens/detail_screen.dart';
import 'package:fasum/screens/sign_in_screen.dart';
import 'package:fasum/screens/theme_provider.dart'; 
import 'package:fasum/screens/favorite_screen.dart'; 
import 'package:fasum/screens/search_screen.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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

  Future<void> signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (route) => false,
    );
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
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AddPostScreen()),
      ).then((_) {
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme(!isDarkMode);
            },
          ),
          IconButton(
            onPressed: () => signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
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
            return const Center(child: Text('No posts available'));
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postDoc = posts[index];
              final postId = postDoc.id;
              final data = postDoc.data() as Map<String, dynamic>;
              final imageBase64 = data['image'] as String?;
              final description = data['description'] as String?;
              final createdAtStr = data['createdAt'] as String;
              final fullName = data['fullName'] as String? ?? 'Anonim';

              final createdAt = DateTime.parse(createdAtStr);

              return Card(
                margin: const EdgeInsets.all(10),
                color: isDarkMode ? Colors.grey[900] : Colors.white,
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
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey),
                                ),
                                Text(
                                  fullName,
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddPostScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // Home Button
            IconButton(
              icon: Icon(
                Icons.home,
                color: _selectedIndex == 0 
                  ? Theme.of(context).colorScheme.primary 
                  : (isDarkMode ? Colors.grey[400] : Colors.grey),
              ),
              onPressed: () {
                setState(() => _selectedIndex = 0);
                // Jika sudah di home screen, tidak perlu navigasi lagi
                if (ModalRoute.of(context)?.settings.name != '/') {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            
            // Favorite Button - Diubah untuk navigasi ke FavoriteScreen
            IconButton(
              icon: Icon(
                Icons.favorite,
                color: _selectedIndex == 1  // Diubah dari 2 ke 1
                  ? Theme.of(context).colorScheme.primary 
                  : (isDarkMode ? Colors.grey[400] : Colors.grey),
              ),
              onPressed: () {
                setState(() => _selectedIndex = 1);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoriteScreen()),
                ).then((_) {
                  // Reset index ketika kembali dari favorite screen
                  setState(() => _selectedIndex = 0);
                });
              },
            ),
            
            // Spacer untuk FAB
            const SizedBox(width: 40),
            
            // Search Button
            IconButton(
              icon: Icon(
                Icons.search,
                color: _selectedIndex == 2
                  ? Theme.of(context).colorScheme.primary 
                  : (isDarkMode ? Colors.grey[400] : Colors.grey),
              ),
              onPressed: () {
                setState(() => _selectedIndex = 2);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                ).then((_) {
                  // Reset index ketika kembali dari search screen
                  setState(() => _selectedIndex = 0);
                });
              },
            ),
            
            // Profile Button
            IconButton(
              icon: Icon(
                Icons.person,
                color: _selectedIndex == 3  // Diubah dari 4 ke 3
                  ? Theme.of(context).colorScheme.primary 
                  : (isDarkMode ? Colors.grey[400] : Colors.grey),
              ),
              onPressed: () {
                setState(() => _selectedIndex = 3);
                // Tambahkan navigasi ke ProfileScreen jika ada
                // Navigator.push(...);
              },
            ),
          ],
        ),
      ),
    );
  }
}