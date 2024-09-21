import 'package:flutter/material.dart' hide CarouselController;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:geocoding/geocoding.dart';

class LocationSelectionPage extends StatefulWidget {
  final LatLng initialLocation;

  LocationSelectionPage({required this.initialLocation});

  @override
  _LocationSelectionPageState createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  LatLng _selectedLocation = LatLng(0, 0);
  double _radius = 50; // Initial radius in feet
  bool _isLoading = false;
  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _checkLocationPermissionAndService();
  }

  Future<void> _checkLocationPermissionAndService() async {
    setState(() {
      _isLoading = true;
    });

    _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!_locationServiceEnabled) {
      setState(() {
        _isLoading = false;
      });
      _showLocationServiceDialog();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied
        setState(() {
          _isLoading = false;
          _locationPermissionGranted = false;
        });
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      setState(() {
        _isLoading = false;
        _locationPermissionGranted = false;
      });
      _showPermissionDeniedForeverDialog();
      return;
    }

    // Permission granted
    setState(() {
      _locationPermissionGranted = true;
    });
    await _useCurrentLocation();

    setState(() {
      _isLoading = false;
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Required'),
          content:
              Text('Please grant location permission to use this feature.'),
          actions: <Widget>[
            TextButton(
              child: Text('Try Again'),
              onPressed: () {
                Navigator.of(context).pop();
                _checkLocationPermissionAndService();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Required'),
          content: Text(
              'Location permission is denied permanently. Please enable it in your device settings.'),
          actions: <Widget>[
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                Geolocator.openAppSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Services Disabled'),
          content: Text('Please enable location services to use this feature.'),
          actions: <Widget>[
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _addMarkerAndCircle(LatLng position) {
    setState(() {
      _markers.clear();
      _circles.clear();
      _markers.add(Marker(
        markerId: MarkerId('selected_location'),
        position: position,
      ));
      _circles.add(Circle(
        circleId: CircleId('check_in_radius'),
        center: position,
        radius: _radius * 0.3048, // Convert feet to meters
        fillColor: Colors.blue.withOpacity(0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ));
    });
  }

  Future<void> _searchLocation() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<Location> locations =
          await locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        setState(() {
          _selectedLocation =
              LatLng(locations.first.latitude, locations.first.longitude);
          _addMarkerAndCircle(_selectedLocation);
        });
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation, 15));
      } else {
        throw Exception('No results found');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to find location: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Select Location'),
        backgroundColor: Colors.grey[900],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 15,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    setState(() {
                      _mapController = controller;
                    });
                    controller.setMapStyle(_mapDarkStyle);
                  },
                  markers: _markers,
                  circles: _circles,
                  onTap: (LatLng position) {
                    setState(() {
                      _selectedLocation = position;
                      _addMarkerAndCircle(position);
                    });
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildSearchBar(),
                ),
                Positioned(
                  top: 80,
                  right: 16,
                  child: _buildCurrentLocationButton(),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search for a location',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _searchLocation(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: _searchLocation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationButton() {
    return FloatingActionButton(
      child: Icon(Icons.my_location),
      onPressed: _useCurrentLocation,
      backgroundColor: Colors.blue,
    );
  }

  Widget _buildBottomCard() {
    return Card(
      color: Colors.grey[800],
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tap on the map to select a location',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              'Check-in Radius: ${_radius.toStringAsFixed(0)} feet',
              style: TextStyle(color: Colors.white),
            ),
            Slider(
              value: _radius,
              min: 10,
              max: 200,
              divisions: 19,
              activeColor: Colors.blue,
              thumbColor: Colors.blue,
              label: _radius.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _radius = value;
                  _addMarkerAndCircle(_selectedLocation);
                });
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              child: Text('Confirm Location'),
              onPressed: _locationPermissionGranted && _locationServiceEnabled
                  ? () {
                      Navigator.pop(context, {
                        'location': _selectedLocation,
                        'radius': _radius,
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: Size(double.infinity, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (!_locationPermissionGranted || !_locationServiceEnabled) {
      await _checkLocationPermissionAndService();
      if (!_locationPermissionGranted || !_locationServiceEnabled) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _addMarkerAndCircle(_selectedLocation);
      });
      _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation, 15));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to get current location: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  final String _mapDarkStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "elementType": "labels.icon",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "administrative.country",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#9e9e9e"
        }
      ]
    },
    {
      "featureType": "administrative.land_parcel",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#bdbdbd"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#181818"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#616161"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1b1b1b"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#2c2c2c"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#8a8a8a"
        }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#373737"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#3c3c3c"
        }
      ]
    },
    {
      "featureType": "road.highway.controlled_access",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#4e4e4e"
        }
      ]
    },
    {
      "featureType": "road.local",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#616161"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#000000"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#3d3d3d"
        }
      ]
    }
  ]
  ''';
}
