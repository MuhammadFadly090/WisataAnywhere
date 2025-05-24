import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wisataanywhere/screens/add_post_screen.dart';
import 'package:wisataanywhere/screens/detail_screen.dart';
import 'package:wisataanywhere/screens/sign_in_screen.dart';
import 'package:wisataanywhere/screens/theme_provider.dart';
import 'package:wisataanywhere/screens/favorite_screen.dart';
import 'package:wisataanywhere/screens/search_screen.dart';
import 'package:wisataanywhere/screens/profile_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<LiquidPullToRefreshState> _refreshIndicatorKey = GlobalKey<LiquidPullToRefreshState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return '${diff.inSeconds} secs ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    if (diff.inHours < 48) return '1 day ago';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 2));
    setState(() {});
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
    String userId,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DetailPostScreen(
          postId: postId,
          userId: userId,
          imageBase64: imageBase64,
          title: title,
          description: description,
          createdAt: createdAt,
          fullName: fullName,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  // Helper function to get like count for a post
  Future<int> _getLikeCount(String postId) async {
    final query = await FirebaseFirestore.instance
        .collection('favorites')
        .where('postId', isEqualTo: postId)
        .get();
    return query.docs.length;
  }

  // Helper function to get comment count for a post
  Future<int> _getCommentCount(String postId) async {
    final query = await FirebaseFirestore.instance
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .get();
    return query.docs.length;
  }

  void _onItemTapped(int index) {
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
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ).then((_) {
        setState(() => _selectedIndex = 0);
        _pageController.jumpToPage(0);
      });
      return;
    }
    
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index == 3 ? 2 : index);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final themeColor = Theme.of(context).primaryColor;
    final currentUser = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('WisataAnywhere', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.grey[900]!, Colors.grey[800]!]
                    : [themeColor, themeColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => themeProvider.toggleTheme(!isDarkMode),
            ),
            if (currentUser != null)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircleAvatar(
                      radius: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final photoBase64 = snapshot.data?['photoBase64'] as String?;
                  return GestureDetector(
                    onTap: () => _onItemTapped(3),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: photoBase64 != null
                          ? MemoryImage(base64Decode(photoBase64))
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                    ),
                  );
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: LiquidPullToRefresh(
          key: _refreshIndicatorKey,
          onRefresh: _handleRefresh,
          color: themeColor,
          height: 150,
          animSpeedFactor: 2,
          showChildOpacityTransition: false,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildHomeContent(isDarkMode, themeColor),
              Container(), // Placeholder for Add Post
              const FavoriteScreen(),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          backgroundColor: themeColor,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AddPostScreen()),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
        bottomNavigationBar: BottomAppBar(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  index: 0,
                  isSelected: _selectedIndex == 0,
                  isDarkMode: isDarkMode,
                  themeColor: themeColor,
                ),
                _buildNavItem(
                  icon: Icons.favorite,
                  label: 'Favorites',
                  index: 2,
                  isSelected: _selectedIndex == 2,
                  isDarkMode: isDarkMode,
                  themeColor: themeColor,
                ),
                const SizedBox(width: 40),
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
            color: isSelected ? themeColor : isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? themeColor : isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
          return _buildShimmerLoading();
        }
        
        if (snapshot.hasError) {
          return _buildErrorState(isDarkMode, 'Error loading posts');
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDarkMode, themeColor);
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
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
            final userId = data['userId'] as String? ?? 'Unknown';
            final createdAt = DateTime.parse(createdAtStr);
            final shareCount = data['shareCount'] as int? ?? 0;

            return FutureBuilder(
              future: Future.wait([
                _getLikeCount(postId),
                _getCommentCount(postId),
                FirebaseFirestore.instance.collection('users').doc(userId).get(),
              ]),
              builder: (context, AsyncSnapshot<List<dynamic>> combinedSnapshot) {
                if (combinedSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildPostShimmer();
                }

                if (combinedSnapshot.hasError) {
                  return _buildErrorCard(isDarkMode, 'Error loading post data');
                }

                final likeCount = combinedSnapshot.data?[0] as int? ?? 0;
                final commentCount = combinedSnapshot.data?[1] as int? ?? 0;
                final userDoc = combinedSnapshot.data?[2] as DocumentSnapshot?;
                final userData = userDoc?.data() as Map<String, dynamic>?;
                final photoBase64 = userData?['photoBase64'] as String?;
                final userPhoto = photoBase64 != null
                    ? MemoryImage(base64Decode(photoBase64))
                    : const AssetImage('assets/default_profile.png') as ImageProvider;

                return AnimatedPostCard(
                  animation: _fadeAnimation,
                  isDarkMode: isDarkMode,
                  imageBase64: imageBase64,
                  title: title,
                  description: description,
                  createdAt: createdAt,
                  fullName: fullName,
                  userPhoto: userPhoto,
                  likeCount: likeCount,
                  commentCount: commentCount,
                  shareCount: shareCount,
                  onTap: () => _navigateToDetailScreen(
                    postId, imageBase64, title, description, createdAt, fullName, userId),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 20,
              width: 200,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Container(
              height: 16,
              width: double.infinity,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Container(
              height: 16,
              width: 150,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/error.json',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => setState(() {}),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDarkMode, String error) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[400]),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, Color themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty.json',
            width: 250,
            height: 250,
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Be the first to share your travel experience!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddPostScreen()),
              );
            },
            child: const Text(
              'Create Post',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedPostCard extends StatelessWidget {
  final Animation<double> animation;
  final bool isDarkMode;
  final String? imageBase64;
  final String? title;
  final String? description;
  final DateTime createdAt;
  final String fullName;
  final ImageProvider userPhoto;
  final VoidCallback onTap;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  const AnimatedPostCard({
    required this.animation,
    required this.isDarkMode,
    this.imageBase64,
    this.title,
    this.description,
    required this.createdAt,
    required this.fullName,
    required this.userPhoto,
    required this.onTap,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: isDarkMode ? Colors.black : Colors.grey.withOpacity(0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageBase64 != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Stack(
                            children: [
                              Image.memory(
                                base64Decode(imageBase64!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatTime(createdAt),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Hero(
                                  tag: 'user_$fullName',
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: userPhoto,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fullName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDarkMode ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (title != null && title!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  title!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            if (description != null && description!.isNotEmpty)
                              Text(
                                description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite_border,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      likeCount.toString(),
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.comment_outlined,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      commentCount.toString(),
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.share_outlined,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      shareCount.toString(),
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return '${diff.inSeconds} secs ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    if (diff.inHours < 48) return '1 day ago';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}