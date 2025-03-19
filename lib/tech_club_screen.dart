import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TechClubScreen extends StatefulWidget {
  const TechClubScreen({super.key});

  @override
  State<TechClubScreen> createState() => _TechClubScreenState();
}

class _TechClubScreenState extends State<TechClubScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  // Fixed: Using null-aware operator to avoid forcing a non-null user.
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1B26),
      appBar: AppBar(
        title: const Text(
          'Tech Club',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tech_club_notices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No notices yet.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final notices = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final notice = notices[index];
              final content = notice['content'];
              final imageUrl = notice['imageUrl'];
              final postedBy = notice['postedBy'];
              final timestamp = notice['timestamp'].toDate();
              final noticeId = notice.id;
              final isPoll = notice['isPoll'] ?? false;
              final pollOptions = notice['pollOptions'] ?? [];
              final pollVotes = notice['pollVotes'] ?? {};

              if (isPoll) {
                return _buildPollCard(
                  noticeId,
                  content,
                  postedBy,
                  timestamp,
                  pollOptions,
                  pollVotes,
                  userId,
                );
              } else {
                return Card(
                  color: const Color(0xFF2A2B3A),
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(
                      content,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null)
                          Image.network(imageUrl),
                        const SizedBox(height: 10),
                        Text(
                          'Posted by: $postedBy',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'Date: ${timestamp.toLocal()}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final userData = snapshot.data!.data() as Map<String, dynamic>;
                          final String role = userData['role'];

                          if (role == 'Teacher' || role == 'Club Coordinator') {
                            return IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _deleteNotice(noticeId);
                              },
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final String role = userData['role'];

            if (role == 'Teacher' || role == 'Club Coordinator') {
              return FloatingActionButton(
                onPressed: () {
                  _showAddNoticeDialog(context);
                },
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

  Widget _buildPollCard(
      String noticeId,
      String content,
      String postedBy,
      DateTime timestamp,
      List<dynamic> pollOptions,
      Map<String, dynamic> pollVotes,
      String userId,
      ) {
    int totalVotes = 0;
    pollVotes.forEach((key, value) {
      if (value is List) {
        totalVotes += value.length;
      }
    });

    return Card(
      color: const Color(0xFF2A2B3A),
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'Posted by: $postedBy',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Date: ${timestamp.toLocal()}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ...pollOptions.map((option) {
              final optionText = option['option'];
              final votes = pollVotes[optionText] is List ? pollVotes[optionText].length : 0;
              final hasVoted = pollVotes.values.any((voters) => voters is List && voters.contains(userId));
              final double progress = totalVotes > 0 ? votes / totalVotes : 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      optionText,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      '$votes votes',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      if (!hasVoted) {
                        _voteInPoll(noticeId, optionText, userId);
                      }
                    },
                  ),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _voteInPoll(String noticeId, String option, String userId) async {
    await FirebaseFirestore.instance.collection('tech_club_notices').doc(noticeId).update({
      'pollVotes.$option': FieldValue.arrayUnion([userId]),
    });
  }

  void _showAddNoticeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AddNoticeDialog(
          onPost: (content, imageUrl, isPoll, pollOptions) async {
            final User? user = FirebaseAuth.instance.currentUser;
            final userId = user!.uid;
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            final userData = userDoc.data() as Map<String, dynamic>;
            final postedBy = userData['name'];

            await FirebaseFirestore.instance.collection('tech_club_notices').add({
              'content': content,
              'imageUrl': imageUrl,
              'postedBy': postedBy,
              'timestamp': DateTime.now(),
              'isPoll': isPoll,
              'pollOptions': isPoll ? pollOptions : [],
              'pollVotes': isPoll ? {} : null,
            });

            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _deleteNotice(String noticeId) async {
    await FirebaseFirestore.instance.collection('tech_club_notices').doc(noticeId).delete();
  }
}

class AddNoticeDialog extends StatefulWidget {
  final Function(String, String?, bool, List<Map<String, String>>) onPost;

  const AddNoticeDialog({super.key, required this.onPost});

  @override
  State<AddNoticeDialog> createState() => _AddNoticeDialogState();
}

class _AddNoticeDialogState extends State<AddNoticeDialog> {
  final TextEditingController contentController = TextEditingController();
  File? imageFile;
  bool isPoll = false;
  final List<Map<String, String>> pollOptions = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2B3A),
      title: const Text(
        'Add Notice',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: contentController,
              decoration: InputDecoration(
                labelText: 'Content',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  setState(() {
                    imageFile = File(pickedFile.path);
                  });
                }
              },
              child: const Text('Add Image'),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text(
                'Is this a poll?',
                style: TextStyle(color: Colors.white),
              ),
              value: isPoll,
              onChanged: (value) {
                setState(() {
                  isPoll = value ?? false;
                });
              },
            ),
            if (isPoll)
              Column(
                children: [
                  ...pollOptions.map((option) {
                    return ListTile(
                      title: Text(
                        option['option']!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            pollOptions.remove(option);
                          });
                        },
                      ),
                    );
                  }).toList(),
                  TextButton(
                    onPressed: () {
                      _addPollOption();
                    },
                    child: const Text(
                      'Add Poll Option',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white),
          ),
        ),
        TextButton(
          onPressed: () async {
            if (contentController.text.isNotEmpty) {
              String? imageUrl;
              if (imageFile != null) {
                final storageRef = FirebaseStorage.instance.ref().child('tech_club_images/${DateTime.now().millisecondsSinceEpoch}');
                await storageRef.putFile(imageFile!);
                imageUrl = await storageRef.getDownloadURL();
              }

              widget.onPost(
                contentController.text,
                imageUrl,
                isPoll,
                pollOptions,
              );
            }
          },
          child: const Text(
            'Post',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _addPollOption() {
    final TextEditingController optionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2B3A),
          title: const Text(
            'Add Poll Option',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: optionController,
            decoration: InputDecoration(
              labelText: 'Option',
              labelStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                if (optionController.text.isNotEmpty) {
                  setState(() {
                    pollOptions.add({'option': optionController.text});
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
