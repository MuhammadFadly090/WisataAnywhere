import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wisataanywhere/screens/theme_provider.dart';
import 'package:wisataanywhere/screens/sign_in_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordChangeVisible = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isEditing = false;

  String? _fullName;
  String? _email;
  String? _photoBase64;
  String? _errorMessage;
  String? _successMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _email = user.email;
        _emailController.text = _email ?? '';

        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          _fullName = data['fullName'];
          _photoBase64 = data['photoBase64'];
          _fullNameController.text = _fullName ?? '';
        }
      }
    } catch (e) {
      debugPrint('Failed to load user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fullName': _fullNameController.text,
        });

        // Update email jika berubah
        if (_emailController.text != user.email) {
          await user.updateEmail(_emailController.text);
        }

        setState(() {
          _fullName = _fullNameController.text;
          _email = _emailController.text;
          _successMessage = 'Profile updated successfully.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Failed to update email.');
    } catch (e) {
      setState(() => _errorMessage = 'Unexpected error occurred.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePhoto(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'photoBase64': base64String,
        });
        setState(() {
          _photoBase64 = base64String;
        });
      }
    }
  }

  Widget _buildProfileImage(Color themeColor) {
    ImageProvider image;
    if (_photoBase64 != null) {
      image = MemoryImage(base64Decode(_photoBase64!));
    } else {
      image = const AssetImage('assets/default_profile.png');
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: image,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: () => _showImagePickerOptions(),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: themeColor,
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        )
      ],
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _updatePhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _updatePhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordController.text);

        setState(() {
          _successMessage = 'Password updated successfully';
          _isPasswordChangeVisible = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'requires-recent-login':
          message = 'Please sign in again before changing your password';
          break;
        case 'weak-password':
          message = 'New password is too weak';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Navigate to SignInScreen and clear all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPasswordSection(Color themeColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isPasswordChangeVisible = !_isPasswordChangeVisible;
                      if (!_isPasswordChangeVisible) {
                        _errorMessage = null;
                        _successMessage = null;
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      }
                    });
                  },
                  icon: Icon(_isPasswordChangeVisible ? Icons.close : Icons.lock),
                  label: Text(_isPasswordChangeVisible ? 'Cancel' : 'Change'),
                ),
              ],
            ),
            if (_isPasswordChangeVisible)
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    if (_successMessage != null)
                      Text(_successMessage!, style: const TextStyle(color: Colors.green)),

                    TextFormField(
                      controller: _currentPasswordController,
                      decoration: const InputDecoration(labelText: 'Current Password'),
                      obscureText: _obscureCurrentPassword,
                      validator: (value) => value!.isEmpty ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(labelText: 'New Password'),
                      obscureText: _obscureNewPassword,
                      validator: (value) => value!.length < 6 ? 'At least 6 characters' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(labelText: 'Confirm Password'),
                      obscureText: _obscureConfirmPassword,
                      validator: (value) =>
                          value != _newPasswordController.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      child: _isLoading ? const CircularProgressIndicator() : const Text('Update Password'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Logout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _showLogoutConfirmation,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.logout, color: Colors.white),
                label: Text(
                  _isLoading ? 'Logging out...' : 'Logout', 
                  style: const TextStyle(color: Colors.white)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Center(child: _buildProfileImage(themeColor)),
                  const SizedBox(height: 16),

                  // Edit Profile Section
                  Card(
                    margin: const EdgeInsets.only(top: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Account Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (!_isEditing) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Full Name'),
                              subtitle: Text(_fullName ?? '-'),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Email'),
                              subtitle: Text(_email ?? '-'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Profile'),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(labelText: 'Full Name'),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                            await _updateProfile();
                                            setState(() => _isEditing = false);
                                          },
                                    icon: const Icon(Icons.save),
                                    label: const Text('Save Changes'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setState(() => _isEditing = false),
                                    icon: const Icon(Icons.cancel),
                                    label: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_errorMessage != null)
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                          if (_successMessage != null)
                            Text(_successMessage!, style: const TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildPasswordSection(themeColor),
                  
                  const SizedBox(height: 24),
                  _buildLogoutSection(),
                ],
              ),
            ),
    );
  }
}