import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:info_sphere/tech_club_screen.dart';
import 'dart:io'; // Import the shared dialog

class CulturalClubScreen extends StatefulWidget {
  const CulturalClubScreen({super.key});

  @override
  State<CulturalClubScreen> createState() => _CulturalClubScreenState();
}

class _CulturalClubScreenState extends State<CulturalClubScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1B26),
      appBar: AppBar(
        title: const Text('Cultural Club', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cultural_club_notices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notices yet.', style: TextStyle(color: Colors.white)));
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
                    title: Text(content, style: const TextStyle(color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null) Image.network(imageUrl),
                        const SizedBox(height: 10),
                        Text('Posted by: $postedBy', style: const TextStyle(color: Colors.grey)),
                        Text('Date: ${timestamp.toLocal()}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    trailing: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
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
          if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final String role = userData['role'];
            if (role == 'Teacher' || role == 'Club Coordinator') {
              return FloatingActionButton(
                onPressed: () {
                  _showAddNoticeDialog(context);
                },
                backgroundColor: Colors.white,
                child: const Icon(Icons.add, color: Colors.black),
              );
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPollCard(String noticeId, String content, String postedBy, DateTime timestamp,
      List<dynamic> pollOptions, Map<String, dynamic> pollVotes, String userId) {
    int totalVotes = 0;
    pollVotes.forEach((key, value) {
      if (value is List) totalVotes += value.length;
    });
    return Card(
      color: const Color(0xFF2A2B3A),
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content, style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 10),
            Text('Posted by: $postedBy', style: const TextStyle(color: Colors.grey)),
            Text('Date: ${timestamp.toLocal()}', style: const TextStyle(color: Colors.grey)),
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
                    title: Text(optionText, style: const TextStyle(color: Colors.white)),
                    trailing: Text('$votes votes', style: const TextStyle(color: Colors.grey)),
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
    await FirebaseFirestore.instance.collection('cultural_club_notices').doc(noticeId).update({
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
            await FirebaseFirestore.instance.collection('cultural_club_notices').add({
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
    await FirebaseFirestore.instance.collection('cultural_club_notices').doc(noticeId).delete();
  }
}