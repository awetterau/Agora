import 'package:flutter/material.dart' hide CarouselController;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './Events/CalendarPage.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import './Events/NwEventDetailsPage.dart';
import './Chat/ChatView.dart';
import './Profiles/ProfilePage.dart';
import './Organization/newOrganizationPage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import './AuthFlow/AuthFlow.dart';
import 'package:flutter/services.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;
late Stream<DocumentSnapshot> _eventStream;
late Stream<QuerySnapshot> _membersStream;
bool isConductOfficer = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ErrorBoundary(child: ProviderScope(child: MyApp())));
}

class FriendSearchPage extends StatefulWidget {
  @override
  _FriendSearchPageState createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final usernameResults = await _firestore
        .collection('users')
        .where('username'.toLowerCase(),
            isGreaterThanOrEqualTo: query.toLowerCase())
        .where('username'.toLowerCase(), isLessThan: query + 'z'.toLowerCase())
        .get();

    final displayNameResults = await _firestore
        .collection('users')
        .where('displayName'.toLowerCase(),
            isGreaterThanOrEqualTo: query.toLowerCase())
        .where('displayName'.toLowerCase(),
            isLessThan: query + 'z'.toLowerCase())
        .get();

    setState(() {
      _searchResults = [...usernameResults.docs, ...displayNameResults.docs]
          .toSet()
          .toList(); // Remove duplicates
    });
  }

  void _sendFriendRequest(String friendId) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Check if a request already exists
    final existingRequest = await _firestore
        .collection('friendRequests')
        .where('senderId', isEqualTo: currentUserId)
        .where('receiverId', isEqualTo: friendId)
        .get();

    if (existingRequest.docs.isEmpty) {
      await _firestore.collection('friendRequests').add({
        'senderId': currentUserId,
        'receiverId': friendId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request already sent')),
      );
    }
  }

  void _viewProfile(DocumentSnapshot user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemberProfilePage(userId: user.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Color(0xFF121212),
        child: Column(
          children: [
            AppBar(backgroundColor: Color(0xFF121212), title: Text('Search')),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: TextField(
                cursorColor: Colors.white,
                controller: _searchController,
                decoration: const InputDecoration(
                  focusColor: Colors.blue,
                  floatingLabelStyle: TextStyle(color: Colors.white),
                  hoverColor: Colors.white,
                  labelText: 'Search for users',
                  suffixIcon: Icon(Icons.search),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                onChanged: _searchUsers,
              ),
            ),
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(child: Text('No results'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          title: Text(user['displayName']),
                          subtitle: Text(
                              '@${user['username']} |  ${user['schoolName'] ?? 'No organization'} | ${user['greekOrganizationName'] ?? 'No organization'} '),
                          trailing: IconButton(
                            icon: Icon(Icons.person_add),
                            onPressed: () => _sendFriendRequest(user.id),
                          ),
                          onTap: () => _viewProfile(user),
                        );
                      },
                    ),
            ),
          ],
        ));
  }
}

class ChatListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        title: Text('Messages',
            style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Theme.of(context).iconTheme.color),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => NewConversationPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: Text('No conversations yet'));
                }
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) {
                  return Center(child: Text('User data is null'));
                }
                final conversationIds =
                    List<String>.from(userData['conversations'] ?? []);

                return FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait(conversationIds.map((id) =>
                      FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(id)
                          .get())),
                  builder: (context, conversationsSnapshot) {
                    if (!conversationsSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final conversations = conversationsSnapshot.data!
                        .where((doc) => doc.exists && doc.data() != null)
                        .toList();

                    conversations.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTimestamp =
                          aData['lastMessageTimestamp'] as Timestamp?;
                      final bTimestamp =
                          bData['lastMessageTimestamp'] as Timestamp?;
                      if (aTimestamp == null && bTimestamp == null) return 0;
                      if (aTimestamp == null) return 1;
                      if (bTimestamp == null) return -1;
                      return bTimestamp.compareTo(aTimestamp);
                    });

                    return ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversationData = conversations[index].data()
                            as Map<String, dynamic>?;
                        if (conversationData == null) {
                          return SizedBox.shrink(); // Skip null conversations
                        }
                        return _buildConversationTile(
                            context, conversationData, currentUserId);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context,
      Map<String, dynamic> conversation, String currentUserId) {
    final List<dynamic> participants = conversation['participants'] ?? [];
    final otherParticipants =
        participants.where((id) => id != currentUserId).toList();
    final isGroupChat = otherParticipants.length > 1;

    return FutureBuilder<List<DocumentSnapshot>>(
        future: Future.wait(otherParticipants.map((id) =>
            FirebaseFirestore.instance.collection('users').doc(id).get())),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return ListTile(title: Text('Loading...'));

          final otherUsers = snapshot.data!;
          final names = otherUsers
              .map((user) {
                final userData = user.data() as Map<String, dynamic>?;
                return userData?['firstName'] as String? ?? 'Unknown';
              })
              .where((name) => name != null)
              .toList();
          final displayName = isGroupChat
              ? (conversation['name'] ??
                  '${names.take(3).join(", ")}${names.length > 3 ? "..." : ""}')
              : names.first;

          Widget buildProfilePicture() {
            if (isGroupChat) {
              // For group chats, we'll use the first user's profile picture
              final firstUserData =
                  otherUsers.first.data() as Map<String, dynamic>?;
              final profileImageUrl =
                  firstUserData?['profileImageUrl'] as String?;
              return _buildProfileImage(profileImageUrl, displayName);
            } else {
              final userData = otherUsers.first.data() as Map<String, dynamic>?;
              final profileImageUrl = userData?['profileImageUrl'] as String?;
              return _buildProfileImage(profileImageUrl, displayName);
            }
          }

          return ListTile(
              leading: buildProfilePicture(),
              title: Text(displayName,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Row(
                children: [
                  Icon(Icons.check, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      conversation['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              trailing: conversation['lastMessageTimestamp'] != null
                  ? Text(
                      DateFormat.jm().format(
                          (conversation['lastMessageTimestamp'] as Timestamp)
                              .toDate()),
                      style: TextStyle(color: Colors.grey),
                    )
                  : null,
              onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatViewPage(
                        conversationId: conversation['id'],
                        currentUserId: FirebaseAuth.instance.currentUser!.uid,
                      ),
                    ),
                  ));
        });
  }

  Widget _buildProfileImage(String? profileImageUrl, String displayName) {
    return CircleAvatar(
      backgroundColor: _generateAvatarColor(displayName),
      child: profileImageUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: profileImageUrl,
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => Text(
                  displayName[0].toUpperCase(),
                  style: TextStyle(color: Colors.white),
                ),
                fit: BoxFit.cover,
                width: 40,
                height: 40,
              ),
            )
          : Text(
              displayName[0].toUpperCase(),
              style: TextStyle(color: Colors.white),
            ),
    );
  }

  Color _generateAvatarColor(String input) {
    final hue = input.hashCode % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.8).toColor();
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<Widget> _widgetOptions = [
    TestEventsPage(),
    ChatListPage(),
    newPhiKappaTauPage(),
    newProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Scaffold(
        body: _widgetOptions.elementAt(_selectedIndex),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Color(0xFF121212),
            border: Border(
              top: BorderSide(
                color: Color(0xFF1E1E1E),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, 0),
                  _buildNavItem(CupertinoIcons.chat_bubble, 1),
                  _buildNavItem(CupertinoIcons.person_2, 2),
                  _buildNavItem(CupertinoIcons.person, 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    return IconButton(
      highlightColor: Color(0xFF121212),
      icon: Icon(
        icon,
        size: index == 0 ? 30 : 25,
        color: _selectedIndex == index ? AgoraTheme.accentColor : Colors.grey,
      ),
      onPressed: () => _onItemTapped(index),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      title: 'Greek Life App',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        textTheme: TextTheme(
          bodySmall: TextStyle(color: Colors.black),
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: TextTheme(
          bodySmall: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.data != null) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(snapshot.data!.uid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.done) {
                    Map<String, dynamic>? userData =
                        userSnapshot.data?.data() as Map<String, dynamic>?;
                    if (userData != null) {
                      return HomePage();
                    } else {
                      return AgoraAuthFlow();
                    }
                  }
                  return Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              );
            } else {
              return AgoraAuthFlow();
            }
          }
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 2,
              ),
            ),
          );
        },
      ),
    );
  }
}

final themeProvider = StateProvider((ref) => ThemeMode.dark);

class NewConversationPage extends StatefulWidget {
  @override
  _NewConversationPageState createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  List<String> _selectedUsers = [];
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text('New Conversation'),
        backgroundColor: Color(0xFF121212),
        actions: [
          TextButton(
            child: Text('Create', style: TextStyle(color: Colors.white)),
            onPressed: _selectedUsers.isNotEmpty
                ? _createOrNavigateToConversation
                : null,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final user = snapshot.data!.docs[index];
              if (user.id == currentUserId) return SizedBox.shrink();
              final userData = user.data() as Map<String, dynamic>;
              final String fullName =
                  userData['firstName'] + ' ' + userData['lastName'];
              return CheckboxListTile(
                title: Text(fullName),
                value: _selectedUsers.contains(user.id),
                onChanged: (bool? value) {
                  setState(() {
                    if (value!) {
                      _selectedUsers.add(user.id);
                    } else {
                      _selectedUsers.remove(user.id);
                    }
                  });
                },
                secondary: CircleAvatar(
                  backgroundColor: _generateAvatarColor(fullName),
                  child: userData['profileImageUrl'] != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: userData['profileImageUrl'],
                            placeholder: (context, url) =>
                                CircularProgressIndicator(),
                            errorWidget: (context, url, error) => Text(
                              fullName[0].toUpperCase(),
                              style: TextStyle(color: Colors.white),
                            ),
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                          ),
                        )
                      : Text(
                          fullName[0].toUpperCase(),
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _generateAvatarColor(String input) {
    final hue = input.hashCode % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.8).toColor();
  }

  void _createOrNavigateToConversation() async {
    try {
      final participants = [..._selectedUsers, currentUserId];
      participants.sort(); // Sort to ensure consistent ordering

      // Check if a conversation already exists with these participants
      final existingConversationQuery = await _firestore
          .collection('conversations')
          .where('participants', isEqualTo: participants)
          .get();
      final conversationRef = await _firestore.collection('conversations').add({
        'participants': participants,
        'name': _selectedUsers.length > 1 ? "Group Chat" : null,
        'lastMessage': null,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'admin': _selectedUsers.length > 1 ? currentUserId : null,
      });

      if (existingConversationQuery.docs.isNotEmpty) {
        // Conversation already exists, navigate to it
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatViewPage(
              conversationId: conversationRef.id,
              currentUserId: currentUserId,
            ),
          ),
        );
        return;
      }

      // Generate conversation name
      final userDocs = await Future.wait(_selectedUsers
          .map((id) => _firestore.collection('users').doc(id).get()));
      final names = userDocs.map((doc) {
        final userData = doc.data();
        if (userData == null)
          throw Exception('User data is null for user ${doc.id}');
        return userData['firstName'] as String;
      }).toList();
      final conversationName = names.length <= 3
          ? names.join(', ')
          : '${names.take(3).join(', ')}...';

      // Create the conversation document
      final conversationData = {
        'id': conversationRef.id,
        'participants': participants,
        'name': _selectedUsers.length > 1 ? conversationName : null,
        'lastMessage': null,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'admin': _selectedUsers.length > 1 ? currentUserId : null,
      };

      await conversationRef.set(conversationData);

      // Add conversation reference to each participant's user document
      await Future.wait(participants
          .map((userId) => _firestore.collection('users').doc(userId).update({
                'conversations': FieldValue.arrayUnion([conversationRef.id])
              })));

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatViewPage(
            conversationId: conversationRef.id,
            currentUserId: currentUserId,
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('Error creating conversation: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to create conversation. Please try again.')),
      );
    }
  }
}

final eventsProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final now = DateTime.now();
  return FirebaseFirestore.instance
      .collection('events')
      .where('endDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
      .orderBy('endDateTime', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

class TestEventsPage extends ConsumerStatefulWidget {
  @override
  _TestEventsPageState createState() => _TestEventsPageState();
}

class _TestEventsPageState extends ConsumerState<TestEventsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final eventsAsyncValue = ref.watch(eventsProvider);

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(context),
            Expanded(
              child: eventsAsyncValue.when(
                loading: () => Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (events) {
                  final filteredEvents = events.where((event) {
                    final eventData = event.data() as Map<String, dynamic>;
                    final name = eventData['name'] as String;
                    return name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                  }).toList();

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      return EventCard(event: filteredEvents[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Events',
                style: GoogleFonts.roboto(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: Icon(CupertinoIcons.calendar, size: 30),
                color: Colors.white,
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CalendarPage(),
                  ));
                },
              ),
            ],
          ),
          SizedBox(height: 5),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextField(
              style: GoogleFonts.roboto(color: Colors.white),
              textAlignVertical: TextAlignVertical.center,
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search events',
                hintStyle: GoogleFonts.roboto(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final DocumentSnapshot event;

  const EventCard({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eventData = event.data() as Map<String, dynamic>;
    final name = eventData['name'] as String;
    final dateTime = (eventData['startDateTime'] as Timestamp).toDate();
    final imageUrl = eventData['imageUrl'] as String?;

    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => newEventDetailsPage(eventId: event.id),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    Image.network(
                      imageUrl ?? '',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Color(0xFF2C2C2C),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.tealAccent,
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF121212).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              DateFormat('MMM d').format(dateTime),
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 20, bottom: 15, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 0),
                    Text(
                      name,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey[400]),
                        SizedBox(width: 5),
                        Text(
                          DateFormat('h:mm a').format(dateTime),
                          style: GoogleFonts.roboto(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 15),
                        Spacer(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}

class AgoraAuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGORA',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF1A2634),
        scaffoldBackgroundColor: Color(0xFF1A2634),
        fontFamily: 'PeakSans',
      ),
      home: AuthScreen(),
    );
  }
}

class AuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A2634),
              Color(0xFF2C3E50),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 80),
                Text(
                  'AGORA',
                  style: TextStyle(
                    fontFamily: 'PeakSans',
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Where Ideas Converge',
                  style: TextStyle(
                    fontFamily: 'PeakSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                Spacer(),
                AuthTextField(hint: 'Username'),
                SizedBox(height: 16),
                AuthTextField(hint: 'Password', isPassword: true),
                SizedBox(height: 24),
                AuthButton(
                  text: 'SIGN IN',
                  onPressed: () {
                    // TODO: Implement sign in logic
                  },
                ),
                SizedBox(height: 16),
                AuthButton(
                  text: 'SIGN UP',
                  onPressed: () {
                    // TODO: Implement sign up logic
                  },
                  isOutlined: true,
                ),
                SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password logic
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontFamily: 'PeakSans',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  final String hint;
  final bool isPassword;

  const AuthTextField({
    Key? key,
    required this.hint,
    this.isPassword = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: isPassword,
      style: TextStyle(fontFamily: 'PeakSans', color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'PeakSans', color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(
          isPassword ? Icons.lock_outline : Icons.person_outline,
          color: Colors.white54,
        ),
      ),
    );
  }
}

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isOutlined;

  const AuthButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isOutlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'PeakSans',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isOutlined ? Color(0xFF4A90E2) : Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutlined ? Colors.transparent : Color(0xFF4A90E2),
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: Color(0xFF4A90E2),
            width: isOutlined ? 2 : 0,
          ),
        ),
      ),
    );
  }
}

class TestAuthFlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agora',
      theme: ThemeData(
        primaryColor: Color(0xFF1E1E1E),
        hintColor: Color(0xFFE0E0E0),
        scaffoldBackgroundColor: Color(0xFF121212),
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
      ),
      home: WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'AGORA',
                  style: GoogleFonts.vollkorn(
                    fontSize: 64,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48.0),
                Text(
                  'Welcome to the forum of ideas',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 64.0),
                ElevatedButton(
                  child: Text('Sign In'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Color(0xFF1E1E1E),
                    backgroundColor: Color(0xFFE0E0E0),
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    textStyle:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignInScreen()),
                  ),
                ),
                SizedBox(height: 16.0),
                OutlinedButton(
                  child: Text('Sign Up'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFFE0E0E0),
                    side: BorderSide(color: Color(0xFFE0E0E0)),
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    textStyle:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignInScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SophisticatedTextField(hint: 'Email'),
            SizedBox(height: 16.0),
            SophisticatedTextField(hint: 'Password', isPassword: true),
            SizedBox(height: 24.0),
            ElevatedButton(
              child: Text('Sign In'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Color(0xFF1E1E1E),
                backgroundColor: Color(0xFFE0E0E0),
                padding: EdgeInsets.symmetric(vertical: 16.0),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Implement sign in logic
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SophisticatedTextField(hint: 'Name'),
            SizedBox(height: 16.0),
            SophisticatedTextField(hint: 'Email'),
            SizedBox(height: 16.0),
            SophisticatedTextField(hint: 'Password', isPassword: true),
            SizedBox(height: 24.0),
            ElevatedButton(
              child: Text('Sign Up'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Color(0xFF1E1E1E),
                backgroundColor: Color(0xFFE0E0E0),
                padding: EdgeInsets.symmetric(vertical: 16.0),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Implement sign up logic
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SophisticatedTextField extends StatelessWidget {
  final String hint;
  final bool isPassword;

  SophisticatedTextField({required this.hint, this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        obscureText: isPassword,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white54),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
