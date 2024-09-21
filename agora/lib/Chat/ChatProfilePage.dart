import 'package:flutter/material.dart' hide CarouselController;
import 'package:chatview/chatview.dart';
import './GroupMembersPage.dart';
import './MediaLinksPage.dart';

class ChatProfilePage extends StatelessWidget {
  final String conversationId;
  final List<ChatUser> chatUsers;
  final bool isGroupChat;

  ChatProfilePage({
    required this.conversationId,
    required this.chatUsers,
    required this.isGroupChat,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Profile'),
        backgroundColor: Color(0xFF121212),
      ),
      backgroundColor: Color(0xFF121212),
      body: ListView(
        children: [
          if (isGroupChat)
            ListTile(
              title: Text('See Members', style: TextStyle(color: Colors.white)),
              leading: Icon(Icons.group, color: Colors.white),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        GroupMembersPage(chatUsers: chatUsers),
                  ),
                );
              },
            ),
          ListTile(
            selectedColor: Colors.transparent,
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            selectedTileColor: Colors.transparent,
            title: Text('View Media', style: TextStyle(color: Colors.white)),
            leading: Icon(Icons.photo_library, color: Colors.white),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MediaAndLinksPage(conversationId: conversationId),
                ),
              );
            },
          ),
          // Add more options here as needed
        ],
      ),
    );
  }
}
