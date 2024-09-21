import 'package:flutter/material.dart' hide CarouselController;
import 'package:chatview/chatview.dart';

class GroupMembersPage extends StatelessWidget {
  final List<ChatUser> chatUsers;

  GroupMembersPage({required this.chatUsers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Members'),
        backgroundColor: Colors.grey[850],
      ),
      backgroundColor: Colors.grey[900],
      body: ListView.builder(
        itemCount: chatUsers.length,
        itemBuilder: (context, index) {
          final user = chatUsers[index];
          return ListTile(
            leading: (user.profilePhoto!.isEmpty || user.profilePhoto == null)
                ? CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      user.name[0].toUpperCase(),
                      style:
                          TextStyle(fontFamily: 'roboto', color: Colors.white),
                    ),
                  )
                : CircleAvatar(
                    backgroundImage: NetworkImage(user.profilePhoto!),
                  ),
            title: Text(user.name,
                style: TextStyle(fontFamily: 'roboto', color: Colors.white)),
            // Add more user details or actions here if needed
          );
        },
      ),
    );
  }
}
