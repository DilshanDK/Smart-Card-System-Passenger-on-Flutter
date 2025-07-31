// ignore_for_file: avoid_print, depend_on_referenced_packages, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

class TrackingService extends ChangeNotifier {
  // API Key for OpenRouteService
  final String _orsApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRhMmI5ODFkNWM3MzliYTQ0Mjk1MDJjZDRiMDA5MjMzN2I0MzBjYWU2OGUyMjU1YjBiOTVmNmNlIiwiaCI6Im11cm11cjY0In0=';
  
  // State variables
  List<Map<String, dynamic>> _busRoutes = [];
  Map<String, dynamic>? _selectedRouteDetails;
  String? _selectedRouteId;
  List<Map<String, dynamic>> _activeBuses = [];
  double _walletBalance = 0.0;
  bool _isBalanceSufficient = true;
  double _routeCost = 0.0;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _showBusMarkers = true;
  bool _isLoadingRoute = false;
  bool _isLoadingWallet = true;
  Timer? _busLocationTimer;
  Timer? _blinkTimer;
  LatLng? _userLocation;
  Map<String, dynamic> _etaInfo = {};
  List<LatLng> _mainStopLatLngs = []; // Added to store main stop coordinates for bounds

  // Custom marker icons
  BitmapDescriptor? mainStopIcon;
  BitmapDescriptor? subStopIcon;
  BitmapDescriptor? busIcon;
  BitmapDescriptor? myLocationIcon;
  
  // Getters
  List<Map<String, dynamic>> get busRoutes => _busRoutes;
  Map<String, dynamic>? get selectedRouteDetails => _selectedRouteDetails;
  String? get selectedRouteId => _selectedRouteId;
  List<Map<String, dynamic>> get activeBuses => _activeBuses;
  double get walletBalance => _walletBalance;
  bool get isBalanceSufficient => _isBalanceSufficient;
  double get routeCost => _routeCost;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  bool get showBusMarkers => _showBusMarkers;
  bool get isLoadingRoute => _isLoadingRoute;
  bool get isLoadingWallet => _isLoadingWallet;
  Map<String, dynamic> get etaInfo => _etaInfo;
  LatLng? get userLocation => _userLocation;
  List<LatLng> get mainStopLatLngs => _mainStopLatLngs; // Getter for main stop coordinates

  // Constructor
  TrackingService() {
    _startBlinking();
  }

  // Update markers (useful for blinking effect from UI)
  void updateMarkers(Set<Marker> newMarkers) {
    _markers = newMarkers;
    notifyListeners();
  }

  // Initialize marker icons
  Future<void> initializeMarkerIcons() async {
    mainStopIcon = await _createCustomMarkerIcon(
      Icons.share_location_rounded,
      const ui.Color.fromARGB(255, 150, 0, 40),
      120.0,
    );
    subStopIcon = await _createCustomMarkerIcon(
      Icons.location_pin,
      const ui.Color.fromARGB(255, 91, 128, 156),
      70.0,
    );
    busIcon = await _createCustomMarkerIcon(
      Icons.directions_bus_rounded,
      const ui.Color.fromARGB(255, 8, 11, 195),
      100.0,
    );
    myLocationIcon = await _createCustomMarkerIcon(
      Icons.radio_button_checked,
      const ui.Color.fromARGB(255, 12, 161, 104),
      60.0,
    );
    notifyListeners();
  }

  // Create custom marker icons
  Future<BitmapDescriptor> _createCustomMarkerIcon(
    IconData iconData,
    Color color,
    double size,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final iconStr = String.fromCharCode(iconData.codePoint);

    textPainter.text = TextSpan(
      text: iconStr,
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = bytes!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  // Start blinking effect for bus markers
  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _showBusMarkers = !_showBusMarkers;
      _updateBusMarkers();
      notifyListeners();
    });
  }

  // Set user's current location
  void setUserLocation(LatLng location) {
    _userLocation = location;
    _addUserLocationMarker();
    _calculateETAs();
    notifyListeners();
  }

  // Add user location marker
  void _addUserLocationMarker() {
    if (_userLocation == null) return;

    // Remove previous user location marker if exists
    _markers.removeWhere((marker) => marker.markerId.value == 'user_location');

    // Add new marker
    _markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: _userLocation!,
        icon: myLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Your Location'),
        zIndex: 3, // Put user marker on top
      ),
    );
    
    notifyListeners();
  }

  // Update bus markers (used for blinking effect)
  void _updateBusMarkers() {
    if (_activeBuses.isEmpty) return;

    // Remove all existing bus markers
    _markers.removeWhere((marker) => marker.markerId.value.startsWith('bus_'));

    // Only add them back if they should be visible
    if (_showBusMarkers) {
      for (final bus in _activeBuses) {
        final location = bus['location'];
        if (location is GeoPoint) {
          final busId = bus['id'];
          
          // Get ETA information if available
          String etaInfo = '';
          if (_etaInfo.containsKey(busId)) {
            final etaMinutes = _etaInfo[busId]['minutes'];
            final etaTime = _etaInfo[busId]['arrivalTime'];
            etaInfo = ' - ETA: $etaMinutes min (${_formatTime(etaTime)})';
          }
          
          _markers.add(
            Marker(
              markerId: MarkerId('bus_$busId'),
              position: LatLng(location.latitude, location.longitude),
              icon: busIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: bus['busNumber'] ?? 'The Bus',
                snippet: 'Speed: ${(bus['speed'] ?? 0).toStringAsFixed(1)} km/h$etaInfo',
              ),
              zIndex: 2,
              rotation: bus['heading']?.toDouble() ?? 0.0, // Added rotation based on bus heading
            ),
          );
        }
      }
    }
  }

  // Format time for display
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Calculate ETAs for all active buses to user's location
  Future<void> _calculateETAs() async {
  if (_userLocation == null || _activeBuses.isEmpty) return;

  for (final bus in _activeBuses) {
    final location = bus['location'];
    if (location is! GeoPoint) continue; // Skip if location is invalid
    final busId = bus['id'];
    final busPosition = LatLng(location.latitude, location.longitude);
    final speed = (bus['speed'] is num && bus['speed'] > 0) ? (bus['speed'] as num).toDouble() : 30.0; // Default to 30 km/h

    try {
      // Calculate road distance using OpenRouteService
      final distanceInMeters = await _calculateRoadDistance(busPosition, _userLocation!);
      final speedInMps = speed * 1000 / 3600; // Convert km/h to m/s
      double timeInMinutes = distanceInMeters / speedInMps / 60;
      timeInMinutes = timeInMinutes < 1 ? 1 : timeInMinutes.roundToDouble();

      // Calculate arrival time
      final now = DateTime.now();
      final arrivalTime = now.add(Duration(minutes: timeInMinutes.toInt()));

      // Store ETA information
      _etaInfo[busId] = {
        'minutes': timeInMinutes.toInt(),
        'arrivalTime': arrivalTime,
        'distance': distanceInMeters / 1000, // in km
        'isEstimate': false,
      };
    } catch (e) {
      print('Error calculating ETA for bus $busId: $e');
      _calculateSimpleETA(busId, busPosition, speed);
    }
  }

  _updateBusMarkers();
  notifyListeners();
}
  // Get nearest bus to user location
  Map<String, dynamic>? getNearestBus() {
    if (_userLocation == null || _activeBuses.isEmpty || _etaInfo.isEmpty) {
      return null;
    }

    String? nearestBusId;
    int? shortestEta;
    
    _etaInfo.forEach((busId, info) {
      final minutes = info['minutes'] as int;
      if (shortestEta == null || minutes < shortestEta!) {
        shortestEta = minutes;
        nearestBusId = busId;
      }
    });
    
    if (nearestBusId != null) {
      final nearestBus = _activeBuses.firstWhere(
        (bus) => bus['id'] == nearestBusId,
        orElse: () => _activeBuses.first,
      );
      
      return {
        'bus': nearestBus,
        'eta': _etaInfo[nearestBusId],
      };
    }
    
    return null;
  }

  // Get start and end stops
  List<LatLng> getStartEndStopLocations() {
    final result = <LatLng>[];
    
    if (_selectedRouteDetails != null) {
      final mainStops = _selectedRouteDetails!['main_stops'] ?? [];
      if (mainStops.isNotEmpty) {
        // Get first stop
        final firstStop = mainStops.first;
        final firstStopLocation = firstStop['location'];
        if (firstStopLocation is GeoPoint) {
          result.add(LatLng(firstStopLocation.latitude, firstStopLocation.longitude));
        }
        
        // Get last stop
        if (mainStops.length > 1) {
          final lastStop = mainStops.last;
          final lastStopLocation = lastStop['location'];
          if (lastStopLocation is GeoPoint) {
            result.add(LatLng(lastStopLocation.latitude, lastStopLocation.longitude));
          }
        }
      }
    }
    
    return result;
  }

  // Simple ETA calculation as fallback
  void _calculateSimpleETA(String busId, LatLng busPosition, double speed) {
    if (_userLocation == null) return;
    
    try {
      // Calculate direct distance
      final lat1 = busPosition.latitude;
      final lon1 = busPosition.longitude;
      final lat2 = _userLocation!.latitude;
      final lon2 = _userLocation!.longitude;
      
      // Haversine formula
      const R = 6371000; // Earth radius in meters
      final phi1 = lat1 * pi / 180;
      final phi2 = lat2 * pi / 180;
      final deltaPhi = (lat2 - lat1) * pi / 180;
      final deltaLambda = (lon2 - lon1) * pi / 180;
      
      final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
          cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      final distanceInMeters = R * c;
      
      // Apply a route factor to account for roads
      final estimatedRoadDistance = distanceInMeters * 1.3;
      
      // Calculate time in minutes
      final speedInMps = speed * 1000 / 3600; // Convert km/h to m/s
      double timeInMinutes = estimatedRoadDistance / speedInMps / 60;
      
      // Round to nearest minute with minimum of 1 minute
      timeInMinutes = timeInMinutes < 1 ? 1 : timeInMinutes.roundToDouble();
      
      // Calculate arrival time
      final now = DateTime.now();
      final arrivalTime = now.add(Duration(minutes: timeInMinutes.toInt()));
      
      // Store ETA information
      _etaInfo[busId] = {
        'minutes': timeInMinutes.toInt(),
        'arrivalTime': arrivalTime,
        'distance': estimatedRoadDistance / 1000, // in km
        'isEstimate': true,
      };
    } catch (e) {
      print('Error in simple ETA calculation: $e');
    }
  }

  // Calculate road distance using OpenRouteService
  Future<double> _calculateRoadDistance(LatLng start, LatLng end) async {
    final url = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car');
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': _orsApiKey,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'coordinates': [
          [start.longitude, start.latitude],
          [end.longitude, end.latitude]
        ],
        'instructions': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['routes'][0]['summary']['distance'].toDouble();
    } else {
      throw Exception('Failed to calculate road distance');
    }
  }

  // Fetch wallet balance
  Future<void> fetchWalletBalance() async {
    _isLoadingWallet = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final doc = await FirebaseFirestore.instance
          .collection('passengers')
          .doc(user.uid)
          .get();

      if (!doc.exists) throw Exception('Passenger profile not found');

      final data = doc.data();
      if (data == null) throw Exception('No data found in passenger profile');

      final balance = data['walletBalance'] as num?;

      _walletBalance = balance?.toDouble() ?? 0.0;
      _isLoadingWallet = false;
      
      // Check balance sufficiency if a route is selected
      if (_selectedRouteId != null) {
        _checkBalanceSufficiency();
      }
      
      notifyListeners();
    } catch (e) {
      print('Error fetching wallet balance: $e');
      _walletBalance = 0.0;
      _isLoadingWallet = false;
      notifyListeners();
    }
  }

  // Fetch available bus routes
  Future<void> fetchRoutes() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('routes').get();
      if (snapshot.docs.isEmpty) return;
      
      _busRoutes = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final routeName = data['routeName'];
            if (routeName is String && routeName.isNotEmpty) {
              return {
                'id': doc.id,
                'name': routeName,
                'routeId': data['routeId'] ?? doc.id,
                'startStop': data['startStop'] ?? 'Unknown',
                'endStop': data['endStop'] ?? 'Unknown',
                'distance': data['distance'] ?? 0.0,
                'costPerKm': data['costPerKm'] ?? 25.0,
              };
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
          
      notifyListeners();
    } catch (e) {
      print('Error fetching routes: $e');
    }
  }

  // Select a route
  void selectRoute(String? routeId) {
    _selectedRouteId = routeId;
    _markers = {};
    _polylines = {};
    _activeBuses = [];
    _etaInfo = {};
    _mainStopLatLngs = []; // Clear main stop coordinates
    
    if (routeId != null) {
      _checkBalanceSufficiency();
    }
    
    notifyListeners();
  }

  // Check if wallet balance is sufficient for selected route
  void _checkBalanceSufficiency() {
    if (_selectedRouteId == null) return;

    final selectedRouteData = _busRoutes.firstWhere(
      (route) => route['id'] == _selectedRouteId,
      orElse: () => {},
    );

    final cost = _calculateRouteCost(selectedRouteData);

    _routeCost = cost;
    _isBalanceSufficient = _walletBalance >= cost;
    
    notifyListeners();
  }

  // Calculate cost of a route
  double _calculateRouteCost(Map<String, dynamic>? routeData) {
    if (routeData == null) return 0.0;

    double distance = routeData['distance'] is num
        ? (routeData['distance'] as num).toDouble()
        : 0.0;
    double costPerKm = routeData['costPerKm'] is num
        ? (routeData['costPerKm'] as num).toDouble()
        : 25.0;

    return distance * costPerKm;
  }

  // Fetch stops and bus data for selected route
  Future<void> fetchStopsAndBuses() async {
    if (_selectedRouteId == null) return;

    _isLoadingRoute = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('routes')
          .doc(_selectedRouteId)
          .get();
          
      if (!doc.exists) {
        _isLoadingRoute = false;
        notifyListeners();
        return;
      }

      final data = doc.data();
      if (data == null) {
        _isLoadingRoute = false;
        notifyListeners();
        return;
      }

      _selectedRouteDetails = data;

      final List<dynamic> mainStops = data['main_stops'] ?? [];
      final List<dynamic> subStops = data['sub_stops'] ?? [];

      final List<LatLng> mainStopLatLngs = [];
      final Set<Marker> markers = {};

      // Add main stops markers
      for (int i = 0; i < mainStops.length; i++) {
        final stop = mainStops[i];
        final location = stop['location'];
        if (location is GeoPoint) {
          final position = LatLng(location.latitude, location.longitude);
          mainStopLatLngs.add(position);

          markers.add(
            Marker(
              markerId: MarkerId('main_stop_${stop['mainId'] ?? i}'),
              position: position,
              icon: mainStopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: stop['name'] ?? 'Main Stop ${i + 1}',
              ),
            ),
          );
        }
      }

      // Store main stop coordinates for bounds calculation
      _mainStopLatLngs = mainStopLatLngs;

      // Add sub stops markers
      for (int i = 0; i < subStops.length; i++) {
        final stop = subStops[i];
        final location = stop['location'];
        if (location is GeoPoint) {
          final position = LatLng(location.latitude, location.longitude);

          markers.add(
            Marker(
              markerId: MarkerId('sub_stop_${stop['subId'] ?? i}'),
              position: position,
              icon: subStopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: InfoWindow(
                title: stop['name'] ?? 'Sub Stop ${i + 1}',
              ),
            ),
          );
        }
      }

      // Add user location marker if available
      if (_userLocation != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: _userLocation!,
            icon: myLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Your Location'),
            zIndex: 3, // Put user marker on top
          ),
        );
      }

      // Create route polylines
      Set<Polyline> polylines = {};
      for (int i = 0; i < mainStopLatLngs.length - 1; i++) {
        final segment = await _fetchDrivingRoute([
          mainStopLatLngs[i],
          mainStopLatLngs[i + 1],
        ]);
        if (segment.length > 1) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('main_route_$i'),
              points: segment,
              color: Colors.blue,
              width: 5,
              visible: true,
            ),
          );
        }
      }

      _markers = markers;
      _polylines = polylines;
      _isLoadingRoute = false;
      
      notifyListeners();
      
      // Start listening for live bus updates
      _startLiveBusTracking();
      
    } catch (e) {
      print('Error fetching stops and buses: $e');
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  // Get route for drawing polylines
  Future<List<LatLng>> _fetchDrivingRoute(List<LatLng> waypoints) async {
    try {
      final coordinates = waypoints.map((p) => [p.longitude, p.latitude]).toList();
      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': _orsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coordinates': coordinates,
          'preference': 'recommended',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coords = data['features'][0]['geometry']['coordinates'];
        return coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      } else {
        print('Failed to fetch route: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching driving route: $e');
      return [];
    }
  }

  // Start tracking live buses
  void _startLiveBusTracking() {
    _busLocationTimer?.cancel();

    FirebaseFirestore.instance
        .collection('live_track')
        .where('routeId', isEqualTo: _selectedRouteId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
          final List<Map<String, dynamic>> buses = snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'busNumber': doc.data()['busNumber'] ?? 'The Bus',
              'speed': doc.data()['speed'] ?? 0.0,
              'lastUpdate': doc.data()['lastUpdated'] ?? Timestamp.now(),
              'location': doc.data()['location'],
              'heading': doc.data()['heading'] ?? 0.0,
            };
          }).toList();
          
          _activeBuses = buses;
          
          // Update markers with new bus positions
          _updateBusMarkers();
          
          // Calculate ETAs if user location is available
          if (_userLocation != null) {
            _calculateETAs();
          }
          
          notifyListeners();
        });
  }

  // Dispose of resources
  @override
  void dispose() {
    _blinkTimer?.cancel();
    _busLocationTimer?.cancel();
    super.dispose();
  }
}