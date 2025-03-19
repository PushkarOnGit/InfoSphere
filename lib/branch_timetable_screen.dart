import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class BranchTimetableScreen extends StatefulWidget {
  const BranchTimetableScreen({super.key});

  @override
  State<BranchTimetableScreen> createState() => _BranchTimetableScreenState();
}

class _BranchTimetableScreenState extends State<BranchTimetableScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _timetables = [];
  String? _selectedPdfUrl;

  @override
  void initState() {
    super.initState();
    _loadTimetables();
  }

  Future<void> _loadTimetables() async {
    final QuerySnapshot snapshot = await _firestore.collection('branch_timetables').get();
    setState(() {
      _timetables = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  Future<void> _uploadTimetable() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      final String fileName = result.files.single.name;
      final String filePath = result.files.single.path!;

      // Upload to Firebase Storage
      final Reference storageRef = _storage.ref().child('branch_timetables/$fileName');
      await storageRef.putFile(File(filePath));

      // Get download URL
      final String downloadUrl = await storageRef.getDownloadURL();

      // Save metadata to Firestore
      await _firestore.collection('branch_timetables').add({
        'fileName': fileName,
        'downloadUrl': downloadUrl,
        'uploadedBy': _user?.uid,
        'timestamp': DateTime.now(),
      });

      _loadTimetables(); // Refresh the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1B26),
      appBar: AppBar(
        title: const Text(
          'Branch Timetable',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // PDF Viewer
          if (_selectedPdfUrl != null)
            Expanded(
              flex: 2,
              child: PDFView(
                filePath: _selectedPdfUrl!,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: true,
                pageSnap: true,
              ),
            )
          else
            const Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  'No PDF selected',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

          // List of Timetables
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: _timetables.length,
              itemBuilder: (context, index) {
                final timetable = _timetables[index];
                return ListTile(
                  title: Text(
                    timetable['fileName'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedPdfUrl = timetable['downloadUrl'];
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('users').doc(_user?.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final String role = userData['role'];

            if (role == 'Teacher') {
              return FloatingActionButton(
                onPressed: _uploadTimetable,
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.add,
                  color: Colors.black,
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}