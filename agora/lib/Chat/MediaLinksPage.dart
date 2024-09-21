import 'package:flutter/material.dart' hide CarouselController;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import './ChatView.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:convert';

class MediaAndLinksPage extends StatelessWidget {
  final String conversationId;

  MediaAndLinksPage({required this.conversationId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Media'),
          backgroundColor: Color(0xFF121212),
        ),
        body: _buildMediaGrid(),

        //   TabBar(
        //     overlayColor: WidgetStateProperty.all(Colors.transparent),
        //     labelColor: Colors.blue,
        //     indicatorColor: Colors.blue,
        //     tabs: [
        //       Tab(text: 'Media'),
        //       Tab(text: 'Audio'),
        //       Tab(text: 'Links'),
        //     ],
        //   ),
        // ),
        // backgroundColor: Color(0xFF121212),
        // body: _buildMediaGrid()
        //TabBarView(
        //   children: [
        //     _buildMediaGrid(),
        //     _buildAudioList(),
        //     _buildLinksList(),
        //   ],
        // ),
      ),
    );
  }

  void _showMediaViewer(BuildContext context, Map<String, dynamic> messageData,
      bool isVideo, String senderId) {
    String mediaUrl = '';
    if (isVideo) {
      final customData = messageData['text'] as String? ?? '{}';
      try {
        final decodedData = json.decode(customData);
        mediaUrl = decodedData['videoUrl'] as String? ?? '';
      } catch (e) {
        print('DEBUG: Error decoding video data: $e');
      }
    } else {
      mediaUrl = messageData['mediaUrl'] as String? ??
          messageData['text'] as String? ??
          '';
    }

    print('DEBUG: Media URL in _showMediaViewer: $mediaUrl');

    if (mediaUrl.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<String>(
            future: _getUserName(senderId),
            builder: (context, snapshot) {
              String senderName = snapshot.data ?? 'Unknown';
              return MediaViewerDialog(
                mediaUrl: mediaUrl,
                isVideo: isVideo,
                senderName: senderName,
              );
            },
          );
        },
      );
    } else {
      print('DEBUG: Invalid media URL in _showMediaViewer');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to display media: Invalid URL')),
      );
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String firstName = userData['firstName'] ?? '';
        String lastName = userData['lastName'] ?? '';
        return '$firstName $lastName'.trim();
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return 'Unknown';
  }

  Widget _buildMediaGrid() {
    final Query query = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('messageType', whereIn: ['image', 'video']).orderBy('createdAt',
            descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(fontFamily: 'roboto', color: Colors.white)));
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return Container(
              color: Color(0xFF121212),
              child: Center(
                  child: Text('There are no media files in this chat',
                      style: TextStyle(
                          fontFamily: 'roboto',
                          color: Colors.white,
                          backgroundColor: Color(0xFF121212)))));
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final data = message.data() as Map<String, dynamic>;
            final messageType = data['messageType'] as String;
            final senderId = data['senderId'] as String? ?? 'Unknown';

            String? mediaUrl;
            bool isVideo = false;

            if (messageType == 'image') {
              mediaUrl = data['mediaUrl'] as String? ?? data['text'] as String?;
              print('DEBUG: Image URL for message $index: $mediaUrl');
            } else if (messageType == 'video') {
              try {
                final videoData = json.decode(data['text'] as String? ?? '{}');
                mediaUrl = videoData['thumbnailUrl'] as String?;
                isVideo = true;
                print(
                    'DEBUG: Video thumbnail URL for message $index: $mediaUrl');
              } catch (e) {
                print(
                    'DEBUG: Error decoding video data for message $index: $e');
              }
            }

            if (mediaUrl == null || mediaUrl.isEmpty) {
              print('DEBUG: Invalid media URL for message $index');
              return Center(child: Icon(Icons.error, color: Colors.white));
            }

            return GestureDetector(
              onTap: () => _showMediaViewer(context, data, isVideo, senderId),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: mediaUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) {
                      print(
                          'DEBUG: Error loading image for message $index: $error');
                      return Center(
                          child: Icon(Icons.error, color: Colors.white));
                    },
                  ),
                  if (isVideo)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 24),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAudioList() {
    final Query query = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('messageType', isEqualTo: 'voice')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(fontFamily: 'roboto', color: Colors.white)));
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return Center(
              child: Text('There are no audio messages in this chat',
                  style: TextStyle(fontFamily: 'roboto', color: Colors.white)));
        }

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return ListTile(
              title: Text('Audio Message',
                  style: TextStyle(fontFamily: 'roboto', color: Colors.white)),
              subtitle: Text(message['createdAt'].toDate().toString(),
                  style:
                      TextStyle(fontFamily: 'roboto', color: Colors.white70)),
              leading: Icon(Icons.audiotrack, color: Colors.white),
              onTap: () {
                // Implement audio playback
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLinksList() {
    final Query query = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('messageType', isEqualTo: 'text')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(fontFamily: 'roboto', color: Colors.white)));
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return Center(
              child: Text('There are no links in this chat',
                  style: TextStyle(fontFamily: 'roboto', color: Colors.white)));
        }

        final linkMessages = messages.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final text = data['text'] as String?;
          return text != null && _containsUrl(text);
        }).toList();

        if (linkMessages.isEmpty) {
          return Center(
              child: Text('There are no links in this chat',
                  style: TextStyle(fontFamily: 'roboto', color: Colors.white)));
        }

        return ListView.builder(
          itemCount: linkMessages.length,
          itemBuilder: (context, index) {
            final message = linkMessages[index];
            final data = message.data() as Map<String, dynamic>;
            final text = data['text'] as String;
            final url = _extractUrl(text);

            return Card(
              color: Colors.grey[800],
              child: ListTile(
                title: Text(url,
                    style: TextStyle(
                        fontFamily: 'roboto',
                        color: Colors.blue,
                        decoration: TextDecoration.underline)),
                subtitle: Text(text,
                    style:
                        TextStyle(fontFamily: 'roboto', color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                onTap: () => _launchURL(url),
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _getImageUrl(String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    return await ref.getDownloadURL();
  }

  bool _containsUrl(String text) {
    final urlPattern = RegExp(r'https?://\S+');
    return urlPattern.hasMatch(text);
  }

  String _extractUrl(String text) {
    final urlPattern = RegExp(r'https?://\S+');
    final match = urlPattern.firstMatch(text);
    return match?.group(0) ?? '';
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withOpacity(0.5),
            padding: EdgeInsets.all(20),
            child: Center(
              child: Hero(
                tag: imageUrl,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => CircularProgressIndicator(),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
