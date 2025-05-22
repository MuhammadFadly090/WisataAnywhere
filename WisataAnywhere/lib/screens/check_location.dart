import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckLocationScreen extends StatefulWidget {
  final String postId;

  const CheckLocationScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _CheckLocationScreenState createState() => _CheckLocationScreenState();
}

class _CheckLocationScreenState extends State<CheckLocationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openLocationInMaps();
    });
  }

  Future<void> _openLocationInMaps() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (!doc.exists) {
        _showError('Post not found');
        return;
      }

      final data = doc.data();
      if (data == null) {
        _showError('Post data is empty');
        return;
      }

      final latRaw = data['latitude'];
      final longRaw = data['longitude'];

      double? latitude;
      double? longitude;

      if (latRaw != null) {
        latitude = (latRaw is num) ? latRaw.toDouble() : double.tryParse(latRaw.toString());
      }
      if (longRaw != null) {
        longitude = (longRaw is num) ? longRaw.toDouble() : double.tryParse(longRaw.toString());
      }

      if (latitude == null || longitude == null) {
        _showError('Invalid location data');
        return;
      }

      final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not launch maps');
      }
    } catch (e) {
      _showError('Error opening location: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // keluar dari screen juga
                },
                child: Text('OK'))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
