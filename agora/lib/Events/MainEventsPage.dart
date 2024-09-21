import 'package:flutter/material.dart' hide CarouselController;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './CalendarPage.dart';
import './NwEventDetailsPage.dart';

final eventsProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final now = DateTime.now();
  return FirebaseFirestore.instance
      .collection('events')
      .where('organization', isEqualTo: "Phi Kappa Tau")
      .where('endDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
      .orderBy('endDateTime', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

class NewEventsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsyncValue = ref.watch(eventsProvider);

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Events',
          style: TextStyle(
            fontFamily: 'roboto',
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => CalendarPage(),
              ));
            },
          ),
        ],
      ),
      body: eventsAsyncValue.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (events) {
          final filteredEvents = _filterEvents(events);
          if (filteredEvents.isEmpty) {
            return Center(
                child: Text('No upcoming events',
                    style: TextStyle(color: Colors.white)));
          }

          final categorizedEvents = _categorizeEvents(filteredEvents);

          return ListView.builder(
            itemCount: categorizedEvents.length,
            itemBuilder: (context, index) {
              final category = categorizedEvents.keys.elementAt(index);
              final categoryEvents = categorizedEvents[category]!;

              if (categoryEvents.isEmpty) return SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontFamily: 'roboto',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ...categoryEvents
                      .map((event) => _buildEventCard(context, event))
                      .toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<DocumentSnapshot> _filterEvents(List<DocumentSnapshot> events) {
    final now = DateTime.now();
    final oneMonthLater = now.add(Duration(days: 30));

    return events.where((event) {
      final eventData = event.data() as Map<String, dynamic>;
      final startDateTime = (eventData['startDateTime'] as Timestamp).toDate();
      return startDateTime.isBefore(oneMonthLater);
    }).toList();
  }

  Map<String, List<DocumentSnapshot>> _categorizeEvents(
      List<DocumentSnapshot> events) {
    final now = DateTime.now();
    final thisWeekEnd = now.add(Duration(days: 7 - now.weekday % 7));
    final nextWeekEnd = thisWeekEnd.add(Duration(days: 7));
    final thirdWeekEnd = nextWeekEnd.add(Duration(days: 7));

    final categorizedEvents = {
      'This Week': <DocumentSnapshot>[],
      'Next Week': <DocumentSnapshot>[],
      DateFormat('MMMM d').format(nextWeekEnd.add(Duration(days: 1))):
          <DocumentSnapshot>[],
      DateFormat('MMMM d').format(thirdWeekEnd.add(Duration(days: 1))):
          <DocumentSnapshot>[],
    };

    for (var event in events) {
      final eventData = event.data() as Map<String, dynamic>;
      final startDateTime = (eventData['startDateTime'] as Timestamp).toDate();

      if (startDateTime.isBefore(thisWeekEnd)) {
        categorizedEvents['This Week']!.add(event);
      } else if (startDateTime.isBefore(nextWeekEnd)) {
        categorizedEvents['Next Week']!.add(event);
      } else if (startDateTime.isBefore(thirdWeekEnd)) {
        categorizedEvents[DateFormat('MMMM d')
                .format(nextWeekEnd.add(Duration(days: 1)))]!
            .add(event);
      } else {
        categorizedEvents[DateFormat('MMMM d')
                .format(thirdWeekEnd.add(Duration(days: 1)))]!
            .add(event);
      }
    }

    return categorizedEvents;
  }

  Widget _buildEventCard(context, DocumentSnapshot event) {
    final eventData = event.data() as Map<String, dynamic>;
    final startDateTime = (eventData['startDateTime'] as Timestamp).toDate();
    final endDateTime = (eventData['endDateTime'] as Timestamp).toDate();
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
        height: 240,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventData['name'],
                        style: TextStyle(
                          fontFamily: 'roboto',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatEventDateTime(startDateTime, endDateTime),
                        style: TextStyle(
                          fontFamily: 'roboto',
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatEventDateTime(DateTime start, DateTime end) {
    final dateFormat = DateFormat('MMMM d');
    final timeFormat = DateFormat('h:mm a');

    String formattedStart =
        '${dateFormat.format(start)} • ${timeFormat.format(start)}';

    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '$formattedStart - ${timeFormat.format(end)}';
    } else {
      return '$formattedStart - ${dateFormat.format(end)} • ${timeFormat.format(end)}';
    }
  }
}
