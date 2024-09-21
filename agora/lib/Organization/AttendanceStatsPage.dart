import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceStatsPage extends StatefulWidget {
  final String organizationId;

  AttendanceStatsPage({required this.organizationId});

  @override
  _AttendanceStatsPageState createState() => _AttendanceStatsPageState();
}

class _AttendanceStatsPageState extends State<AttendanceStatsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _memberStats = [];
  List<Map<String, dynamic>> _allMemberStats = [];
  List<Map<String, dynamic>> _filteredMemberStats = [];
  double _overallAttendanceRate = 0.0;
  int _totalEvents = 0;
  bool _isLoading = true;
  String _searchQuery = '';
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDefaultStartDate().then((_) => _fetchAttendanceData());
  }

  Future<void> _loadDefaultStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultStartDate = prefs.getString('defaultStartDate');
    if (defaultStartDate != null) {
      setState(() {
        _startDate = DateTime.parse(defaultStartDate);
      });
    }
  }

  Future<void> _setDefaultStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultStartDate', _startDate.toIso8601String());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Default start date set successfully')),
    );
  }

  void _showDatePicker(bool isStartDate) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.darkColor,
        child: Column(
          children: [
            Container(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text('Cancel',
                        style: TextStyle(color: CupertinoColors.activeBlue)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (isStartDate)
                    CupertinoButton(
                      child: Text('Set as Default',
                          style: TextStyle(color: CupertinoColors.activeBlue)),
                      onPressed: () {
                        _setDefaultStartDate();
                        Navigator.of(context).pop();
                      },
                    ),
                  CupertinoButton(
                    child: Text('Done',
                        style: TextStyle(color: CupertinoColors.activeBlue)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _fetchAttendanceData();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: isStartDate ? _startDate : _endDate,
                onDateTimeChanged: (val) {
                  setState(() {
                    if (isStartDate) {
                      _startDate = val;
                    } else {
                      _endDate = val;
                    }
                  });
                },
                minimumDate: isStartDate ? DateTime(2020) : _startDate,
                maximumDate: isStartDate ? _endDate : DateTime.now(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _filterMembers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMemberStats = List.from(_allMemberStats);
      } else {
        _filteredMemberStats = _allMemberStats
            .where((member) =>
                member['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print(
          'Fetching events for org: ${widget.organizationId}, start: $_startDate, end: $_endDate');
      final eventsQuery = await _firestore
          .collection('events')
          .where('organization', isEqualTo: "Phi Kappa Tau")
          .where('startDateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('startDateTime',
              isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
          .where('endDateTime',
              isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .get();

      final events = eventsQuery.docs.where((doc) {
        final data = doc.data();
        // Filter out events where trackAttendance is true
        return data['trackAttendance'] != false;
      });
      _totalEvents = events.length;
      print('Total events found: $_totalEvents');

      final membersQuery = await _firestore
          .collection('users')
          .where('greekOrganization', isEqualTo: widget.organizationId)
          .get();

      final members = membersQuery.docs;
      print('Total members found: ${members.length}');

      Map<String, Map<String, dynamic>> memberAttendance = {};

      for (var member in members) {
        final memberData = member.data();
        memberAttendance[member.id] = {
          'id': member.id,
          'name': '${memberData['firstName']} ${memberData['lastName']}',
          'attended': 0,
          'excused': 0,
          'missed': 0,
        };
      }

      int totalAttendancesAndExcused = 0;

      for (var event in events) {
        final eventData = event.data();
        print(eventData['trackAttendance']);
        if (eventData['trackAttendance'] == true) {
          final attendees = eventData['attendees'] as List<dynamic>? ?? [];
          final excusedMembers =
              eventData['excusedMembers'] as List<dynamic>? ?? [];

          for (var memberId in memberAttendance.keys) {
            if (attendees.contains(memberId)) {
              memberAttendance[memberId]!['attended']++;
              totalAttendancesAndExcused++;
            } else if (excusedMembers.contains(memberId)) {
              memberAttendance[memberId]!['excused']++;
              totalAttendancesAndExcused++;
            } else {
              memberAttendance[memberId]!['missed']++;
            }
          }
        }
      }

      _overallAttendanceRate = _totalEvents > 0 && members.isNotEmpty
          ? (totalAttendancesAndExcused / (_totalEvents * members.length)) * 100
          : 0.0;
      _allMemberStats = memberAttendance.entries.map((entry) {
        final stats = entry.value;
        final total = stats['attended'] + stats['excused'] + stats['missed'];
        final attendanceRate = total > 0
            ? ((stats['attended'] + stats['excused']) / total * 100)
                .toStringAsFixed(1)
            : '0';

        return {
          'id': entry.key,
          'name': stats['name'],
          'attended': stats['attended'],
          'excused': stats['excused'],
          'missed': stats['missed'],
          'attendanceRate': attendanceRate,
        };
      }).toList();

      _allMemberStats.sort((a, b) => double.parse(b['attendanceRate'])
          .compareTo(double.parse(a['attendanceRate'])));

      _filteredMemberStats = List.from(_allMemberStats);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching attendance data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to fetch attendance data. Please try again.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _fetchAttendanceData();
    _filterMembers(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Attendance',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.pending_actions, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ExcuseRequestsPage(organizationId: "Phi Kappa Tau"),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.white,
        backgroundColor: Color(0xFF1A1A1A),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.white60))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateRange(),
                          SizedBox(height: 30),
                          _buildOverallStats(),
                          SizedBox(height: 30),
                          _buildSearchBar(),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  _buildMemberStatsList(),
                ],
              ),
      ),
    );
  }

  Widget _buildDateRange() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildDateButton(
          label: 'From',
          date: _startDate,
          onTap: () => _showDatePicker(true),
        ),
        Text('—', style: TextStyle(color: Colors.white60)),
        _buildDateButton(
          label: 'To',
          date: _endDate,
          onTap: () => _showDatePicker(false),
        ),
      ],
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            DateFormat('MMM dd').format(date),
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStats() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Attendance',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                label: 'Attendance Rate',
                value: '${_overallAttendanceRate.toStringAsFixed(1)}%',
              ),
              _buildStatItem(
                label: 'Total Events',
                value: '$_totalEvents',
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildStatItem({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.roboto(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        cursorColor: Colors.white,
        style: GoogleFonts.roboto(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search members',
          hintStyle: GoogleFonts.roboto(color: Colors.white38),
          icon: Icon(Icons.search, color: Colors.white38, size: 20),
          border: InputBorder.none,
        ),
        onChanged: _filterMembers,
      ),
    );
  }

  Widget _buildMemberStatsList() {
    if (_filteredMemberStats.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            _searchQuery.isEmpty ? 'No members found' : 'No matching members',
            style: GoogleFonts.roboto(color: Colors.white60, fontSize: 16),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final memberStat = _filteredMemberStats[index];
          return _buildMemberStatItem(memberStat, index);
        },
        childCount: _filteredMemberStats.length,
      ),
    );
  }

  Widget _buildMemberStatItem(Map<String, dynamic> memberStat, int index) {
    return InkWell(
      onTap: () => _navigateToMemberDetails(memberStat),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white10, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberStat['name'],
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Attendance: ${memberStat['attendanceRate']}%',
                    style:
                        GoogleFonts.roboto(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms);
  }

  void _navigateToMemberDetails(Map<String, dynamic> memberStat) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemberDetailsPage(
          memberId: memberStat['id'],
          memberName: memberStat['name'],
          organizationId: "Phi Kappa Tau",
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
    if (result == true) {
      // Refresh data if changes were made in MemberDetailsPage
      _refreshData();
    }
  }
}

class MemberDetailsPage extends StatefulWidget {
  final String memberId;
  final String memberName;
  final String organizationId;
  final DateTime startDate;
  final DateTime endDate;

  MemberDetailsPage({
    required this.memberId,
    required this.memberName,
    required this.organizationId,
    required this.startDate,
    required this.endDate,
  });

  @override
  _MemberDetailsPageState createState() => _MemberDetailsPageState();
}

class _MemberDetailsPageState extends State<MemberDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _eventList = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _userPermissions = [];
  bool _isLoading = true;
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _fetchMemberEvents();
    _fetchUserPermissions();
  }

  bool _hasPermission(String permission) {
    return _userPermissions.contains(permission);
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

  Future<void> _fetchMemberEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print(
          'Fetching events for member: ${widget.memberId}, org: ${widget.organizationId}, start: ${widget.startDate}, end: ${widget.endDate}');
      final eventsQuery = await _firestore
          .collection('events')
          .where('organization', isEqualTo: "Phi Kappa Tau")
          .where('startDateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(widget.startDate))
          .where('startDateTime',
              isLessThanOrEqualTo: Timestamp.fromDate(widget.endDate))
          .get();

      print('Total events found: ${eventsQuery.docs.length}');

      _eventList = eventsQuery.docs.where((doc) {
        final data = doc.data();
        // Filter out events where trackAttendance is true
        return data['trackAttendance'] != false;
      }).map((doc) {
        final data = doc.data();
        final attendees = data['attendees'] as List<dynamic>? ?? [];
        final excusedMembers = data['excusedMembers'] as List<dynamic>? ?? [];

        String status = 'Missed';
        if (attendees.contains(widget.memberId)) {
          status = 'Attended';
        } else if (excusedMembers.contains(widget.memberId)) {
          status = 'Excused';
        }

        return {
          'id': doc.id,
          'name': data['name'],
          'startDateTime': (data['startDateTime'] as Timestamp).toDate(),
          'status': status,
        };
      }).toList();

      _eventList
          .sort((a, b) => b['startDateTime'].compareTo(a['startDateTime']));

      print('Processed events for member: ${_eventList.length}');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching member events: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to fetch member events. Please try again.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateEventStatus(String eventId, String newStatus) async {
    try {
      final eventRef = _firestore.collection('events').doc(eventId);

      await _firestore.runTransaction((transaction) async {
        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) {
          throw Exception('Event does not exist');
        }

        final eventData = eventDoc.data()!;
        List<String> attendees =
            List<String>.from(eventData['attendees'] ?? []);
        List<String> excusedMembers =
            List<String>.from(eventData['excusedMembers'] ?? []);

        // Remove the member from all lists first
        attendees.remove(widget.memberId);
        excusedMembers.remove(widget.memberId);

        // Add the member to the appropriate list based on the new status
        switch (newStatus) {
          case 'Attended':
            attendees.add(widget.memberId);
            break;
          case 'Excused':
            excusedMembers.add(widget.memberId);
            break;
          // For 'Missed', we don't need to add to any list
        }

        transaction.update(eventRef, {
          'attendees': attendees,
          'excusedMembers': excusedMembers,
        });
      });

      // Update local state
      setState(() {
        final eventIndex = _eventList.indexWhere((e) => e['id'] == eventId);
        if (eventIndex != -1) {
          _eventList[eventIndex]['status'] = newStatus;
        }
        _dataChanged = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event status updated successfully')),
      );
    } catch (e) {
      print('Error updating event status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update event status. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_dataChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            widget.memberName,
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.white60))
            : _eventList.isEmpty
                ? Center(
                    child: Text(
                      'No events found',
                      style: GoogleFonts.roboto(color: Colors.white60),
                    ),
                  )
                : ListView.builder(
                    itemCount: _eventList.length,
                    itemBuilder: (context, index) {
                      final event = _eventList[index];
                      return _buildEventItem(event);
                    },
                  ),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    Color statusColor;
    switch (event['status']) {
      case 'Attended':
        statusColor = Colors.green;
        break;
      case 'Excused':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.red;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
            margin: EdgeInsets.only(top: 4),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['name'],
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, y - h:mm a')
                      .format(event['startDateTime']),
                  style:
                      GoogleFonts.roboto(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          ),
          if (_hasPermission('Edit Attendance')) _buildStatusDropdown(event),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(Map<String, dynamic> event) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: event['status'],
          onChanged: (String? newValue) {
            if (newValue != null) {
              _updateEventStatus(event['id'], newValue);
            }
          },
          items: <String>['Attended', 'Excused', 'Missed']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: GoogleFonts.roboto(color: Colors.white),
              ),
            );
          }).toList(),
          dropdownColor: Color(0xFF1A1A1A),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white38),
          isDense: true,
        ),
      ),
    );
  }
}

class ExcuseRequestsPage extends StatefulWidget {
  final String organizationId;

  ExcuseRequestsPage({required this.organizationId});

  @override
  _ExcuseRequestsPageState createState() => _ExcuseRequestsPageState();
}

class _ExcuseRequestsPageState extends State<ExcuseRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _excuseRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExcuseRequests();
  }

  Future<void> _fetchExcuseRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use your existing query logic here
      final pendingExcuseRequestsQuery = await _firestore
          .collection('events')
          .where('organization', isEqualTo: widget.organizationId)
          .where('hasPendingExcuseRequests', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> requests = [];

      for (var eventDoc in pendingExcuseRequestsQuery.docs) {
        final eventData = eventDoc.data();
        final excuseRequests =
            eventData['excuseRequests'] as List<dynamic>? ?? [];

        for (var request in excuseRequests) {
          final userDoc =
              await _firestore.collection('users').doc(request['userId']).get();
          final userData = userDoc.data();

          requests.add({
            'eventId': eventDoc.id,
            'eventName': eventData['name'],
            'eventDate': (eventData['startDateTime'] as Timestamp).toDate(),
            'userId': request['userId'],
            'userName': '${userData?['firstName']} ${userData?['lastName']}',
            'excuse': request['excuse'],
            'timestamp': request['timestamp'],
          });
        }
      }

      requests.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      setState(() {
        _excuseRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching excuse requests: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to fetch excuse requests. Please try again.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleExcuseRequest(
      Map<String, dynamic> request, bool isApproved) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final eventRef =
            _firestore.collection('events').doc(request['eventId']);
        final eventDoc = await transaction.get(eventRef);

        if (!eventDoc.exists) {
          throw Exception('Event does not exist');
        }

        final eventData = eventDoc.data()!;
        List<dynamic> excuseRequests =
            List.from(eventData['excuseRequests'] ?? []);
        List<String> excusedMembers =
            List<String>.from(eventData['excusedMembers'] ?? []);

        excuseRequests.removeWhere((r) => r['userId'] == request['userId']);

        if (isApproved) {
          excusedMembers.add(request['userId']);
        }

        bool hasPendingRequests = excuseRequests.isNotEmpty;

        transaction.update(eventRef, {
          'excuseRequests': excuseRequests,
          'excusedMembers': excusedMembers,
          'hasPendingExcuseRequests': hasPendingRequests,
        });
      });

      setState(() {
        _excuseRequests.removeWhere((r) =>
            r['userId'] == request['userId'] &&
            r['eventId'] == request['eventId']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isApproved
                ? 'Excuse request approved'
                : 'Excuse request denied')),
      );
    } catch (e) {
      print('Error handling excuse request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to process excuse request. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Excuse Requests',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white60))
          : _excuseRequests.isEmpty
              ? Center(
                  child: Text(
                    'No pending excuse requests',
                    style:
                        GoogleFonts.roboto(color: Colors.white60, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _excuseRequests.length,
                  itemBuilder: (context, index) {
                    final request = _excuseRequests[index];
                    return _buildExcuseRequestItem(request);
                  },
                ),
    );
  }

  Widget _buildExcuseRequestItem(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Color(0xFF3D3D3D),
          child: Text(
            request['userName'].substring(0, 1).toUpperCase(),
            style: GoogleFonts.roboto(color: Colors.white),
          ),
        ),
        title: Text(
          request['userName'],
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'Event: ${request['eventName']}',
              style: GoogleFonts.roboto(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 2),
            Text(
              DateFormat('MMM d, y - h:mm a').format(request['eventDate']),
              style: GoogleFonts.roboto(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Excuse:',
              style: GoogleFonts.roboto(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              request['excuse'],
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 14),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton(
                label: 'Deny',
                color: Colors.red,
                onPressed: () => _handleExcuseRequest(request, false),
              ),
              SizedBox(width: 16),
              _buildActionButton(
                label: 'Approve',
                color: Colors.green,
                onPressed: () => _handleExcuseRequest(request, true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle:
            GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
