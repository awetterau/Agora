import 'package:flutter/material.dart' hide CarouselController;
import 'package:frat_chat/AuthFlow/AuthFlow.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import './NwEventDetailsPage.dart';

final eventsProvider = StreamProvider<Map<DateTime, List<Event>>>((ref) {
  return FirebaseFirestore.instance
      .collection('events')
      .where('organization', isEqualTo: "Phi Kappa Tau")
      .snapshots()
      .map((snapshot) {
    Map<DateTime, List<Event>> eventMap = {};
    for (var doc in snapshot.docs) {
      final event = Event.fromFirestore(doc);
      final date = DateTime(event.startDateTime.year, event.startDateTime.month,
          event.startDateTime.day);
      if (eventMap[date] == null) eventMap[date] = [];
      eventMap[date]!.add(event);
    }
    return eventMap;
  });
});

class Event {
  final String id;
  final String name;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String imageUrl;

  Event({
    required this.id,
    required this.name,
    required this.startDateTime,
    required this.endDateTime,
    required this.imageUrl,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      name: data['name'],
      startDateTime: (data['startDateTime'] as Timestamp).toDate(),
      endDateTime: (data['endDateTime'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

class CalendarPage extends ConsumerStatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsyncValue = ref.watch(eventsProvider);

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Calendar',
          style: GoogleFonts.roboto(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AgoraTheme.accentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: eventsAsyncValue.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AgoraTheme.accentColor)),
        error: (err, stack) => Center(
            child: Text('Error: $err', style: TextStyle(color: Colors.white))),
        data: (eventMap) => Column(
          children: [
            _buildCalendar(eventMap),
            SizedBox(height: 20),
            _buildEventList(eventMap),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<Event>> eventMap) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.now(),
        lastDay: DateTime.now().add(Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.white70),
          holidayTextStyle: TextStyle(color: Colors.white70),
          selectedDecoration: BoxDecoration(
            color: Color.fromARGB(255, 122, 122, 122),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Color.fromARGB(255, 122, 122, 122).withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          markerSize: 5,
          markerDecoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white70),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white70),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.white70),
          weekendStyle: TextStyle(color: Colors.white70),
        ),
        eventLoader: (day) =>
            eventMap[DateTime(day.year, day.month, day.day)] ?? [],
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              return Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    width: 5,
                    height: 5,
                  ),
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildEventList(Map<DateTime, List<Event>> eventMap) {
    final selectedDate =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final events = eventMap[selectedDate] ?? [];

    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: events.isEmpty
            ? Center(
                child: Text(
                  'No events on this day',
                  style:
                      GoogleFonts.roboto(color: Colors.white70, fontSize: 16),
                ),
              )
            : ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) => _buildEventItem(events[index]),
              ),
      ),
    );
  }

  Widget _buildEventItem(Event event) {
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
        height: 180,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFF262626),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Image
              Positioned.fill(
                child: event.imageUrl != null
                    ? Image.network(
                        event.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8)
                      ],
                    ),
                  ),
                ),
              ),
              // Event details
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${DateFormat('h:mm a').format(event.startDateTime)} - ${DateFormat('h:mm a').format(event.endDateTime)}',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Icon(Icons.event, color: Colors.white60, size: 48),
      ),
    );
  }
}
