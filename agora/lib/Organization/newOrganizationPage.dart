import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Events/EventCreationPage.dart';
import './AttendanceStatsPage.dart';
import './RoleManagementPage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../Events/NwEventDetailsPage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class newPhiKappaTauPage extends StatefulWidget {
  final bool isAdmin;

  newPhiKappaTauPage({this.isAdmin = true});

  @override
  _newPhiKappaTauPageState createState() => _newPhiKappaTauPageState();
}

class _newPhiKappaTauPageState extends State<newPhiKappaTauPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _showAllEvents = false;
  List<String> _userPermissions = [];
  Widget? _eventCarousel;
  Widget? _eventList;

  @override
  void initState() {
    super.initState();
    _fetchUserPermissions();
    _preloadEventViews();
  }

  void _preloadEventViews() {
    _eventCarousel = _buildEventCarousel();
    _eventList = _buildEventList();
  }

  Future<void> _fetchUserPermissions() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print('No user signed in');
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      if (userData != null) {
        final chapterDoc = await _firestore
            .collection('chapters')
            .doc("aY3G5VjQhGlRTzMn8Boa")
            .get();
        final chapterRoles =
            List<Map<String, dynamic>>.from(chapterDoc.data()?['roles'] ?? []);

        for (var role in chapterRoles) {
          if ((role['memberIds']).contains(user.uid)) {
            _userPermissions.addAll(List<String>.from(role['permissions']));
          }
        }
      }

      setState(() {});
    } catch (e) {
      print('Error fetching user permissions: $e');
    }
  }

  bool _hasPermission(String permission) {
    return _userPermissions.contains(permission);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEventsSection(),
                    SizedBox(height: 16),
                    _buildMembersSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          var top = constraints.biggest.height;
          var flexibleSpaceHeight = 200; // Same as expandedHeight
          var collapsedHeight = kToolbarHeight; // Standard AppBar height

          // Calculate the percentage of collapse
          var percentCollapsed = (flexibleSpaceHeight - top) /
              (flexibleSpaceHeight - collapsedHeight);

          return FlexibleSpaceBar(
            title: Text(
              'Phi Kappa Tau',
              style: TextStyle(
                fontFamily: 'roboto',
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1770&q=80',
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(percentCollapsed),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        if (_hasPermission('Manage Events') || _hasPermission('Manage Roles'))
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              _showActionSheet(context);
            },
          ),
      ],
    );
  }

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Events',
              style: TextStyle(
                fontFamily: 'roboto',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _showAllEvents = !_showAllEvents;
                });
              },
              child: Text(
                _showAllEvents ? 'Show Less' : 'Show All',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _showAllEvents ? _eventList : _eventCarousel,
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Actives',
              style: TextStyle(
                fontFamily: 'roboto',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllMembersPage(),
                  ),
                );
              },
              child: Text(
                'View All',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildFeaturedMembers(),
      ],
    );
  }

  Widget _buildEventCarousel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .where('organization', isEqualTo: "Phi Kappa Tau")
          .orderBy('startDateTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('No Upcoming Events',
                  style: TextStyle(color: Colors.white)));
        }

        final events = snapshot.data!.docs;
        final now = DateTime.now();

        final upcomingEvents = events.where((event) {
          final eventData = event.data() as Map<String, dynamic>;
          final endDateTime = (eventData['endDateTime'] as Timestamp).toDate();
          return endDateTime.isAfter(now);
        }).toList();

        if (upcomingEvents.isEmpty) {
          return Center(
              child: Text('No Upcoming Events',
                  style: TextStyle(color: Colors.white)));
        }

        return FlutterCarousel(
          items:
              upcomingEvents.map((event) => EventCard(event: event)).toList(),
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1,
            enlargeCenterPage: true,
            enableInfiniteScroll: true,
            autoPlay: true,
            showIndicator: false,
            autoPlayInterval: Duration(seconds: 5),
            autoPlayAnimationDuration: Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
          ),
        );
      },
    );
  }

  Widget _buildEventList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .where('organization', isEqualTo: "Phi Kappa Tau")
          .orderBy('startDateTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('No Upcoming Events',
                  style: TextStyle(color: Colors.white)));
        }

        final events = snapshot.data!.docs;
        final now = DateTime.now();

        final upcomingEvents = events.where((event) {
          final eventData = event.data() as Map<String, dynamic>;
          final endDateTime = (eventData['endDateTime'] as Timestamp).toDate();
          return endDateTime.isAfter(now);
        }).toList();

        if (upcomingEvents.isEmpty) {
          return Center(
              child: Text('No Upcoming Events',
                  style: TextStyle(color: Colors.white)));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: upcomingEvents.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: EventCard(event: upcomingEvents[index]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventCard(context, DocumentSnapshot event) {
    Map<String, dynamic> eventData = event.data() as Map<String, dynamic>;
    DateTime startDateTime = (eventData['startDateTime'] as Timestamp).toDate();
    DateTime endDateTime = (eventData['endDateTime'] as Timestamp).toDate();
    String? imageUrl = eventData['imageUrl'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => newEventDetailsPage(eventId: event.id),
          ),
        );
      },
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Color(0xFF1E1E1E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eventData['name'],
                    style: TextStyle(
                      fontFamily: 'roboto',
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${DateFormat('MMM d, h:mm a').format(startDateTime)} - ${DateFormat('h:mm a').format(endDateTime)}',
                    style: TextStyle(
                      fontFamily: 'roboto',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedMembers() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('greekOrganization', isEqualTo: "6DgHgmtq2iLiGuvWUSh7")
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.white)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('No members found',
                  style: TextStyle(color: Colors.white)));
        }

        final members = snapshot.data!.docs;

        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildMemberCard(members[index]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMemberCard(DocumentSnapshot member) {
    final memberData = member.data() as Map<String, dynamic>;
    final firstName = memberData['firstName'];
    final lastName = memberData['lastName'];
    final profileImageUrl = memberData['profileImageUrl'];

    final roles = List<String>.from(memberData['roles'] ?? []);

    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 2),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemberProfilePage(userId: member.id),
            ),
          );
        },
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Color(0xFF1E1E1E),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? CircleAvatar(
                      radius: 53,
                      backgroundImage: NetworkImage(profileImageUrl),
                    )
                  : CircleAvatar(
                      radius: 53,
                      backgroundColor: _generateAvatarColor(firstName),
                      child: Text(
                        '${firstName[0]}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
              SizedBox(height: 8),
              Text(
                '${firstName[0].toUpperCase()}${firstName.substring(1).toLowerCase()} ${lastName[0].toUpperCase()}.',
                style: TextStyle(
                  fontFamily: 'roboto',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                memberData['roles'] is List && memberData['roles'].isNotEmpty
                    ? memberData['roles'][0]
                    : 'Member',
                style: TextStyle(
                  fontFamily: 'roboto',
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              if (_hasPermission('Manage Events'))
                ListTile(
                  leading: Icon(Icons.event, color: Colors.white),
                  title: Text('Create Event',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EventCreationPage(
                            organizationName: "Phi Kappa Tau"),
                      ),
                    );
                  },
                ),
              if (_hasPermission('Manage Roles'))
                ListTile(
                  leading: Icon(Icons.people, color: Colors.white),
                  title: Text('Manage Roles',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RoleManagementPage(
                            chapterId: "aY3G5VjQhGlRTzMn8Boa"),
                      ),
                    );
                  },
                ),
              if (_hasPermission('View Attendance'))
                ListTile(
                  leading: Icon(Icons.assessment, color: Colors.white),
                  title: Text('View Attendance',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AttendanceStatsPage(
                            organizationId: "6DgHgmtq2iLiGuvWUSh7"),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Color _generateAvatarColor(String input) {
    final hue = input.hashCode % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.8).toColor();
  }
}

class AllMembersPage extends StatefulWidget {
  @override
  _AllMembersPageState createState() => _AllMembersPageState();
}

class _AllMembersPageState extends State<AllMembersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'All Actives',
          style: TextStyle(
            fontFamily: 'roboto',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF121212),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              style: TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('greekOrganization', isEqualTo: "6DgHgmtq2iLiGuvWUSh7")
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.white)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No members found',
                        style: TextStyle(color: Colors.white)),
                  );
                }
                final members = snapshot.data!.docs;
                final filteredMembers = members.where((member) {
                  final memberData = member.data() as Map<String, dynamic>;
                  final fullName =
                      '${memberData['firstName']} ${memberData['lastName']}'
                          .toLowerCase();
                  return fullName.contains(_searchQuery);
                }).toList();
                return AnimationLimiter(
                  child: ListView.builder(
                    itemCount: filteredMembers.length,
                    itemBuilder: (BuildContext context, int index) {
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildMemberListItem(
                                context, filteredMembers[index]),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberListItem(BuildContext context, DocumentSnapshot member) {
    final memberData = member.data() as Map<String, dynamic>;
    final firstName = memberData['firstName'];
    final lastName = memberData['lastName'];
    final profileImageUrl = memberData['profileImageUrl'];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _generateAvatarColor(firstName),
        child: profileImageUrl != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: profileImageUrl,
                  placeholder: (context, url) => CircularProgressIndicator(),
                  errorWidget: (context, url, error) => Text(
                    firstName[0],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                ),
              )
            : Text(
                firstName[0],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
      title: Text(
        '$firstName $lastName',
        style: TextStyle(
          fontFamily: 'roboto',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberProfilePage(userId: member.id),
          ),
        );
      },
    );
  }

  Color _generateAvatarColor(String input) {
    final hue = input.hashCode % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.8).toColor();
  }
}

class MemberProfilePage extends StatefulWidget {
  final String userId;

  MemberProfilePage({required this.userId});

  @override
  _MemberProfilePageState createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _eventsAttended = 0;
  double _attendancePercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    try {
      DateTime startDate =
          DateTime.now().subtract(Duration(days: 365)); // Last year
      DateTime endDate = DateTime.now();

      final eventsQuery = await _firestore
          .collection('events')
          .where('organization', isEqualTo: "Phi Kappa Tau")
          .where('startDateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startDateTime',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('endDateTime',
              isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .get();

      final events = eventsQuery.docs.where((doc) {
        final data = doc.data();
        // Filter out events where trackAttendance is true
        return data['trackAttendance'] != false;
      });
      final totalEvents = events.length;

      final membersQuery = await _firestore.collection('users').get();

      final members = membersQuery.docs;

      Map<String, Map<String, dynamic>> memberAttendance = {};

      for (var member in members) {
        final memberData = member.data();
        memberAttendance[member.id] = {
          'id': member.id,
        };
      }

      int totalAttendancesAndExcused = 0;
      int eventsAttended = 0;

      for (var event in events) {
        final eventData = event.data();
        final attendees = eventData['attendees'] as List<dynamic>? ?? [];
        final excusedMembers =
            eventData['excusedMembers'] as List<dynamic>? ?? [];

        for (var memberId in memberAttendance.keys) {
          if (memberId == widget.userId) {
            if (attendees.contains(memberId)) {
              eventsAttended++;
              totalAttendancesAndExcused++;
            } else if (excusedMembers.contains(memberId)) {
              eventsAttended++;
              totalAttendancesAndExcused++;
            }
          }
        }
      }

      setState(() {
        _attendancePercentage = totalEvents > 0 && members.isNotEmpty
            ? (totalAttendancesAndExcused / (totalEvents)) * 100
            : 0.0;
        _eventsAttended = eventsAttended;
      });
    } catch (e) {
      print('Error fetching attendance data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          '',
          style: TextStyle(
            fontFamily: 'roboto',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF121212),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData == null)
            return Center(child: Text('User data not found'));

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildProfilePicture(userData),
                  SizedBox(height: 24),
                  _buildNameSection(userData),
                  SizedBox(height: 8),
                  _buildPositionAndPledgeClass(userData),
                  SizedBox(height: 32),
                  _buildInfoSection(userData),
                  SizedBox(height: 32),
                  _buildStatsSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfilePicture(Map<String, dynamic> userData) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        image: userData['profileImageUrl'] != null
            ? DecorationImage(
                image: NetworkImage(userData['profileImageUrl']),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: userData['profileImageUrl'] == null
          ? Icon(Icons.person, size: 80, color: Colors.white)
          : null,
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }

  Widget _buildNameSection(Map<String, dynamic> userData) {
    return Column(
      children: [
        Text(
          '${userData['firstName']} ${userData['lastName']}',
          style: TextStyle(
            fontFamily: 'roboto',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        FutureBuilder<DocumentSnapshot>(
          future: _firestore
              .collection('greekOrganizations')
              .doc(userData['greekOrganization'])
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return Text('Loading...',
                  style: TextStyle(color: Colors.white70));
            final orgData = snapshot.data!.data() as Map<String, dynamic>?;
            return Text(
              '${orgData?['name'] ?? 'Unknown Organization'}',
              style: TextStyle(
                fontFamily: 'roboto',
                fontSize: 16,
                color: Colors.white70,
              ),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms);
  }

  Widget _buildPositionAndPledgeClass(Map<String, dynamic> userData) {
    final roles = List<String>.from(userData['roles'] ?? []);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildChip(roles.isNotEmpty ? roles[0] : 'Member', Colors.blue),
        SizedBox(width: 8),
        _buildChip(userData['pledgeClass'] ?? 'Unknown', Colors.green),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms);
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'roboto',
          fontSize: 14,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> userData) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoItem(Icons.school, userData['school'] ?? 'Unknown'),
          SizedBox(height: 16),
          _buildInfoItem(Icons.book, userData['major'] ?? 'Unknown'),
          SizedBox(height: 16),
          _buildInfoItem(Icons.calendar_today,
              'Class of ${userData['graduationYear'] ?? 'Unknown'}'),
        ],
      ),
    ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms, delay: 300.ms);
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 20),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'roboto',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Events Attended', _eventsAttended.toString()),
        _buildStatItem(
            'Attendance', '${_attendancePercentage.toStringAsFixed(1)}%'),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 400.ms);
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'roboto',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'roboto',
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
      ],
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
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey,
                            child: Icon(Icons.error, color: Colors.white),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey,
                        child: Icon(Icons.event, color: Colors.white),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Spacer(),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey[400]),
                        SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d • h:mm a').format(dateTime),
                          style: GoogleFonts.roboto(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
