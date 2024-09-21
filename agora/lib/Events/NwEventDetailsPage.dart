import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class newEventDetailsPage extends StatefulWidget {
  final String eventId;

  newEventDetailsPage({Key? key, required this.eventId}) : super(key: key);

  @override
  _newEventDetailsPageState createState() => _newEventDetailsPageState();
}

class _newEventDetailsPageState extends State<newEventDetailsPage> {
  Color _themeColor = Colors.blue; // Default color
  String _fontName = 'Roboto';
  final EventService _eventService = EventService();
  bool _isSubmitting = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<DocumentSnapshot> _eventStream;
  late Stream<DocumentSnapshot> _userStream;
  bool _isCheckedIn = false;
  bool _isExcused = false;
  bool _hasRequestedExcuse = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrViewController;

  @override
  void initState() {
    super.initState();
    _eventStream =
        _firestore.collection('events').doc(widget.eventId).snapshots();
    _userStream =
        _firestore.collection('users').doc(_auth.currentUser!.uid).snapshots();
    _checkAttendanceStatus();
  }

  void _checkAttendanceStatus() async {
    try {
      final eventDoc =
          await _firestore.collection('events').doc(widget.eventId).get();
      final eventData = eventDoc.data() as Map<String, dynamic>?;
      if (eventData != null) {
        final attendees = eventData['attendees'] as List<dynamic>? ?? [];
        final excusedMembers =
            eventData['excusedMembers'] as List<dynamic>? ?? [];
        final excuseRequests =
            eventData['excuseRequests'] as List<dynamic>? ?? [];

        if (mounted) {
          setState(() {
            _themeColor = Color(eventData['themeColor'] ?? 0xFF2196F3);
            _fontName = eventData['font'] ?? 'Roboto';
            _isCheckedIn = attendees.contains(_auth.currentUser!.uid);
            _isExcused = excusedMembers.contains(_auth.currentUser!.uid);
            _hasRequestedExcuse = excuseRequests
                .any((request) => request['userId'] == _auth.currentUser!.uid);
          });
        }
      }
    } catch (e) {
      print('Error checking attendance status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: _eventStream,
        builder: (context, eventSnapshot) {
          if (!eventSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final eventData = eventSnapshot.data!.data() as Map<String, dynamic>?;
          if (eventData == null) {
            return Center(child: Text('Event data not found'));
          }
          final DateTime startDateTime =
              (eventData['startDateTime'] as Timestamp).toDate();
          final DateTime endDateTime =
              (eventData['endDateTime'] as Timestamp).toDate();
          final DateTime now = DateTime.now();

          return StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              final bool isInOrganization = userData['organization'] != null;

              return Stack(
                children: [
                  // Full-size background image
                  Image.network(
                    eventData['imageUrl'] ??
                        'https://example.com/default-event-background.jpg',
                    fit: BoxFit.cover,
                    height: double.infinity,
                    width: double.infinity,
                  ),
                  // Glassmorphic overlay
                  GlassmorphicContainer(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                    blur: 20,
                    alignment: Alignment.topCenter,
                    border: 0,
                    linearGradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderGradient: LinearGradient(
                        colors: [Colors.transparent, Colors.transparent]),
                    child: SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Event poster (full aspect ratio)
                            Center(
                              child: Hero(
                                tag: 'eventPoster',
                                child: Container(
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width -
                                              40),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      eventData['imageUrl'] ??
                                          'https://example.com/default-event-poster.jpg',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideX(begin: 0.1, end: 0, duration: 200.ms),
                            SizedBox(height: 30),
                            // Event details
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    eventData['name'] ?? "UNNAMED EVENT",
                                    style: GoogleFonts.getFont(
                                      _fontName,
                                      textStyle: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 15),
                                  Text(
                                    _formatEventDateTime(
                                        startDateTime, endDateTime),
                                    style: GoogleFonts.roboto(
                                      fontSize: 16,
                                      color: _themeColor,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    "Hosted by ${eventData['organization'] ?? 'Unknown Organization'}",
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      color: _themeColor,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  // Address with icon
                                  GestureDetector(
                                    onTap: () =>
                                        _launchMaps(eventData['address'] ?? ''),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            color: Colors.redAccent),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            eventData['address'] ??
                                                'Address not provided',
                                            style: GoogleFonts.roboto(
                                                color: _themeColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action buttons
                                  if (eventData['trackAttendance'] == true)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24.0, vertical: 30.0),
                                      child: Column(
                                        children: [
                                          if (!_isExcused &&
                                              now.isBefore(startDateTime))
                                            _buildActionButton(
                                              icon: _hasRequestedExcuse
                                                  ? Icons.check_circle
                                                  : Icons.event_busy,
                                              label: _hasRequestedExcuse
                                                  ? "Excuse Requested"
                                                  : "Request Excuse",
                                              onPressed: _hasRequestedExcuse
                                                  ? () {}
                                                  : () =>
                                                      _showExcuseRequestDialog(),
                                              color: _hasRequestedExcuse
                                                  ? Colors.grey
                                                  : Colors.redAccent,
                                            ),
                                          if (_isExcused)
                                            _buildActionButton(
                                              icon: Icons.event_busy,
                                              label: "Excused",
                                              onPressed: () {},
                                              color: Colors.grey,
                                            ),
                                          if (!_isExcused &&
                                              now.isAfter(startDateTime) &&
                                              now.isBefore(endDateTime) &&
                                              !_isCheckedIn)
                                            _buildActionButton(
                                              icon: Icons.check,
                                              label: "Check In",
                                              onPressed: () =>
                                                  _showCheckInOptions(
                                                      eventData),
                                              color: Colors.greenAccent,
                                            ),
                                          if (_isCheckedIn)
                                            _buildActionButton(
                                              icon: Icons.check_circle,
                                              label: "Checked In",
                                              onPressed: () {},
                                              color: Colors.grey,
                                            ),
                                        ],
                                      ),
                                    ),
                                  SizedBox(height: 32),
                                ],
                              )
                                  .animate()
                                  .fadeIn(duration: 300.ms)
                                  .slideX(begin: 0.1, end: 0, duration: 200.ms),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.black,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showCheckInOptions(Map<String, dynamic> eventData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: GlassmorphicContainer(
              width: double.infinity,
              height: 200,
              borderRadius: 20,
              blur: 20,
              alignment: Alignment.bottomCenter,
              border: 2,
              linearGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              child: SafeArea(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Check In Options',
                      style: GoogleFonts.roboto(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (eventData['locationCheckIn'] == true)
                    _buildCheckInOption(
                      icon: Icons.location_on,
                      label: 'Check In with Location',
                      onTap: () => _checkInWithLocation(eventData),
                    ),
                  if (eventData['qrCodeCheckIn'] == true)
                    _buildCheckInOption(
                      icon: Icons.qr_code,
                      label: 'Check In with QR Code',
                      onTap: () => _checkInWithQRCode(eventData),
                    ),
                  Spacer(),
                ],
              )),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckInOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExcuseRequestDialog() {
    final _excuseController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Request Excuse',
                  style: GoogleFonts.roboto(color: Colors.white)),
              backgroundColor: Color(0xFF1A1A1A),
              content: TextField(
                cursorColor: Colors.white,
                autofocus: true,
                style: GoogleFonts.roboto(
                    color: Colors.white, decorationColor: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: "Enter your excuse",
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                controller: _excuseController,
                maxLines: 3,
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel',
                      style: GoogleFonts.roboto(color: Colors.white70)),
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: _isSubmitting
                      ? CircularProgressIndicator()
                      : Text('Submit',
                          style: GoogleFonts.roboto(
                              color: Theme.of(context).primaryColor)),
                  onPressed: _isSubmitting
                      ? null
                      : () => _submitExcuseRequest(
                          _excuseController.text, setState),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showErrorSnackBar(String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  Future<void> submitExcuseRequestQuery(String eventId, String excuse) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final eventRef =
        FirebaseFirestore.instance.collection('events').doc(eventId);

    final newExcuseRequest = {
      'userId': userId,
      'excuse': excuse,
      'timestamp': DateTime.now()
          .toUtc()
          .millisecondsSinceEpoch, // Use current timestamp
    };

    await eventRef.update({
      'excuseRequests': FieldValue.arrayUnion([newExcuseRequest]),
      'hasPendingExcuseRequests': true,
    });
  }

// Usage in your _submitExcuseRequest method remains the same:
  Future<void> _submitExcuseRequest(String excuse, StateSetter setState) async {
    if (excuse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an excuse before submitting.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await submitExcuseRequestQuery(widget.eventId, excuse);

      Navigator.of(context).pop(); // Dismiss the excuse request dialog
      if (mounted) {
        setState(() => _hasRequestedExcuse = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excuse request submitted successfully.')),
      );
      setState(() {
        _hasRequestedExcuse = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting excuse request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _performExcuseRequest(
      DocumentReference eventRef, String excuse) async {
    try {
      final userId = _auth.currentUser!.uid;
      final docSnapshot = await eventRef.get();

      if (!docSnapshot.exists) {
        throw Exception('Event document does not exist');
      }

      final eventData = docSnapshot.data() as Map<String, dynamic>?;
      if (eventData == null) {
        throw Exception('Event data is null');
      }

      List<dynamic> currentExcuseRequests = eventData['excuseRequests'] ?? [];

      bool alreadyRequested = currentExcuseRequests.any((request) =>
          request is Map<String, dynamic> && request['userId'] == userId);

      if (alreadyRequested) {
        throw Exception('You have already submitted an excuse request');
      }

      Map<String, dynamic> newExcuseRequest = {
        'userId': userId,
        'excuse': excuse,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await eventRef.update({
        'excuseRequests': FieldValue.arrayUnion([newExcuseRequest]),
        'hasPendingExcuseRequests': true,
      });

      return true;
    } catch (e) {
      print('Error in _performExcuseRequest: $e');
      return false;
    }
  }

  Future<void> _checkInWithLocation(Map<String, dynamic> eventData) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final eventLocation = eventData['selectedLocation'];
      final checkInRadius = eventData['checkInRadius'];

      if (eventLocation == null ||
          eventLocation.latitude == null ||
          eventLocation.longitude == null) {
        throw Exception('Event location not properly set');
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        eventLocation.latitude,
        eventLocation.longitude,
      );

      if (distance <= checkInRadius) {
        await _firestore.collection('events').doc(widget.eventId).update({
          'attendees': FieldValue.arrayUnion([_auth.currentUser!.uid]),
        });
        setState(() => _isCheckedIn = true);
        Navigator.pop(context); // Dismiss the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully checked in!')),
        );
      } else {
        Navigator.pop(context); // Dismiss the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are not within the check-in range.')),
        );
      }
    } catch (e) {
      print('Error checking in: $e');
      Navigator.pop(context); // Dismiss the bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking in: ${e.toString()}')),
      );
    }
  }

  Future<void> _checkInWithQRCode(Map<String, dynamic> eventData) async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text('Scan QR Code')),
        body: QRView(
          key: qrKey,
          onQRViewCreated: (QRViewController controller) {
            setState(() => _qrViewController = controller);
            controller.scannedDataStream.listen((scanData) {
              if (scanData.code == eventData['qrCode']) {
                _qrViewController?.dispose();
                _performQRCheckIn();
              }
            });
          },
        ),
      ),
    ));
  }

  Future<void> _performQRCheckIn() async {
    try {
      await _firestore.collection('events').doc(widget.eventId).update({
        'attendees': FieldValue.arrayUnion([_auth.currentUser!.uid]),
      });
      setState(() => _isCheckedIn = true);
      Navigator.of(context).pop(); // Close QR scanner
      Navigator.of(context).pop(); // Close bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully checked in with QR code!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking in: ${e.toString()}')),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        label,
        style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
      onTap: onPressed,
    );
  }

  String _formatEventDateTime(DateTime startDateTime, DateTime endDateTime) {
    final now = DateTime.now();
    final startDate =
        _formatDate(startDateTime, includeYear: startDateTime.year > now.year);
    final startTime = _formatTime(startDateTime);
    final endTime = _formatTime(endDateTime);

    if (startDateTime.year == endDateTime.year &&
        startDateTime.month == endDateTime.month &&
        startDateTime.day == endDateTime.day) {
      return '$startDate $startTime - $endTime';
    } else {
      final endDate =
          _formatDate(endDateTime, includeYear: endDateTime.year > now.year);
      return '$startDate $startTime - $endDate $endTime';
    }
  }

  String _formatDate(DateTime dateTime, {bool includeYear = false}) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return includeYear
        ? '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}'
        : '${months[dateTime.month - 1]} ${dateTime.day}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  void _launchMaps(String address) async {
    final url = Uri.encodeFull('https://maps.apple.com/?q=$address');
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      final fallbackUrl = Uri.encodeFull(
          'https://www.google.com/maps/search/?api=1&query=$address');
      if (await canLaunch(fallbackUrl)) {
        await launch(fallbackUrl);
      } else {
        throw 'Could not launch maps';
      }
    }
  }
}

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> submitExcuseRequest(String eventId, String excuse) async {
    try {
      final userId = _auth.currentUser!.uid;
      final eventRef = _firestore.collection('events').doc(eventId);

      // Use a batched write instead of a transaction
      WriteBatch batch = _firestore.batch();

      DocumentSnapshot eventDoc = await eventRef.get();
      if (!eventDoc.exists) {
        return 'ERROR: Event document does not exist';
      }

      Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
      List<dynamic> currentExcuseRequests = eventData['excuseRequests'] ?? [];

      bool alreadyRequested = currentExcuseRequests.any((request) =>
          request is Map<String, dynamic> && request['userId'] == userId);

      if (alreadyRequested) {
        return 'ERROR: You have already submitted an excuse request';
      }

      Map<String, dynamic> newExcuseRequest = {
        'userId': userId,
        'excuse': excuse,
        'timestamp': FieldValue.serverTimestamp(),
      };

      batch.update(eventRef, {
        'excuseRequests': FieldValue.arrayUnion([newExcuseRequest]),
        'hasPendingExcuseRequests': true,
      });

      await batch.commit();
      return 'SUCCESS';
    } catch (e) {
      print('Error in submitExcuseRequest: $e');
      return 'ERROR: ${e.toString()}';
    }
  }
}
