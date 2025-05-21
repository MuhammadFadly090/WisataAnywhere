import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Tambahkan package ini

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  File? _image;
  String? _base64Image;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _getLocation(); // Ambil lokasi di awal
  }

  Future<void> _requestPermissions() async {
    // Request camera and storage permissions on init
    await [
      Permission.camera,
      Permission.storage,
    ].request();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check camera permission first when using camera
      if (source == ImageSource.camera) {
        final status = await Permission.camera.status;
        if (!status.isGranted) {
          final result = await Permission.camera.request();
          if (result != PermissionStatus.granted) {
            _showErrorSnackbar('Camera permission denied');
            return;
          }
        }
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 50, // Reduce image quality further
        maxWidth: 800, // Limit image width
        maxHeight: 800, // Limit image height
      );
      
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        
        // Compress and convert to base64 with error handling
        try {
          final Uint8List? compressedBytes = await _compressImage(_image!);
          if (compressedBytes != null) {
            final String encoded = base64Encode(compressedBytes);
            // Limit base64 string size for Firestore (limit to ~800KB)
            if (encoded.length > 800000) {
              _base64Image = encoded.substring(0, 800000);
              debugPrint('Image trimmed to fit Firestore limits');
            } else {
              _base64Image = encoded;
            }
          } else {
            _showErrorSnackbar('Failed to compress image');
          }
        } catch (e) {
          debugPrint('Base64 encoding error: $e');
          _showErrorSnackbar('Failed to process image: $e');
        }
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      _showErrorSnackbar('Failed to pick image: ${e.toString()}');
    }
  }

  // Method to compress image
  Future<Uint8List?> _compressImage(File file) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 600,
        minHeight: 600,
        quality: 40, // Low quality for smaller size
      );
      return result;
    } catch (e) {
      debugPrint('Image compression error: $e');
      return null;
    }
  }

  Future<void> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse && 
            permission != LocationPermission.always) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 15));

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Location error: $e');
      // Don't show error snackbar for location, just log it
    }
  }

  Future<void> _submitPost() async {
    if (_image == null || _base64Image == null) {
      _showErrorSnackbar('Please add an image');
      return;
    }

    if (_titleController.text.isEmpty) {
      _showErrorSnackbar('Please add a title');
      return;
    }

    if (_descriptionController.text.isEmpty) {
      _showErrorSnackbar('Please add a description');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackbar('User not found. Please sign in.');
        setState(() => _isUploading = false);
        return;
      }

      // Get user document safely
      DocumentSnapshot? userDoc;
      try {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      } catch (e) {
        debugPrint('Error fetching user doc: $e');
      }
          
      final fullName = userDoc?.data() is Map ? 
          (userDoc!.data() as Map<String, dynamic>)['fullName'] ?? 'Anonymous' : 
          'Anonymous';

      // Create a cleaned map to avoid invalid arguments
      final Map<String, dynamic> postData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(), // Use server timestamp
        'userId': user.uid,
        'status': 'Pending',
        'fullName': fullName,
      };

      // Add base64Image if it's not too large
      if (_base64Image != null && _base64Image!.length < 900000) {
        postData['image'] = _base64Image;
      } else {
        // Store a placeholder if image is too large
        postData['image'] = 'image_too_large';
        postData['imageError'] = 'Image was too large to upload directly';
      }

      // Add location only if available
      if (_latitude != null && _longitude != null) {
        postData['latitude'] = _latitude;
        postData['longitude'] = _longitude;
      }

      // Create the document
      await FirebaseFirestore.instance.collection('posts').add(postData);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackbar('Post uploaded successfully!');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      _showErrorSnackbar('Failed to upload: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a picture'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image picker section
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Add Photo',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter post title...',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            
            // Description field
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter post description...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Location status
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location'),
              subtitle: _latitude != null 
                  ? Text('Lat: $_latitude, Long: $_longitude')
                  : const Text('Getting location...'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _getLocation,
              ),
            ),
            const SizedBox(height: 24),
            
            // Submit button
            ElevatedButton(
              onPressed: _isUploading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'SUBMIT POST',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}