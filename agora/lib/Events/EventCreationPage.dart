import 'dart:io';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:adoptive_calendar/adoptive_calendar.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as prefix;
import 'package:flutter_animate/flutter_animate.dart';
import './LocationSelectionPage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;

class EventCreationPage extends StatefulWidget {
  final String organizationName;

  EventCreationPage({required this.organizationName});

  @override
  _EventCreationPageState createState() => _EventCreationPageState();
}

class _EventCreationPageState extends State<EventCreationPage> {
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Prevents keyboard from pushing content up
      body: Stack(
        children: [
          EditableSlimeEventCard(
            organizationName: widget.organizationName,
            onSave: _createEventt,
          ),
        ],
      ),
    );
  }

  Future<void> _createEventt(
      String name,
      DateTime startDateTime,
      DateTime endDateTime,
      String address,
      File? imageFile,
      Map<String, dynamic> additionalData) async {
    if (_isCreating) return; // Prevent multiple submissions

    setState(() {
      _isCreating = true;
    });

    try {
      // Validate required fields
      if (name.isEmpty || address.isEmpty || imageFile == null) {
        throw Exception(
            'Please fill in all required fields and upload an image.');
      }

      String? imageUrl;
      if (imageFile != null) {
        XFile compressedImage = await compressImage(imageFile);
        final ref = FirebaseStorage.instance
            .ref()
            .child('event_images')
            .child('${DateTime.now().toIso8601String()}.jpg');
        await ref.putFile(compressedImage as File);
        imageUrl = await ref.getDownloadURL();
      }

      final eventData = {
        'name': name,
        'startDateTime': Timestamp.fromDate(startDateTime),
        'endDateTime': Timestamp.fromDate(endDateTime),
        'address': address,
        'organization': widget.organizationName,
        'imageUrl': imageUrl,
        'createdBy': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        ...additionalData,
      };

      await FirebaseFirestore.instance.collection('events').add(eventData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event created successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create event: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<XFile> compressImage(File file) async {
    final dir = await path_provider.getTemporaryDirectory();
    final targetPath = path.join(
        dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (result == null) {
      throw Exception('Image compression failed');
    }

    // If the compressed image is still over 1MB, reduce quality further
    while (await result!.length() > 1 * 1024 * 1024) {
      int currentQuality = 70;
      currentQuality -= 10;
      if (currentQuality <= 0) break; // Prevent infinite loop

      result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: currentQuality,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) {
        throw Exception('Image compression failed');
      }
    }

    return result;
  }
}

class EditableSlimeEventCard extends StatefulWidget {
  final String organizationName;
  final Function(
      String, DateTime, DateTime, String, File?, Map<String, dynamic>) onSave;

  EditableSlimeEventCard({
    required this.organizationName,
    required this.onSave,
  });

  @override
  _EditableSlimeEventCardState createState() => _EditableSlimeEventCardState();
}

class _EditableSlimeEventCardState extends State<EditableSlimeEventCard> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  File? _imageFile;
  Color themeColor = Colors.white;
  bool _isDarkMode = true;
  bool _trackAttendance = false;
  bool _locationCheckIn = false;
  bool _qrCodeCheckIn = false;
  String _postAs = "Phi Kappa Tau";
  String _selectedFont = 'Roboto';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String userName = "";
  List<String> _fontOptions = [
    'Roboto',
    'Lato',
    'Open Sans',
    'Montserrat',
    'Oswald',
    'Raleway',
    'Merriweather',
    'Poppins',
    'Playfair Display'
  ];
  bool _isStyleOptionsExpanded = false;
  RepeatEventSettings? _repeatEventSettings;
  bool _isCreating = false;
  prefix.LatLng? _selectedLocation;
  double? _selectedRadius;

  Widget _buildExpandingStyleOptions() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _isStyleOptionsExpanded ? 180 : 40,
      height: _isStyleOptionsExpanded ? 160 : 40,
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _isStyleOptionsExpanded
          ? Padding(
              padding: EdgeInsets.only(left: 8, right: 8, top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Font',
                          style: TextStyle(
                              fontFamily: 'roboto',
                              color: _isDarkMode ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _selectedFont,
                        isExpanded: false,
                        isDense: true,
                        dropdownColor: themeColor,
                        style: TextStyle(
                            fontFamily: 'roboto',
                            color: _isDarkMode ? Colors.black : Colors.white,
                            fontSize: 10),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedFont = newValue!;
                          });
                        },
                        items: _fontOptions
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style:
                                    GoogleFonts.getFont(value, fontSize: 10)),
                          );
                        }).toList(),
                        underline: Container(
                            height: 1,
                            color: _isDarkMode ? Colors.black : Colors.white),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Theme Color',
                          style: TextStyle(
                              fontFamily: 'roboto',
                              color: _isDarkMode ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Pick a color'),
                                content: SingleChildScrollView(
                                  child: ColorPicker(
                                    pickerColor: themeColor,
                                    onColorChanged: (Color color) {
                                      setState(() {
                                        themeColor = color;
                                      });
                                    },
                                    showLabel: true,
                                    pickerAreaHeightPercent: 0.8,
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Done'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: themeColor,
                            border: Border.all(
                                color:
                                    _isDarkMode ? Colors.black : Colors.white,
                                width: 2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Dark Mode',
                          style: TextStyle(
                              fontFamily: 'roboto',
                              color: _isDarkMode ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          value: _isDarkMode,
                          onChanged: (bool value) {
                            setState(() {
                              _isDarkMode = value;
                            });
                          },
                          activeColor:
                              _isDarkMode ? Colors.black : Colors.white,
                          activeTrackColor: _isDarkMode
                              ? Colors.black.withOpacity(0.5)
                              : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    child: Text('Close',
                        style: TextStyle(fontFamily: 'roboto', fontSize: 10)),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: themeColor,
                      backgroundColor:
                          _isDarkMode ? Colors.black : Colors.white,
                      minimumSize: Size(double.infinity, 24),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      setState(() {
                        _isStyleOptionsExpanded = false;
                      });
                    },
                  ),
                ],
              ),
            )
          : IconButton(
              icon: Icon(Icons.mode,
                  color: _isDarkMode ? Colors.black : Colors.white),
              iconSize: 20,
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _isStyleOptionsExpanded = true;
                });
              },
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    _postAs = widget.organizationName;
    _loadUser();
  }

  void _loadUser() async {
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() as Map<String, dynamic>;
    setState(() {
      userName = '${userData['firstName']} ${userData['lastName']}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        // Blurred background
        Positioned.fill(
          child: _imageFile != null
              ? ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      _isDarkMode
                          ? Colors.black.withOpacity(0.5)
                          : Colors.white.withOpacity(0.5),
                      BlendMode.srcOver,
                    ),
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      _isDarkMode
                          ? Color.fromARGB(255, 0, 0, 0).withOpacity(0.1)
                          : Colors.white.withOpacity(0.1),
                      BlendMode.srcOver,
                    ),
                    child: Image.asset(
                      'lib/images/DefaultImage.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
        ),

        // Black Bar on Bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 100,
          child: Container(
            color: _isDarkMode ? Colors.black : Colors.white,
          ),
        ),
        // Content
        SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_imageFile != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              left: 10,
                              top: 10,
                              child: _buildExpandingStyleOptions(),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: CircleAvatar(
                                backgroundColor: themeColor,
                                child: IconButton(
                                  icon: Icon(Icons.camera_alt,
                                      color: _isDarkMode
                                          ? Colors.black
                                          : Colors.white),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'lib/images/DefaultImage.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Create Your Event Page",
                                  style: TextStyle(
                                    fontFamily: 'roboto',
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  child: Text('Upload your Image*'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(
                                        255, 109, 109, 109),
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: _pickImage,
                                )
                              ],
                            ),
                          ],
                        ),
                      SizedBox(height: 22),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.getFont(
                          _selectedFont,
                          textStyle: TextStyle(
                            color: themeColor,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _isDarkMode
                              ? Colors.black.withOpacity(0.6)
                              : Colors.white.withOpacity(0.6),
                          hintText: 'Event Name*',
                          hintStyle: TextStyle(
                              fontFamily: 'roboto', color: themeColor),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7.0),
                              borderSide: BorderSide(color: themeColor)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7.0),
                              borderSide: BorderSide(color: themeColor)),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 10,
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final DateTime? picked =
                                      await showDialog<DateTime>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AdoptiveCalendar(
                                        initialDate:
                                            _startDateTime ?? DateTime.now(),
                                        action: true,
                                        barColor:
                                            Color.fromARGB(255, 111, 111, 111),
                                        barForegroundColor:
                                            Color.fromARGB(255, 65, 65, 65),
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _startDateTime = picked;
                                    });
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                    backgroundColor: _isDarkMode
                                        ? Colors.black.withOpacity(0.6)
                                        : Colors.white.withOpacity(0.6),
                                    minimumSize: Size(2, 35),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    side: BorderSide(color: themeColor)),
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _startDateTime == null
                                          ? "Start Time*"
                                          : "${DateFormat('MM/dd/yyyy HH:mm').format(_startDateTime!)}",
                                      style: TextStyle(
                                          fontFamily: 'roboto',
                                          color: themeColor),
                                    )),
                              ),
                            ),
                            Text("  -  ",
                                style: TextStyle(
                                    fontFamily: 'roboto',
                                    color: themeColor,
                                    fontSize: 33,
                                    fontWeight: FontWeight.w300)),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final DateTime? picked =
                                      await showDialog<DateTime>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AdoptiveCalendar(
                                        initialDate: _endDateTime ??
                                            (_startDateTime
                                                    ?.add(Duration(hours: 2)) ??
                                                DateTime.now()
                                                    .add(Duration(hours: 2))),
                                        action: true,
                                        barColor:
                                            Color.fromARGB(255, 111, 111, 111),
                                        barForegroundColor:
                                            Color.fromARGB(255, 65, 65, 65),
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _endDateTime = picked;
                                    });
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                    backgroundColor: _isDarkMode
                                        ? Colors.black.withOpacity(0.6)
                                        : Colors.white.withOpacity(0.6),
                                    minimumSize: Size(2, 35),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 2,
                                      horizontal: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    side: BorderSide(color: themeColor)),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                      _endDateTime == null
                                          ? "End Time*"
                                          : "${DateFormat('MM/dd/yyyy HH:mm').format(_endDateTime!)}",
                                      style: TextStyle(
                                          fontFamily: 'roboto',
                                          color: themeColor)),
                                ),
                              ),
                            ),
                          ]),
                      SizedBox(height: 2),
                      TextFormField(
                        controller: _addressController,
                        style: TextStyle(
                          fontFamily: "roboto",
                          color: themeColor,
                          fontWeight: FontWeight.normal,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: _isDarkMode
                                ? Colors.black.withOpacity(0.6)
                                : Colors.white.withOpacity(0.6),
                            isDense: true,
                            hintText: 'Address*',
                            hintStyle: TextStyle(
                                fontFamily: 'roboto', color: themeColor),
                            prefixIcon:
                                Icon(Icons.location_on, color: themeColor),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 25,
                              minHeight: 25,
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7.0),
                                borderSide: BorderSide(color: themeColor)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7.0),
                                borderSide: BorderSide(color: themeColor)),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5)),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Posting as: Phi Kappa Tau',
                            style: TextStyle(
                                fontFamily: 'roboto',
                                color: themeColor,
                                fontSize: 16),
                          ),
                          // SizedBox(width: 8),
                          // DropdownButton<String>(
                          //   value: _postAs,
                          //   dropdownColor:
                          //       _isDarkMode ? Colors.black : Colors.white,
                          //   style: TextStyle( fontFamily: 'roboto',color: themeColor),
                          //   onChanged: (String? newValue) {
                          //     setState(() {
                          //       _postAs = newValue!;
                          //     });
                          //   },
                          //   items: ["Phi Kappa Tau", '${userName}']
                          //       .map<DropdownMenuItem<String>>((String value) {
                          //     return DropdownMenuItem<String>(
                          //       value: value,
                          //       child: Text(value),
                          //     );
                          //   }).toList(),
                          // ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? Colors.black.withOpacity(0.6)
                              : Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.all(10),
                        child: AdvancedAttendanceTrackingWidget(
                          themeColor: themeColor,
                          isDarkMode: _isDarkMode,
                          onTrackAttendanceChanged: (value) {
                            setState(() {
                              _trackAttendance = value;
                            });
                          },
                          onLocationCheckInChanged: (value) {
                            setState(() {
                              _locationCheckIn = value;
                            });
                          },
                          onQrCodeCheckInChanged: (value) {
                            setState(() {
                              _qrCodeCheckIn = value;
                            });
                          },
                          onLocationSelected:
                              (prefix.LatLng location, double radius) {
                            setState(() {
                              _selectedLocation = location;
                              _selectedRadius = radius;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      RepeatEventsWidget(
                        themeColor: themeColor,
                        isDarkMode: _isDarkMode,
                        onRepeatSettingsChanged: (settings) {
                          setState(() {
                            _repeatEventSettings = settings;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                  color: _isDarkMode ? Colors.black : Colors.white,
                  child: Padding(
                      padding: EdgeInsets.only(left: 20, right: 20, top: 20),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.blue,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                minimumSize: Size(2, 35),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              onPressed: () {
                                _createEvent();
                              },
                              child: const Text('Create Event'),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _isDarkMode
                                    ? Color.fromARGB(255, 67, 67, 67)
                                    : Colors.grey,
                                tapTargetSize: MaterialTapTargetSize.padded,
                                minimumSize: const Size(2, 30),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                side: BorderSide(
                                    color: _isDarkMode
                                        ? Color.fromARGB(255, 67, 67, 67)
                                        : Colors.grey),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ])))
            ],
          ),
        ),
        if (_isCreating)
          Container(
            color: Colors.black54,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ]),
    );
  }

  Future<void> _createEvent() async {
    if (_nameController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _imageFile == null ||
        _startDateTime == null ||
        _endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Please fill in all required fields and upload an image.')),
      );
      return;
    }
    if (_isCreating) return;

    setState(() {
      _isCreating = true;
    });
    if (_repeatEventSettings?.enabled == true &&
        _repeatEventSettings?.endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Please select an end date for the repeating event.')),
      );
      return;
    }

    String? imageUrl;
    if (_imageFile != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('event_images')
          .child('${DateTime.now().toIso8601String()}.jpg');
      await ref.putFile(_imageFile!);
      imageUrl = await ref.getDownloadURL();
    }

    List<Map<String, dynamic>> eventData = [];

    if (_repeatEventSettings?.enabled == true) {
      DateTime currentDate = _startDateTime!;
      DateTime endDate = _repeatEventSettings!.endDate!;

      while (currentDate.isBefore(endDate) && eventData.length < 20) {
        if (_isValidEventDate(currentDate)) {
          eventData.add(_createEventData(currentDate, imageUrl));
        }
        currentDate = _getNextEventDate(currentDate);
      }

      if (eventData.length == 20 && currentDate.isBefore(endDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'You can only create up to 20 events at a time. The end date has been adjusted.')),
        );
      }
    } else {
      eventData.add(_createEventData(_startDateTime!, imageUrl));
    }

    for (var data in eventData) {
      await FirebaseFirestore.instance.collection('events').add(data);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Event(s) created successfully!')),
    );
    setState(() {
      _isCreating = false;
    });
    Navigator.pop(context);
  }

  Map<String, dynamic> _createEventData(DateTime eventDate, String? imageUrl) {
    return {
      'name': _nameController.text,
      'startDateTime': Timestamp.fromDate(eventDate),
      'endDateTime': Timestamp.fromDate(
          eventDate.add(_endDateTime!.difference(_startDateTime!))),
      'address': _addressController.text,
      'organization': widget.organizationName,
      'imageUrl': imageUrl,
      'createdBy': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'postAs': _postAs,
      'trackAttendance': _trackAttendance,
      'locationCheckIn': _locationCheckIn,
      'qrCodeCheckIn': _qrCodeCheckIn,
      'qrCode': DateTime.now()
          .millisecondsSinceEpoch
          .toString(), // Unique QR code for each event
      'selectedLocation': _selectedLocation != null
          ? GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude)
          : null,
      'checkInRadius': _selectedLocation != null ? _selectedRadius : null,
      'repeatEventSettings': _repeatEventSettings?.enabled == true
          ? {
              'frequency': _repeatEventSettings!.frequency.toString(),
              'interval': _repeatEventSettings!.interval,
              'selectedDays': _repeatEventSettings!.selectedDays,
              'endDate': _repeatEventSettings!.endDate != null
                  ? Timestamp.fromDate(_repeatEventSettings!.endDate!)
                  : null,
            }
          : null,
      'font': _selectedFont,
      'themeColor': themeColor.value,
      'isDarkMode': _isDarkMode,
      'attendees': [], // Initialize empty attendees list
      'excusedMembers': [], // Initialize empty excused members list
      'excuseRequests': [], // Initialize empty excuse requests list
    };
  }

  bool _isValidEventDate(DateTime date) {
    if (_repeatEventSettings!.frequency == RepeatFrequency.weekly) {
      return _repeatEventSettings!.selectedDays[date.weekday - 1];
    }
    return true;
  }

  DateTime _getNextEventDate(DateTime currentDate) {
    switch (_repeatEventSettings!.frequency) {
      case RepeatFrequency.daily:
        return currentDate.add(Duration(days: _repeatEventSettings!.interval));
      case RepeatFrequency.weekly:
        return currentDate
            .add(Duration(days: 7 * _repeatEventSettings!.interval));
      case RepeatFrequency.monthly:
        return DateTime(
            currentDate.year,
            currentDate.month + _repeatEventSettings!.interval,
            currentDate.day);
      case RepeatFrequency.yearly:
        return DateTime(currentDate.year + _repeatEventSettings!.interval,
            currentDate.month, currentDate.day);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        final compressedFile = await compressImage(file);
        setState(() {
          _imageFile = compressedFile;
        });
        await _updateThemeColorFromImage();
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image. Please try again.')),
      );
    }
  }

  Future<File> compressImage(File file) async {
    final dir = await path_provider.getTemporaryDirectory();
    final targetPath = path.join(
        dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (result == null) {
      throw Exception('Image compression failed');
    }

    File compressedFile = File(result.path);

    while (await compressedFile.length() > 1 * 1024 * 1024) {
      int currentQuality = 70;
      currentQuality -= 10;
      if (currentQuality <= 0) break;

      result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: currentQuality,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) {
        throw Exception('Image compression failed');
      }

      compressedFile = File(result.path);
    }

    return compressedFile;
  }

  Future<void> _updateThemeColorFromImage() async {
    if (_imageFile != null) {
      try {
        final paletteGenerator = await PaletteGenerator.fromImageProvider(
          FileImage(_imageFile!),
        );
        if (mounted) {
          setState(() {
            themeColor = paletteGenerator.dominantColor?.color ??
                paletteGenerator.vibrantColor?.color ??
                Colors.blue;

            if (themeColor.computeLuminance() < 0.5) {
              themeColor =
                  HSLColor.fromColor(themeColor).withLightness(0.6).toColor();
            }
          });
        }
      } catch (e) {
        print('Error generating palette: $e');
      }
    }
  }

  void _showStyleOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Style Options'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButton<String>(
                      value: _selectedFont,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedFont = newValue!;
                        });
                        this.setState(() {}); // Update the main state
                      },
                      items: _fontOptions
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: GoogleFonts.getFont(value)),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      child: Text('Select Theme Color'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Pick a color'),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: themeColor,
                                  onColorChanged: (Color color) {
                                    setState(() {
                                      themeColor = color;
                                    });
                                    this.setState(
                                        () {}); // Update the main state
                                  },
                                  showLabel: true,
                                  pickerAreaHeightPercent: 0.8,
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Done'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Dark Mode'),
                        Switch(
                          value: _isDarkMode,
                          onChanged: (bool value) {
                            setState(() {
                              _isDarkMode = value;
                            });
                            this.setState(() {}); // Update the main state
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AdvancedAttendanceTrackingWidget extends StatefulWidget {
  final Color themeColor;
  final bool isDarkMode;
  final Function(bool) onTrackAttendanceChanged;
  final Function(bool) onLocationCheckInChanged;
  final Function(bool) onQrCodeCheckInChanged;
  final Function(prefix.LatLng, double) onLocationSelected;

  AdvancedAttendanceTrackingWidget({
    required this.themeColor,
    required this.isDarkMode,
    required this.onTrackAttendanceChanged,
    required this.onLocationCheckInChanged,
    required this.onQrCodeCheckInChanged,
    required this.onLocationSelected,
  });

  @override
  _AdvancedAttendanceTrackingWidgetState createState() =>
      _AdvancedAttendanceTrackingWidgetState();
}

class _AdvancedAttendanceTrackingWidgetState
    extends State<AdvancedAttendanceTrackingWidget>
    with TickerProviderStateMixin {
  bool _trackAttendance = false;
  bool _locationCheckIn = false;
  bool _qrCodeCheckIn = false;
  prefix.LatLng? _selectedLocation;
  double? _selectedRadius;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _locationAnimationController;
  late Animation<double> _locationAnimation;
  String _qrData = '';
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _locationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _locationAnimation = CurvedAnimation(
      parent: _locationAnimationController,
      curve: Curves.easeInOut,
    );
    _generateQRCode();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _locationAnimationController.dispose();
    super.dispose();
  }

  void _generateQRCode() {
    // Generate a unique QR code for the event
    _qrData = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.themeColor.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  heightFactor: _animation.value,
                  child: child,
                ),
              );
            },
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Column(
                    children: [
                      _buildLocationCheckIn(),
                      //                   SizedBox(height: 16),
                      //                   _buildQRCodeCheckIn(),
                    ],
                  ),
                )),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: Offset(0.95, 0.95));
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () {
        setState(() {
          _trackAttendance = !_trackAttendance;
          if (_trackAttendance) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
        });
        widget.onTrackAttendanceChanged(_trackAttendance);
      },
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.people,
              color: widget.themeColor,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Attendance Tracking',
                style: GoogleFonts.poppins(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.7,
              child: _CustomSwitch(
                value: _trackAttendance,
                onChanged: (val) {
                  setState(() {
                    _trackAttendance = val;
                    if (val) {
                      _animationController.forward();
                    } else {
                      _animationController.reverse();
                    }
                  });
                  widget.onTrackAttendanceChanged(val);
                },
                activeColor: widget.themeColor,
                inactiveColor:
                    widget.isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCheckIn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on,
              color: widget.themeColor,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location Check-in',
                style: GoogleFonts.poppins(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.7,
              child: _CustomSwitch(
                value: _locationCheckIn,
                onChanged: (val) {
                  setState(() {
                    _locationCheckIn = val;
                    if (val) {
                      _locationAnimationController.forward();
                    } else {
                      _locationAnimationController.reverse();
                    }
                  });
                  widget.onLocationCheckInChanged(val);
                },
                activeColor: widget.themeColor,
                inactiveColor:
                    widget.isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
              ),
            )
          ],
        ),
        SizeTransition(
          sizeFactor: _locationAnimation,
          child: Column(
            children: [
              SizedBox(height: 12),
              _buildLocationSelector(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSelector() {
    return InkWell(
        onTap: _selectLocation,
        child: Padding(
          padding: EdgeInsets.only(left: 20),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.themeColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedLocation != null
                      ? Icons.check_circle
                      : Icons.add_location,
                  color: widget.themeColor,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLocation != null
                        ? 'Location selected'
                        : 'Select check-in location',
                    style: GoogleFonts.poppins(
                      color:
                          widget.isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: widget.themeColor,
                  size: 14,
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildQRCodeCheckIn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.qr_code,
              color: widget.themeColor,
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'QR Code Check-in',
                style: GoogleFonts.poppins(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.7,
              child: _CustomSwitch(
                value: _qrCodeCheckIn,
                onChanged: (val) {
                  setState(() {
                    _qrCodeCheckIn = val;
                  });
                  widget.onQrCodeCheckInChanged(val);
                },
                activeColor: widget.themeColor,
                inactiveColor:
                    widget.isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
              ),
            )
          ],
        ),
        if (_qrCodeCheckIn) ...[
          SizedBox(height: 12),
          Center(
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 120.0,
              eyeStyle: QrEyeStyle(color: widget.themeColor),
              backgroundColor:
                  widget.isDarkMode ? Colors.grey[800]! : Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Scan this QR code to check in',
              style: GoogleFonts.poppins(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _selectLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectionPage(
          initialLocation:
              _selectedLocation ?? prefix.LatLng(37.7749, -122.4194),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedLocation = result['location'];
        _selectedRadius = result['radius'];
      });
      widget.onLocationSelected(_selectedLocation!, _selectedRadius!);
    }
  }
}

class _CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color inactiveColor;

  const _CustomSwitch({
    Key? key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.inactiveColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value ? activeColor : inactiveColor,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: value ? 22 : 0,
              right: value ? 0 : 22,
              top: 2,
              bottom: 2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RepeatEventsWidget extends StatefulWidget {
  final Color themeColor;
  final bool isDarkMode;
  final Function(RepeatEventSettings) onRepeatSettingsChanged;

  RepeatEventsWidget({
    required this.themeColor,
    required this.isDarkMode,
    required this.onRepeatSettingsChanged,
  });

  @override
  _RepeatEventsWidgetState createState() => _RepeatEventsWidgetState();
}

class _RepeatEventsWidgetState extends State<RepeatEventsWidget> {
  bool _repeatEvent = false;
  RepeatFrequency _frequency = RepeatFrequency.weekly;
  int _interval = 1;
  List<bool> _selectedDays = List.generate(7, (_) => false);
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              'Repeat',
              style: TextStyle(
                fontFamily: 'roboto',
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: CupertinoSwitch(
              value: _repeatEvent,
              onChanged: (val) {
                setState(() {
                  _repeatEvent = val;
                  if (!val) _endDate = null;
                });
                _updateRepeatSettings();
              },
              activeColor: widget.themeColor,
            ),
          ),
          if (_repeatEvent) ...[
            Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
            _buildFrequencyPicker(),
            Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
            _buildIntervalPicker(),
            if (_frequency == RepeatFrequency.weekly) ...[
              Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
              _buildDaySelector(),
            ],
            Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
            _buildEndDatePicker(),
          ],
        ],
      ),
    );
  }

  Widget _buildFrequencyPicker() {
    return ListTile(
      title: Text(
        'Frequency',
        style: TextStyle(
          fontFamily: 'roboto',
          color: widget.isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Text(
          _getFrequencyDisplayText(_frequency),
          style: TextStyle(fontFamily: 'roboto', color: widget.themeColor),
        ),
        onPressed: () {
          showCupertinoModalPopup(
            context: context,
            builder: (BuildContext context) => Container(
              height: 200,
              color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
              child: CupertinoPicker(
                itemExtent: 32.0,
                onSelectedItemChanged: (int index) {
                  setState(() {
                    _frequency = RepeatFrequency.values[index];
                  });
                  _updateRepeatSettings();
                },
                children: RepeatFrequency.values
                    .map((f) => Text(_getFrequencyDisplayText(f)))
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getFrequencyDisplayText(RepeatFrequency frequency) {
    switch (frequency) {
      case RepeatFrequency.daily:
        return 'Daily';
      case RepeatFrequency.weekly:
        return 'Weekly';
      case RepeatFrequency.monthly:
        return 'Monthly';
      case RepeatFrequency.yearly:
        return 'Yearly';
    }
  }

  String _getEveryDisplayText(RepeatFrequency frequency) {
    switch (frequency) {
      case RepeatFrequency.daily:
        return 'Days';
      case RepeatFrequency.weekly:
        return 'Weeks';
      case RepeatFrequency.monthly:
        return 'Months';
      case RepeatFrequency.yearly:
        return 'Years';
    }
  }

  Widget _buildIntervalPicker() {
    return ListTile(
      title: Text(
        'Every',
        style: TextStyle(
          fontFamily: 'roboto',
          color: widget.isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Text(
          '$_interval ${_getEveryDisplayText(_frequency)}',
          style: TextStyle(fontFamily: 'roboto', color: widget.themeColor),
        ),
        onPressed: () {
          showCupertinoModalPopup(
            context: context,
            builder: (BuildContext context) => Container(
              height: 200,
              color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
              child: CupertinoPicker(
                itemExtent: 32.0,
                onSelectedItemChanged: (int index) {
                  setState(() {
                    _interval = index + 1;
                  });
                  _updateRepeatSettings();
                },
                children: List.generate(30, (index) => Text('${index + 1}')),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < 7; i++)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDays[i] = !_selectedDays[i];
                });
                _updateRepeatSettings();
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedDays[i]
                      ? widget.themeColor
                      : (widget.isDarkMode
                          ? Colors.grey[800]
                          : Colors.grey[200]),
                ),
                child: Center(
                  child: Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                    style: TextStyle(
                      fontFamily: 'roboto',
                      color: _selectedDays[i]
                          ? Colors.white
                          : (widget.isDarkMode
                              ? Colors.white70
                              : Colors.black87),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEndDatePicker() {
    return ListTile(
      title: Text(
        'End Date',
        style: TextStyle(
          fontFamily: 'roboto',
          color: widget.isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Text(
          _endDate != null
              ? DateFormat('MMM d, y').format(_endDate!)
              : 'Select',
          style: TextStyle(fontFamily: 'roboto', color: widget.themeColor),
        ),
        onPressed: () {
          showCupertinoModalPopup(
            context: context,
            builder: (BuildContext context) => Container(
              height: 200,
              color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime:
                    _endDate ?? DateTime.now().add(Duration(days: 1)),
                minimumDate: DateTime.now(),
                maximumDate: DateTime.now()
                    .add(Duration(days: 3650)), // 10 years from now
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _endDate = newDate;
                  });
                  _updateRepeatSettings();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateRepeatSettings() {
    widget.onRepeatSettingsChanged(
      RepeatEventSettings(
        enabled: _repeatEvent,
        frequency: _frequency,
        interval: _interval,
        selectedDays: _selectedDays,
        endDate: _endDate,
      ),
    );
  }
}

enum RepeatFrequency { daily, weekly, monthly, yearly }

class RepeatEventSettings {
  final bool enabled;
  final RepeatFrequency frequency;
  final int interval;
  final List<bool> selectedDays;
  final DateTime? endDate;

  RepeatEventSettings({
    required this.enabled,
    required this.frequency,
    required this.interval,
    required this.selectedDays,
    this.endDate,
  });
}
