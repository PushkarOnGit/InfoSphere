import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BranchNoticeBoardScreen extends StatefulWidget {
  const BranchNoticeBoardScreen({super.key});

  @override
  State<BranchNoticeBoardScreen> createState() => _BranchNoticeBoardScreenState();
}

class _BranchNoticeBoardScreenState extends State<BranchNoticeBoardScreen> {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String userId = user!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1B26), // Background color #1a1b26
      appBar: AppBar(
        title: const Text(
          'Branch Notice Board',
          style: TextStyle(color: Colors.white), // White text for AppBar title
        ),
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // White icons
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('branch_notices') // Use branch_notices collection
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
                'No branch-specific notices yet.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final notices = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final notice = notices[index];
              final type = notice['type'];
              final content = notice['content'];
              final imageUrl = notice['imageUrl'];
              final postedBy = notice['postedBy'];
              final timestamp = notice['timestamp'].toDate();
              final eventDate = notice['eventDate']?.toDate();
              final eventTitle = notice['eventTitle'];
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
                  color: const Color(0xFF2A2B3A), // Darker shade for cards
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
                        if (eventTitle != null)
                          Text(
                            'Event: $eventTitle',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        if (eventDate != null)
                          Text(
                            'Event Date: ${eventDate.toLocal()}',
                            style: const TextStyle(color: Colors.grey),
                          ),
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

                          if (role == 'Teacher') {
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

            if (role == 'Teacher') {
              return FloatingActionButton(
                onPressed: () {
                  _showAddNoticeDialog(context);
                },
                backgroundColor: Colors.white, // White FAB
                child: const Icon(
                  Icons.add,
                  color: Colors.black, // Black plus icon
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // Build a poll card
  Widget _buildPollCard(
      String noticeId,
      String content,
      String postedBy,
      DateTime timestamp,
      List<dynamic> pollOptions,
      Map<String, dynamic> pollVotes,
      String userId,
      ) {
    // Calculate total votes
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

  // Vote in a poll
  void _voteInPoll(String noticeId, String option, String userId) async {
    await FirebaseFirestore.instance.collection('branch_notices').doc(noticeId).update({
      'pollVotes.$option': FieldValue.arrayUnion([userId]),
    });
  }

  // Show dialog to add a notice or poll
  void _showAddNoticeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AddNoticeDialog(
          onPost: (content, eventTitle, eventDate, imageUrl, isEventNotice, isPoll, pollOptions) async {
            final User? user = FirebaseAuth.instance.currentUser;
            final userId = user!.uid;
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            final userData = userDoc.data() as Map<String, dynamic>;
            final postedBy = userData['name'];
            final role = userData['role'];

            await FirebaseFirestore.instance.collection('branch_notices').add({
              'type': 'notice',
              'content': content,
              'eventTitle': isEventNotice ? eventTitle : null,
              'eventDate': isEventNotice ? eventDate : null,
              'imageUrl': imageUrl,
              'postedBy': postedBy,
              'role': role,
              'timestamp': DateTime.now(),
              'isEventNotice': isEventNotice,
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

  // Delete a notice
  void _deleteNotice(String noticeId) async {
    await FirebaseFirestore.instance.collection('branch_notices').doc(noticeId).delete();
  }
}

class AddNoticeDialog extends StatefulWidget {
  final Function(String, String?, DateTime?, String?, bool, bool, List<Map<String, String>>) onPost;

  const AddNoticeDialog({super.key, required this.onPost});

  @override
  State<AddNoticeDialog> createState() => _AddNoticeDialogState();
}

class _AddNoticeDialogState extends State<AddNoticeDialog> {
  final TextEditingController contentController = TextEditingController();
  final TextEditingController eventTitleController = TextEditingController();
  final TextEditingController eventDateController = TextEditingController();
  File? imageFile;
  DateTime? eventDate;
  bool isEventNotice = false; // Checkbox for event notices
  bool isPoll = false; // Checkbox for polls
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
            // Checkbox for event notice
            CheckboxListTile(
              title: const Text(
                'Is this an event notice?',
                style: TextStyle(color: Colors.white),
              ),
              value: isEventNotice,
              onChanged: (value) {
                setState(() {
                  isEventNotice = value ?? false;
                });
              },
            ),
            const SizedBox(height: 20),

            // Checkbox for poll
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
            const SizedBox(height: 20),

            // Content field
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

            // Event title field (only for event notices)
            if (isEventNotice)
              TextField(
                controller: eventTitleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
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
            if (isEventNotice) const SizedBox(height: 20),

            // Event date field (only for event notices)
            if (isEventNotice)
              TextField(
                controller: eventDateController,
                decoration: InputDecoration(
                  labelText: 'Event Date',
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
                onTap: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (selectedDate != null) {
                    final selectedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (selectedTime != null) {
                      setState(() {
                        eventDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        eventDateController.text = eventDate.toString();
                      });
                    }
                  }
                },
              ),
            if (isEventNotice) const SizedBox(height: 20),

            // Add poll options (only for polls)
            if (isPoll)
              Column(
                children: [
                  const Text(
                    'Poll Options',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
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
            if (isPoll) const SizedBox(height: 20),

            // Add image button
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
              widget.onPost(
                contentController.text,
                isEventNotice ? eventTitleController.text : null,
                isEventNotice ? eventDate : null,
                imageFile != null ? 'Upload logic here' : null,
                isEventNotice,
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

  // Add a poll option
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