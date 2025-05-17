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
    _openLocationInMaps();
  }

  Future<void> _openLocationInMaps() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (!doc.exists) {
        print('Post not found');
        Navigator.of(context).pop();
        return;
      }

      final data = doc.data();
      if (data == null) {
        print('Post data is empty');
        Navigator.of(context).pop();
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
        print('Invalid location data');
        Navigator.of(context).pop();
        return;
      }

      final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch maps');
      }
    } catch (e) {
      print('Error opening location in maps: $e');
    } finally {
      Navigator.of(context).pop(); // tutup layar ini setelah buka maps atau gagal
    }
  }

  @override
  Widget build(BuildContext context) {
    // tampilkan kosong atau loading sementara proses berjalan
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
