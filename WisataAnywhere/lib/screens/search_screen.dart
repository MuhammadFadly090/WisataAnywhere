import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wisataanywhere/screens/detail_screen.dart';// Import the DetailPostScreen

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  String _filterMode = 'all';
  Position? _userPosition;
  static const double nearbyRadiusKm = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('Layanan lokasi tidak aktif');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('Izin lokasi ditolak');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar('Izin lokasi ditolak permanen');
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _userPosition = pos;
    });
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; 
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) /
            2;
    return 12742 * asin(sqrt(a)); 
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _searchPosts(String query) async {
    setState(() {
      _isSearching = true;
      _searchQuery = query.toLowerCase();
    });

    if (query.isEmpty && _filterMode == 'all') {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    try {
      if (_filterMode == 'all') {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .get();

        final filteredDocs = querySnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] as String? ?? '').toLowerCase();
          final topic = (data['topic'] as String? ?? '').toLowerCase();
          return title.contains(_searchQuery) || topic.contains(_searchQuery);
        }).toList();

        setState(() {
          _searchResults = filteredDocs;
          _isSearching = false;
        });
      } else if (_filterMode == 'nearby') {
        if (_userPosition == null) {
          await _determinePosition();
          if (_userPosition == null) {
            _showErrorSnackBar('Tidak dapat menentukan lokasi pengguna');
            setState(() {
              _isSearching = false;
              _searchResults = [];
            });
            return;
          }
        }

        final allPosts = await FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .get();

        final nearbyDocs = allPosts.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (!data.containsKey('latitude') || !data.containsKey('longitude'))
            return false;

          final lat = data['latitude'] as double?;
          final lon = data['longitude'] as double?;
          if (lat == null || lon == null) return false;

          final distance = _calculateDistance(
            _userPosition!.latitude,
            _userPosition!.longitude,
            lat,
            lon,
          );
          return distance <= nearbyRadiusKm;
        }).toList();

        if (nearbyDocs.isEmpty) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
          _showErrorSnackBar(
              'Tidak ada tempat wisata terdekat dalam radius $nearbyRadiusKm km');
          return;
        }

        final filteredNearbyDocs = nearbyDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] as String? ?? '').toLowerCase();
          final topic = (data['topic'] as String? ?? '').toLowerCase();
          return title.contains(_searchQuery) || topic.contains(_searchQuery);
        }).toList();

        setState(() {
          _searchResults = filteredNearbyDocs;
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showErrorSnackBar('Error searching: $e');
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Semua Tempat Wisata'),
              value: 'all',
              groupValue: _filterMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _filterMode = value;
                  });
                  _searchPosts(_searchController.text);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Tempat Wisata Terdekat (10 km)'),
              value: 'nearby',
              groupValue: _filterMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _filterMode = value;
                  });
                  _searchPosts(_searchController.text);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else {
      return '${difference.inDays} hari lalu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Tempat Wisata'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari berdasarkan judul',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      _searchPosts(value);
                    },
                    onSubmitted: (value) {
                      _searchPosts(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada hasil pencarian',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final doc = _searchResults[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final postId = doc.id;
                          final imageBase64 = data['image'] as String?;
                          final title = data['title'] as String?;
                          final description = data['description'] as String?;
                          final createdAtStr = data['createdAt'] as String? ?? '';
                          final fullName = data['fullName'] as String? ?? 'Unknown';
                          final userId = data['userId'] as String? ?? '';

                          // Handle createdAt parsing
                          DateTime createdAt;
                          if (data['createdAt'] is Timestamp) {
                            createdAt = (data['createdAt'] as Timestamp).toDate();
                          } else {
                            try {
                              createdAt = DateTime.parse(createdAtStr);
                            } catch (_) {
                              createdAt = DateTime.now();
                            }
                          }

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailPostScreen(
                                    postId: postId,
                                    imageBase64: imageBase64,
                                    title: title,
                                    description: description,
                                    createdAt: createdAt,
                                    fullName: fullName,
                                    userId: userId,
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (imageBase64 != null && imageBase64.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          base64Decode(imageBase64),
                                          width: 100,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 100,
                                              height: 80,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.broken_image),
                                            );
                                          },
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 100,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.image_not_supported),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title ?? '-',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: themeColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            description ?? '-',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDarkMode
                                                  ? Colors.grey[300]
                                                  : Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Oleh: $fullName',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDarkMode
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
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
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}