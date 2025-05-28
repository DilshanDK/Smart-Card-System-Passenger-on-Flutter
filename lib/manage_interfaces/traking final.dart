// ignore_for_file: use_build_context_synchronously, deprecated_member_use, file_names, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'dart:convert';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  String? _selectedRouteId;
  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _busRoutes = [];
  final String _orsApiKey =
      '5b3ce3597851110001cf62487871ef21d79ae69eb50d7dac820cb128c479b6513d7d159fad21ed94';

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
    _requestLocationPermission();
  }

  Future<void> _fetchRoutes() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('routes').get();
      if (snapshot.docs.isEmpty) {
        _showSnackBar('No routes available.', color: Colors.orange);
        return;
      }
      setState(() {
        _busRoutes = snapshot.docs
            .map((doc) {
              final data = doc.data();
              final routeName = data['routeName'];
              if (routeName is String && routeName.isNotEmpty) {
                return {
                  'id': doc.id,
                  'name': routeName,
                  'routeId': data['routeId'] ?? doc.id,
                };
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    } catch (e, stack) {
      developer.log('Error fetching routes: $e', error: e, stackTrace: stack);
      _showSnackBar('Failed to load routes: $e', color: Colors.red);
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        setState(() {
          _locationPermissionGranted = true;
        });
        if (_selectedRouteId != null) {
          await _fetchStops();
        }
      } else {
        setState(() {
          _locationPermissionGranted = false;
        });
        _showSnackBar(
          'Location permission denied. Map may not work properly.',
          color: Colors.red,
        );
      }
    } catch (e, stack) {
      developer.log('Error requesting location permission: $e', error: e, stackTrace: stack);
      _showSnackBar('Error requesting permission.', color: Colors.red);
    }
  }

  void _showSnackBar(String message, {Color color = Colors.blue}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
      ),
    );
  }

  Future<List<LatLng>> _fetchStops() async {
    if (_selectedRouteId == null) return [];

    try {
      final doc = await FirebaseFirestore.instance.collection('routes').doc(_selectedRouteId).get();
      if (!doc.exists) {
        _showSnackBar('Route not found.', color: Colors.red);
        return [];
      }

      final data = doc.data();
      if (data == null) return [];

      final List<dynamic> mainStops = data['main_stops'] ?? [];
      final List<dynamic> subStops = data['sub_stops'] ?? [];

      final List<LatLng> allStopPoints = [];
      final Set<Marker> stopMarkers = {};
      final List<LatLng> mainStopPoints = [];

      // Main stops (red for first/last, orange for others)
      for (int i = 0; i < mainStops.length; i++) {
        final stop = mainStops[i];
        final location = stop['location'];
        if (location is GeoPoint) {
          final position = LatLng(location.latitude, location.longitude);
          allStopPoints.add(position);
          mainStopPoints.add(position);

          BitmapDescriptor markerIcon;
          if (i == 0 || i == mainStops.length - 1) {
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
          } else {
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
          }

          stopMarkers.add(
            Marker(
              markerId: MarkerId('main_stop_${stop['mainId'] ?? i}'),
              position: position,
              infoWindow: InfoWindow(title: stop['name'] ?? 'Main Stop ${i + 1}'),
              icon: markerIcon,
            ),
          );
        }
      }

      // Sub stops (blue)
      final sortedSubStops = List<dynamic>.from(subStops)
        ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
      for (int i = 0; i < sortedSubStops.length; i++) {
        final stop = sortedSubStops[i];
        final location = stop['location'];
        if (location is GeoPoint) {
          final position = LatLng(location.latitude, location.longitude);
          allStopPoints.add(position);

          stopMarkers.add(
            Marker(
              markerId: MarkerId('sub_stop_${stop['subId'] ?? i}'),
              position: position,
              infoWindow: InfoWindow(title: stop['name'] ?? 'Sub Stop ${i + 1}'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ),
          );
        }
      }

      // Draw polyline for actual route between main stops
      Set<Polyline> polylines = {};
      if (mainStopPoints.length >= 2) {
        final drivingRoute = await _fetchDrivingRoute(mainStopPoints);
        if (drivingRoute.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('driving_route'),
              points: drivingRoute,
              color: const Color.fromARGB(255, 18, 86, 204),
              width: 5,
              visible: true,
            ),
          );
        }
      }

      setState(() {
        _markers = stopMarkers;
        _polylines = polylines;
      });

      // Adjust camera to fit all points
      final points = stopMarkers.map((m) => m.position).toList();
      if (points.isNotEmpty) {
        double minLat = points.first.latitude, maxLat = points.first.latitude;
        double minLng = points.first.longitude, maxLng = points.first.longitude;
        for (var p in points) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
        final latPad = (maxLat - minLat) * 0.1;
        final lngPad = (maxLng - minLng) * 0.1;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat - latPad, minLng - lngPad),
              northeast: LatLng(maxLat + latPad, maxLng + lngPad),
            ),
            100,
          ),
        );
      }

      return allStopPoints;
    } catch (e, stack) {
      developer.log('Error fetching stops: $e', error: e, stackTrace: stack);
      _showSnackBar('Failed to load stops: $e', color: Colors.red);
      return [];
    }
  }

  Future<List<LatLng>> _fetchDrivingRoute(List<LatLng> waypoints) async {
    try {
      final coordinates = waypoints.map((p) => [p.longitude, p.latitude]).toList();
      final url = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson');
      final response = await http.post(
        url,
        headers: {
          'Authorization': _orsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'coordinates': coordinates, 'preference': 'recommended'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coords = data['features'][0]['geometry']['coordinates'];
        return coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      } else {
        developer.log('Failed to fetch route: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e, stack) {
      developer.log('Error fetching driving route: $e', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Track Your Bus',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _selectedRouteId != null
                    ? _busRoutes.firstWhere((r) => r['id'] == _selectedRouteId, orElse: () => {'name': 'Select a Route'})['name']
                    : 'Select a Route',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route, color: Colors.blueGrey[900]),
                          const SizedBox(width: 10),
                          Text(
                            'Bus Route',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedRouteId,
                        hint: Text(
                          'Choose a route',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                        items: _busRoutes.map((route) {
                          return DropdownMenuItem<String>(
                            value: route['id'],
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                route['name'],
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.blueGrey[900],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRouteId = newValue;
                            _markers.clear();
                            _polylines.clear();
                            if (_locationPermissionGranted && newValue != null) {
                              _fetchStops();
                            } else if (!_locationPermissionGranted) {
                              _requestLocationPermission();
                            }
                          });
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey[900]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_selectedRouteId != null)
                Container(
                  height: 350,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _locationPermissionGranted
                        ? GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: const LatLng(7.2906, 80.6337),
                              zoom: 10,
                            ),
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                              if (_selectedRouteId != null) {
                                _fetchStops();
                              }
                            },
                            markers: _markers,
                            polylines: _polylines,
                            mapToolbarEnabled: true,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: true,
                            compassEnabled: true,
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_off,
                                  size: 50,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Location permission required',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: _requestLocationPermission,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: Text(
                                    'Request Permission',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}