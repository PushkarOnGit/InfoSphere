import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

class ExamTimetableScreen extends StatefulWidget {
  const ExamTimetableScreen({super.key});

  @override
  State<ExamTimetableScreen> createState() => _ExamTimetableScreenState();
}

class _ExamTimetableScreenState extends State<ExamTimetableScreen> {
  List<File> _timetables = [];
  String? _selectedPdfPath;

  @override
  void initState() {
    super.initState();
    _loadTimetables();
  }

  Future<void> _loadTimetables() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> files = appDir.listSync();
    setState(() {
      _timetables = files.whereType<File>().where((file) => file.path.endsWith('.pdf')).toList();
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

      // Copy the file to the app's local storage
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String localFilePath = '${appDir.path}/$fileName';
      await File(filePath).copy(localFilePath);

      // Refresh the list
      _loadTimetables();
    }
  }

  Future<void> _deleteTimetable(File file) async {
    await file.delete();
    _loadTimetables(); // Refresh the list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1B26),
      appBar: AppBar(
        title: const Text(
          'Exam Timetable',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // PDF Viewer
          if (_selectedPdfPath != null)
            Expanded(
              flex: 2,
              child: PDFView(
                filePath: _selectedPdfPath!,
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
                final File timetable = _timetables[index];
                return ListTile(
                  title: Text(
                    timetable.path.split('/').last,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _deleteTimetable(timetable);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, color: Colors.blue),
                        onPressed: () {
                          setState(() {
                            _selectedPdfPath = timetable.path;
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadTimetable,
        backgroundColor: Colors.white,
        child: const Icon(
          Icons.add,
          color: Colors.black,
        ),
      ),
    );
  }
}