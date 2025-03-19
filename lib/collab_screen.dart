import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CollabScreen extends StatefulWidget {
  const CollabScreen({super.key});

  @override
  State<CollabScreen> createState() => _CollabScreenState();
}

class _CollabScreenState extends State<CollabScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _pollOptionController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  bool _isPoll = false;
  final List<Map<String, String>> _pollOptions = [];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.isEmpty && _imageFile == null && !_isPoll) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some content or add an image/poll.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      if (_imageFile != null) {
        final Reference storageRef = _storage.ref().child('collab_images/${DateTime.now().millisecondsSinceEpoch}');
        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }

      // Fetch user details from Firestore
      final userDoc = await _firestore.collection('users').doc(_user?.uid).get();
      final userName = userDoc.data()?['name'] ?? _user?.displayName ?? 'Anonymous';
      final userRole = userDoc.data()?['role'] ?? 'User';

      // Prepare post data
      final postData = {
        'userId': _user?.uid,
        'userName': userName,
        'userRole': userRole,
        'content': _postController.text,
        'type': _isPoll ? 'poll' : (_imageFile != null ? 'image' : 'text'),
        'imageUrl': imageUrl,
        'pollOptions': _isPoll
            ? _pollOptions.map((option) => {'option': option['option'], 'votes': []}).toList()
            : null,
        'likes': [],
        'comments': [],
        'timestamp': DateTime.now(),
      };

      // Debugging: Print post data
      print('Post Data: $postData');

      // Add post to Firestore
      await _firestore.collection('collab_posts').add(postData);

      // Clear form
      _postController.clear();
      setState(() {
        _imageFile = null;
        _isPoll = false;
        _pollOptions.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('collab_posts').doc(postId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _likePost(String postId, List<String> likes) async {
    if (likes.contains(_user?.uid)) {
      await _firestore.collection('collab_posts').doc(postId).update({
        'likes': FieldValue.arrayRemove([_user?.uid]),
      });
    } else {
      await _firestore.collection('collab_posts').doc(postId).update({
        'likes': FieldValue.arrayUnion([_user?.uid]),
      });
    }
  }

  Future<void> _addComment(String postId, String comment) async {
    if (comment.isEmpty) return;

    await _firestore.collection('collab_posts').doc(postId).update({
      'comments': FieldValue.arrayUnion([
        {
          'userId': _user?.uid,
          'userName': _user?.displayName ?? 'Anonymous',
          'text': comment,
        }
      ]),
    });
  }

  Future<void> _voteInPoll(String postId, String option) async {
    await _firestore.collection('collab_posts').doc(postId).update({
      'pollOptions': FieldValue.arrayUnion([{'option': option, 'votes': [_user?.uid]}]),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1B26),
      appBar: AppBar(
        title: const Text(
          'Collab',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Posts Feed
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('collab_posts').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No posts yet.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final posts = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final postId = post.id;
                    final data = post.data() as Map<String, dynamic>;
                    final userName = data['userName'] ?? 'Anonymous'; // Handle null
                    final userRole = data['userRole'] ?? 'User'; // Handle null
                    final content = data['content'] ?? ''; // Handle null
                    final type = data['type'] ?? 'text'; // Handle null
                    final imageUrl = data['imageUrl']; // Can be null
                    final pollOptions = data['pollOptions'] ?? []; // Handle null
                    final likes = List<String>.from(data['likes'] ?? []); // Handle null
                    final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []); // Handle null

                    return Card(
                      color: const Color(0xFF2A2B3A),
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.person,
                                    size: 25,
                                    color: const Color(0xFF1A1B26),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      userRole,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (_user?.uid == data['userId'])
                                  IconButton(
                                    onPressed: () => _deletePost(postId),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (type == 'text')
                              Text(
                                content,
                                style: const TextStyle(color: Colors.white),
                              ),
                            if (type == 'image' && imageUrl != null)
                              Image.network(imageUrl),
                            if (type == 'poll')
                              Column(
                                children: [
                                  Text(
                                    content,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 10),
                                  ...pollOptions.map<Widget>((option) {
                                    final optionText = option['option'] ?? ''; // Handle null
                                    final votes = List<String>.from(option['votes'] ?? []); // Handle null
                                    final progress = votes.length / (likes.isNotEmpty ? likes.length : 1);

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          title: Text(
                                            optionText,
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          trailing: Text(
                                            '${votes.length} votes',
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                          onTap: () {
                                            _voteInPoll(postId, optionText);
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _likePost(postId, likes),
                                  icon: Icon(
                                    likes.contains(_user?.uid) ? Icons.favorite : Icons.favorite_border,
                                    color: likes.contains(_user?.uid) ? Colors.red : Colors.white,
                                  ),
                                ),
                                Text(
                                  '${likes.length} Likes',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(width: 20),
                                IconButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          backgroundColor: const Color(0xFF2A2B3A),
                                          title: const Text(
                                            'Add Comment',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          content: TextField(
                                            controller: _commentController,
                                            decoration: InputDecoration(
                                              labelText: 'Comment',
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
                                                _addComment(postId, _commentController.text);
                                                _commentController.clear();
                                                Navigator.pop(context);
                                              },
                                              child: const Text(
                                                'Post',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.comment, color: Colors.white),
                                ),
                                Text(
                                  '${comments.length} Comments',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            if (comments.isNotEmpty)
                              Column(
                                children: comments.map<Widget>((comment) {
                                  return ListTile(
                                    title: Text(
                                      comment['userName'] ?? 'Anonymous', // Handle null
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      comment['text'] ?? '', // Handle null
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Post Creation Form at the Bottom
          Container(
            color: const Color(0xFF2A2B3A),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _postController,
                  decoration: InputDecoration(
                    labelText: 'What\'s on your mind?',
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
                const SizedBox(height: 10),
                if (_isPoll)
                  Column(
                    children: [
                      ..._pollOptions.map((option) {
                        return ListTile(
                          title: Text(
                            option['option']!,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _pollOptions.remove(option);
                              });
                            },
                          ),
                        );
                      }).toList(),
                      TextButton(
                        onPressed: () {
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
                                  controller: _pollOptionController,
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
                                      if (_pollOptionController.text.isNotEmpty) {
                                        setState(() {
                                          _pollOptions.add({'option': _pollOptionController.text});
                                        });
                                        _pollOptionController.clear();
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
                        },
                        child: const Text(
                          'Add Poll Option',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isPoll = !_isPoll;
                        });
                      },
                      icon: const Icon(Icons.poll, color: Colors.white),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                        'Post',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}