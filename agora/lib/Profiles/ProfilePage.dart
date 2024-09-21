import 'package:flutter/material.dart' hide CarouselController;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './SettingsPage.dart';

class newProfilePage extends StatefulWidget {
  @override
  _newProfilePage createState() => _newProfilePage();
}

class _newProfilePage extends State<newProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
          if (memberId == _auth.currentUser!.uid) {
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
      body: SafeArea(
        child: Stack(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_auth.currentUser!.uid)
                  .snapshots(),
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
                        SizedBox(height: 40), // Space for settings button
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
            Positioned(
              top: 16,
              right: 16,
              child: _buildSettingsButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.settings, color: Colors.white),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SettingsPage()),
        );
      },
    ).animate().fade(duration: 300.ms, delay: 500.ms);
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
            final fraternityData =
                snapshot.data!.data() as Map<String, dynamic>?;
            return Text(
              '${fraternityData?['name'] ?? 'Unknown Fraternity'}',
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildChip(
            userData['roles'] is List && userData['roles'].isNotEmpty
                ? userData['roles'][0]
                : 'Member',
            Colors.blue),
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
