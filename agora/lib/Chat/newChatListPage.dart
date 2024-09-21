import 'package:flutter/material.dart' hide CarouselController;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class newChatListPage extends StatelessWidget {
  final List<ChatPreview> chats = [
    ChatPreview(
      name: 'JOHN SMITH',
      lastMessage: 'Hey bro, are you coming to the party tonight?',
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
      unreadCount: 2,
      isOnline: true,
    ),
    ChatPreview(
      name: 'ALPHA BETA GAMMA',
      lastMessage: 'Don\'t forget about the chapter meeting tomorrow!',
      timestamp: DateTime.now().subtract(Duration(hours: 2)),
      unreadCount: 0,
      isOnline: false,
    ),
    ChatPreview(
      name: 'SARAH JOHNSON',
      lastMessage: 'Can you help me with the philanthropy event?',
      timestamp: DateTime.now().subtract(Duration(days: 1)),
      unreadCount: 5,
      isOnline: true,
    ),
    ChatPreview(
      name: 'MIKE THOMPSON',
      lastMessage: 'Dude, that party last night was epic!',
      timestamp: DateTime.now().subtract(Duration(days: 2)),
      unreadCount: 0,
      isOnline: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E2023), Color(0xFF23272B)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'MESSAGES',
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2C3E50), Color(0xFF1E2023)],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.message,
                        size: 50,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.search, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'RECENT CONVERSATIONS',
                    style: GoogleFonts.oswald(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return ChatPreviewTile(chat: chats[index]);
                  },
                  childCount: chats.length,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
        backgroundColor: Color(0xFFD4AF37),
      ),
    );
  }
}

class ChatPreviewTile extends StatelessWidget {
  final ChatPreview chat;

  const ChatPreviewTile({Key? key, required this.chat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage('https://picsum.photos/200'),
              ),
              if (chat.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF2C3E50), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            chat.name,
            style: GoogleFonts.oswald(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            chat.lastMessage,
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              color: Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(chat.timestamp),
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              SizedBox(height: 4),
              if (chat.unreadCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    chat.unreadCount.toString(),
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            // Navigate to chat detail page
          },
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class ChatPreview {
  final String name;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;

  ChatPreview({
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
  });
}
