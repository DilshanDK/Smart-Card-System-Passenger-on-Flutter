// ignore_for_file: depend_on_referenced_packages, unused_field, deprecated_member_use, avoid_print, unused_local_variable

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart' as loc;
import 'package:smart_card_app_passenger/services/tracking_service.dart';
import 'package:smart_card_app_passenger/themes/colors.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Controller for Google Maps
  GoogleMapController? _mapController;

  // State variables
  bool _locationPermissionGranted = false;
  bool _isFullScreenMap = false;
  bool _isRefreshing = false;
  bool _showLegend = false;
  Timer? _blinkTimer;
  bool _showBusMarkers = true;

  // Location service instance
  final _locationService = loc.Location();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _initializeServices();
    _startBlinking();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _showBusMarkers = !_showBusMarkers;
      });
      _updateBusMarkers();
    });
  }

  void _updateBusMarkers() {
    final trackingService = Provider.of<TrackingService>(
      context,
      listen: false,
    );
    if (trackingService.activeBuses.isEmpty) return;

    Set<Marker> markers = Set<Marker>.from(trackingService.markers);

    // Remove all existing bus markers
    markers.removeWhere((marker) => marker.markerId.value.startsWith('bus_'));

    // Only add them back if they should be visible
    if (_showBusMarkers) {
      for (final bus in trackingService.activeBuses) {
        final location = bus['location'];
        if (location is GeoPoint) {
          final busId = bus['id'];

          // Get ETA information if available
          String etaInfo = '';
          if (trackingService.etaInfo.containsKey(busId)) {
            final etaMinutes = trackingService.etaInfo[busId]['minutes'];
            final etaTime = trackingService.etaInfo[busId]['arrivalTime'];
            etaInfo = ' - ETA: $etaMinutes min';
          }

          markers.add(
            Marker(
              markerId: MarkerId('bus_$busId'),
              position: LatLng(location.latitude, location.longitude),
              icon:
                  trackingService.busIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
              infoWindow: InfoWindow(
                title: bus['busNumber'] ?? 'The Bus',
                snippet:
                    'Speed: ${(bus['speed'] ?? 0).toStringAsFixed(1)} km/h$etaInfo',
              ),
              zIndex: 2,
            ),
          );
        }
      }
    }

    // Update the service
    trackingService.updateMarkers(markers);
  }

  Future<void> _initializeServices() async {
    final trackingService = Provider.of<TrackingService>(
      context,
      listen: false,
    );

    // Initialize service data
    await trackingService.initializeMarkerIcons();
    await trackingService.fetchWalletBalance();
    await trackingService.fetchRoutes();

    // Start location updates if permission granted
    if (_locationPermissionGranted) {
      _startLocationUpdates();
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      setState(() {
        _locationPermissionGranted = status.isGranted;
      });

      if (status.isGranted) {
        _startLocationUpdates();
      } else {
        _showSnackBar(
          'Location permission denied. Map may not work properly.',
          color: AppColors.errorRed,
          duration: 4,
        );
      }
    } catch (e) {
      print('Error requesting location permission: $e');
      _showSnackBar('Error requesting permission', color: AppColors.errorRed);
    }
  }

  void _startLocationUpdates() async {
    try {
      final trackingService = Provider.of<TrackingService>(
        context,
        listen: false,
      );

      // Request location service
      await _locationService.requestService();

      // Configure location accuracy
      await _locationService.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 10000, // Update every 10 seconds
      );

      // Get initial location
      final initialLocation = await _locationService.getLocation();
      if (initialLocation.latitude != null &&
          initialLocation.longitude != null) {
        trackingService.setUserLocation(
          LatLng(initialLocation.latitude!, initialLocation.longitude!),
        );
      }

      // Listen for location changes
      _locationService.onLocationChanged.listen((loc.LocationData location) {
        if (location.latitude != null && location.longitude != null) {
          trackingService.setUserLocation(
            LatLng(location.latitude!, location.longitude!),
          );
        }
      });
    } catch (e) {
      print('Error starting location updates: $e');
    }
  }

  void _showSnackBar(
    String message, {
    Color color = AppColors.accentGreen,
    int duration = 2,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: duration),
      ),
    );
  }

  void _toggleFullScreenMap() {
    final trackingService = Provider.of<TrackingService>(
      context,
      listen: false,
    );

    if (!trackingService.isBalanceSufficient) {
      _showInsufficientBalanceDialog(trackingService.routeCost);
      return;
    }

    setState(() {
      _isFullScreenMap = !_isFullScreenMap;
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    final trackingService = Provider.of<TrackingService>(
      context,
      listen: false,
    );

    try {
      await trackingService.fetchWalletBalance();
      await trackingService.fetchRoutes();

      if (trackingService.selectedRouteId != null &&
          trackingService.isBalanceSufficient) {
        await trackingService.fetchStopsAndBuses();
      }

      _showSnackBar(
        'Data refreshed successfully',
        color: Colors.green,
      );
    } catch (e) {
      _showSnackBar('Failed to refresh data', color: AppColors.errorRed);
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Find nearest bus with shortest ETA
  void _focusOnNearestBus() {
    final trackingService = Provider.of<TrackingService>(
      context,
      listen: false,
    );

    if (_mapController != null &&
        trackingService.activeBuses.isNotEmpty &&
        trackingService.etaInfo.isNotEmpty) {
      // Find nearest bus (with shortest ETA)
      String? nearestBusId;
      int? shortestEta;

      trackingService.etaInfo.forEach((busId, info) {
        final minutes = info['minutes'] as int;
        if (shortestEta == null || minutes < shortestEta!) {
          shortestEta = minutes;
          nearestBusId = busId;
        }
      });

      if (nearestBusId != null) {
        // Find the bus location
        final bus = trackingService.activeBuses.firstWhere(
          (b) => b['id'] == nearestBusId,
          orElse: () => trackingService.activeBuses.first,
        );

        final location = bus['location'];
        if (location is GeoPoint) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(location.latitude, location.longitude),
              16.0,
            ),
          );
        }
      }
    }
  }

  // Focus on start and end stops
  void _focusOnStartEndStops() {
    final trackingService = Provider.of<TrackingService>(
      context,
      listen: false,
    );

    if (_mapController != null &&
        trackingService.selectedRouteDetails != null) {
      final mainStops =
          trackingService.selectedRouteDetails!['main_stops'] ?? [];
      if (mainStops.length >= 2) {
        final firstStop = mainStops.first;
        final lastStop = mainStops.last;

        if (firstStop['location'] is GeoPoint &&
            lastStop['location'] is GeoPoint) {
          final points = [
            LatLng(
              firstStop['location'].latitude,
              firstStop['location'].longitude,
            ),
            LatLng(
              lastStop['location'].latitude,
              lastStop['location'].longitude,
            ),
          ];
          _animateToBounds(points);
        }
      }
    }
  }

  void _showInsufficientBalanceDialog(double cost) {
    final trackingService = Provider.of<TrackingService>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.errorRed,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'Insufficient Balance',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your wallet balance is too low for this route.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.grey600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBalanceInfoRow(
                  'Current Balance',
                  'Rs. ${trackingService.walletBalance.toStringAsFixed(2)}',
                  AppColors.grey600,
                ),
                const SizedBox(height: 8),
                _buildBalanceInfoRow(
                  'Estimated Cost',
                  'Rs. ${trackingService.routeCost.toStringAsFixed(2)}',
                  AppColors.errorRed,
                ),
                const SizedBox(height: 8),
                _buildBalanceInfoRow(
                  'Shortage',
                  'Rs. ${(trackingService.routeCost - trackingService.walletBalance).toStringAsFixed(2)}',
                  AppColors.errorRed,
                ),
                const SizedBox(height: 16),
                Text(
                  'Top up your wallet to track buses and proceed.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.grey600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: AppColors.grey600),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/payment');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.account_balance_wallet,
                  size: 18,
                  color: AppColors.white,
                ),
                label: Text(
                  'Top Up Wallet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildBalanceInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.grey600),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<TrackingService>(
      builder: (context, trackingService, _) {
        return Scaffold(
          backgroundColor: AppColors.white,
          appBar:
              _isFullScreenMap
                  ? null
                  : AppBar(
                    backgroundColor: AppColors.white,
                    elevation: 0,
                    title: Text(
                      'Live Bus Tracker',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    centerTitle: true,
                    automaticallyImplyLeading: false,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/payment'),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 80),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  trackingService.isLoadingWallet
                                      ? AppColors.grey600.withOpacity(0.1)
                                      : AppColors.shadowGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    trackingService.isLoadingWallet
                                        ? AppColors.grey600
                                        : AppColors.accentGreen,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 16,
                                  color:
                                      trackingService.isLoadingWallet
                                          ? AppColors.grey600
                                          : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                trackingService.isLoadingWallet
                                    ? SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.grey600,
                                      ),
                                    )
                                    : Text(
                                      'Rs. ${trackingService.walletBalance.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          body: SafeArea(
            child:
                _isFullScreenMap
                    ? _buildFullScreenMap(trackingService)
                    : _buildNormalView(trackingService),
          ),
        );
      },
    );
  }

  // Full screen map view
  Widget _buildFullScreenMap(TrackingService trackingService) {
    return Stack(
      children: [
        _buildMap(trackingService),


        // Route selector positioned at top
        Positioned(
          top: 16 + MediaQuery.of(context).padding.top ,
          left: 16,
          right: 16,
          child: _buildRouteSelectorCard(trackingService, compact: true),
        ),

        // Map control buttons positioned at bottom right
        if (trackingService.selectedRouteId != null &&
            trackingService.isBalanceSufficient)
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                // My Location button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryDark,
                  onPressed: () {
                    if (_mapController != null &&
                        trackingService.userLocation != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: trackingService.userLocation!,
                            zoom: 16,
                          ),
                        ),
                      );
                    }
                  },
                  tooltip: 'Focus on Your Location',
                  child: const Icon(Icons.my_location, size: 24),
                ),
                const SizedBox(height: 8),

                // Nearest Bus button
                if (trackingService.activeBuses.isNotEmpty)
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.primaryDark,
                    onPressed: _focusOnNearestBus,
                    tooltip: 'Focus on Nearest Bus',
                    child: const Icon(Icons.directions_bus, size: 24),
                  ),
                const SizedBox(height: 8),

                // Start/End Stops button
                if (trackingService.selectedRouteId != null)
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.primaryDark,
                    onPressed: _focusOnStartEndStops,
                    tooltip: 'Show Start/End Stops',
                    child: const Icon(Icons.compare_arrows, size: 24),
                  ),
                const SizedBox(height: 8),

                // All Stops button
                if (trackingService.selectedRouteId != null)
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.primaryDark,
                    onPressed: () {
                      if (_mapController != null &&
                          trackingService.selectedRouteDetails != null) {
                        final mainStops =
                            trackingService
                                .selectedRouteDetails!['main_stops'] ??
                            [];
                        final List<LatLng> mainStopLatLngs =
                            mainStops
                                .where((stop) => stop['location'] is GeoPoint)
                                .map(
                                  (stop) => LatLng(
                                    stop['location'].latitude,
                                    stop['location'].longitude,
                                  ),
                                )
                                .toList();
                        if (mainStopLatLngs.isNotEmpty) {
                          _animateToBounds(mainStopLatLngs);
                        }
                      }
                    },
                    tooltip: 'Show All Stops',
                    child: const Icon(Icons.location_on, size: 24),
                  ),
                const SizedBox(height: 8),

                // Legend toggle button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: _showLegend ? Colors.blue : AppColors.white,
                  foregroundColor: _showLegend ? AppColors.white : Colors.blue,
                  onPressed: () {
                    setState(() {
                      _showLegend = !_showLegend;
                    });
                  },
                  tooltip: 'Toggle Legend',
                  child: const Icon(Icons.info_outline, size: 24),
                ),
                const SizedBox(height: 8),

                // Fullscreen toggle button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryDark,
                  onPressed: _toggleFullScreenMap,
                  tooltip: 'Exit Fullscreen',
                  child: const Icon(Icons.fullscreen_exit, size: 24),
                ),
              ],
            ),
          ),

        // Bus cards positioned at bottom
        if (trackingService.selectedRouteId != null &&
            trackingService.activeBuses.isNotEmpty &&
            trackingService.isBalanceSufficient)
          Positioned(
            bottom: 0,
            left: 16,
            right: 80,
            child: SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: trackingService.activeBuses.length,
                itemBuilder: (context, index) {
                  final bus = trackingService.activeBuses[index];
                  final busId = bus['id'];

                  // Get ETA info if available
                  String etaText = '';
                  if (trackingService.etaInfo.containsKey(busId)) {
                    final etaMinutes =
                        trackingService.etaInfo[busId]['minutes'];
                    final etaTime =
                        trackingService.etaInfo[busId]['arrivalTime']
                            as DateTime;
                    final formattedTime =
                        '${etaTime.hour.toString().padLeft(2, '0')}:${etaTime.minute.toString().padLeft(2, '0')}';
                    etaText = ' • ETA: $etaMinutes min ($formattedTime)';
                  }

                  return Card(
                    margin: const EdgeInsets.only(right: 8,bottom: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    color: AppColors.white,
                    child: Container(
                      width: 170, // Wider to accommodate ETA info
                      padding: const EdgeInsets.only(
                        top: 10,
                        left: 12,
                        right: 12,
                        bottom: 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.shadowGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions_bus,
                                  color: Colors.green,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                bus['busNumber'].toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.speed,
                                size: 14,
                                color: AppColors.grey600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${bus['speed'].toStringAsFixed(1)} km/h',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.grey600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (etaText.isNotEmpty)
                            Text(
                              etaText,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),
                          ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        // Legend positioned at top right
        if (_showLegend && trackingService.isBalanceSufficient)
          Positioned(
            top: 80 + MediaQuery.of(context).padding.top + 70,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Legend',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      color: const Color.fromARGB(255, 8, 11, 195),
                      icon: Icons.directions_bus,
                      label: 'Active buses',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      color: const Color.fromARGB(255, 150, 0, 40),
                      icon: Icons.share_location_rounded,
                      label: 'Main stops',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      color: AppColors.primaryDark,
                      icon: Icons.location_pin,
                      label: 'Sub-stops',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      color:  Colors.green,
                      icon: Icons.radio_button_checked,
                      label: 'Your location',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      color: Colors.blue,
                      icon: Icons.timeline,
                      label: 'Route path',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Legend item widget
  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.grey600),
        ),
      ],
    );
  }

  // Route selector widget (duplicate, renamed to avoid conflict)
  Widget _buildRouteSelectorCard(
    TrackingService trackingService, {
    bool compact = false,
  }) {
    return Card(
      elevation: compact ? 10 : 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!compact)
              Row(
                children: [
                  Icon(Icons.route, color: AppColors.primaryDark, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Select Bus Route',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            if (!compact) const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: trackingService.selectedRouteId,
              hint: Text(
                compact ? 'Select Route' : 'Choose a route',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.grey600,
                ),
              ),
              items:
                  trackingService.busRoutes.map((route) {
                    return DropdownMenuItem<String>(
                      value: route['id'],
                      child: Text(
                        route['name'],
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.primaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                trackingService.selectRoute(newValue);
                if (newValue != null &&
                    _locationPermissionGranted &&
                    trackingService.isBalanceSufficient) {
                  trackingService.fetchStopsAndBuses().then((_) {
                    if (trackingService.mainStopLatLngs.isNotEmpty) {
                      List<LatLng> points = List.from(
                        trackingService.mainStopLatLngs,
                      );
                      if (trackingService.userLocation != null) {
                        points.add(trackingService.userLocation!);
                      }
                      _animateToBounds(points);
                    }
                  });
                } else if (!_locationPermissionGranted) {
                  _requestLocationPermission();
                }
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.shadowGreen.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.accentGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Normal view with scrollable content
  Widget _buildNormalView(TrackingService trackingService) {
  return RefreshIndicator(
    onRefresh: _onRefresh,
    color: AppColors.accentGreen,
    backgroundColor: Colors.white,
    child: Stack(
      children: [
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRouteSelectorCard(trackingService),
              const SizedBox(height: 20),
              if (trackingService.selectedRouteId != null) ...[
                _buildRouteInfoCard(trackingService),
                const SizedBox(height: 16),
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    height: 400,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: trackingService.isBalanceSufficient
                          ? _buildMap(trackingService)
                          : _buildInsufficientBalanceMapOverlay(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (trackingService.isBalanceSufficient)
                  _buildActiveBusesList(trackingService)
                else
                  _buildInsufficientBalanceCard(trackingService),
                const SizedBox(height: 16),
                if (trackingService.selectedRouteDetails != null && trackingService.isBalanceSufficient)
                  _buildStopsList(trackingService),
              ],
              const SizedBox(height: 80), // Extra padding to avoid overlap with buttons
            ],
          ),
        ),
        // Map control buttons
        if (trackingService.selectedRouteId != null && trackingService.isBalanceSufficient)
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                // My Location button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryDark,
                  onPressed: () {
                    if (_mapController != null && trackingService.userLocation != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: trackingService.userLocation!,
                            zoom: 16,
                          ),
                        ),
                      );
                    }
                  },
                  tooltip: 'Focus on Your Location',
                  child: const Icon(Icons.my_location, size: 24),
                ),
                const SizedBox(height: 8),
                // Nearest Bus button
                if (trackingService.activeBuses.isNotEmpty)
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.primaryDark,
                    onPressed: _focusOnNearestBus,
                    tooltip: 'Focus on Nearest Bus',
                    child: const Icon(Icons.directions_bus, size: 24),
                  ),
                const SizedBox(height: 8),
                // Start/End Stops button
                if (trackingService.selectedRouteId != null)
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.primaryDark,
                    onPressed: _focusOnStartEndStops,
                    tooltip: 'Show Start/End Stops',
                    child: const Icon(Icons.compare_arrows, size: 24),
                  ),
                
                const SizedBox(height: 8),
                // Legend toggle button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: _showLegend ? Colors.blue : AppColors.white,
                  foregroundColor: _showLegend ? AppColors.white : Colors.blue,
                  onPressed: () {
                    setState(() {
                      _showLegend = !_showLegend;
                    });
                  },
                  tooltip: 'Toggle Legend',
                  child: const Icon(Icons.info_outline, size: 24),
                ),
                const SizedBox(height: 8),
                // Fullscreen toggle button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryDark,
                  onPressed: _toggleFullScreenMap,
                  tooltip: 'Enter Fullscreen',
                  child: const Icon(Icons.fullscreen, size: 24),
                ),
              ],
            ),
          ),
        // Legend for normal view
        if (_showLegend && trackingService.isBalanceSufficient)
          Positioned(
            top: 16 + MediaQuery.of(context).padding.top,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Legend',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      color: const Color.fromARGB(255, 8, 11, 195),
                      icon: Icons.directions_bus,
                      label: 'Active buses',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      color: const Color.fromARGB(255, 150, 0, 40),
                      icon: Icons.share_location_rounded,
                      label: 'Main stops',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      color: const Color.fromARGB(255, 91, 128, 156),
                      icon: Icons.location_pin,
                      label: 'Sub-stops',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      color: Colors.green,
                      icon: Icons.radio_button_checked,
                      label: 'Your location',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      color: Colors.blue,
                      icon: Icons.timeline,
                      label: 'Route path',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
  // Insufficient balance overlay for map
  Widget _buildInsufficientBalanceMapOverlay() {
    return Stack(
      children: [
        Container(color: Colors.white.withOpacity(0.8)),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 60,
                color: AppColors.errorRed,
              ),
              const SizedBox(height: 16),
              Text(
                'Insufficient Balance',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Your wallet balance is insufficient for this route.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.grey600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
                ],
          ),
        ),
      ],
    );
  }

  // Insufficient balance card
  Widget _buildInsufficientBalanceCard(TrackingService trackingService) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.errorRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insufficient Balance',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please top up your wallet to view bus information',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Balance',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.grey600,
                        ),
                      ),
                      Text(
                        'Rs. ${trackingService.walletBalance.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Required Amount',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.grey600,
                        ),
                      ),
                      Text(
                        'Rs. ${trackingService.routeCost.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),            
          ],
        ),
      ),
    );
  }

  // Route info card
  Widget _buildRouteInfoCard(TrackingService trackingService) {
    if (trackingService.selectedRouteDetails == null) return const SizedBox();

    final selectedRoute = trackingService.busRoutes.firstWhere(
      (route) => route['id'] == trackingService.selectedRouteId,
      orElse: () => {'name': 'Unknown Route', 'startStop': '', 'endStop': ''},
    );

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.route,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedRoute['name'] ?? 'Unknown Route',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trackingService.activeBuses.isNotEmpty &&
                    trackingService.isBalanceSufficient)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.shadowGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_bus,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trackingService.activeBuses.length}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.grey600,
                      ),
                    ),
                    Text(
                      '${(selectedRoute['distance'] ?? 0.0).toStringAsFixed(1)} km',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cost per km',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.grey600,
                      ),
                    ),
                    Text(
                      'Rs. ${(selectedRoute['costPerKm'] ?? 25.0).toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full Journey Cost',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.grey600,
                      ),
                    ),
                    Text(
                      'Rs. ${trackingService.routeCost.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            trackingService.isBalanceSufficient
                                ? AppColors.accentGreen
                                : AppColors.errorRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (trackingService.isLoadingRoute)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading route information...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.grey600,
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

  // Route selector widget
  Widget _buildRouteSelector(
    TrackingService trackingService, {
    bool compact = false,
  }) {
    return Card(
      elevation: compact ? 10 : 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!compact)
              Row(
                children: [
                  Icon(Icons.route, color: AppColors.primaryDark, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Select Bus Route',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            if (!compact) const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: trackingService.selectedRouteId,
              hint: Text(
                compact ? 'Select Route' : 'Choose a route',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.grey600,
                ),
              ),
              items:
                  trackingService.busRoutes.map((route) {
                    return DropdownMenuItem<String>(
                      value: route['id'],
                      child: Text(
                        route['name'],
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.primaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                trackingService.selectRoute(newValue);
                if (newValue != null &&
                    _locationPermissionGranted &&
                    trackingService.isBalanceSufficient) {
                  trackingService.fetchStopsAndBuses();
                } else if (!_locationPermissionGranted) {
                  _requestLocationPermission();
                }
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.shadowGreen.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.accentGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Map widget
  Widget _buildMap(TrackingService trackingService) {
    return _locationPermissionGranted
        ? GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(
              7.2906,
              80.6337,
            ), // Default starting point (e.g., Kandy, Sri Lanka)
            zoom: 10,
          ),
          onMapCreated: (GoogleMapController controller) async {
            _mapController = controller;
            if (trackingService.selectedRouteId != null &&
                trackingService.isBalanceSufficient) {
              await trackingService.fetchStopsAndBuses();
              // Auto-focus map on route and user location after data is loaded
              if (trackingService.mainStopLatLngs.isNotEmpty) {
                List<LatLng> points = List.from(
                  trackingService.mainStopLatLngs,
                );
                if (trackingService.userLocation != null) {
                  points.add(trackingService.userLocation!);
                }
                _animateToBounds(points);
              }
            }
          },
          markers: trackingService.markers,
          polylines: trackingService.polylines,
          mapToolbarEnabled: true,
          myLocationEnabled: false, // Enable built-in my location layer
          myLocationButtonEnabled: true, // Enable built-in my location button
          zoomControlsEnabled: false,
          compassEnabled: true,
        )
        : _buildPermissionRequest();
  }

  // Permission request widget
  Widget _buildPermissionRequest() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.location_off, size: 50, color: AppColors.errorRed),
        const SizedBox(height: 10),
        Text(
          'Location Permission Required',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.grey600,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _requestLocationPermission,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'Request Permission',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }

  // Map bounds animation helper
  void _animateToBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double southWestLat = points.first.latitude;
    double southWestLng = points.first.longitude;
    double northEastLat = points.first.latitude;
    double northEastLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < southWestLat) southWestLat = point.latitude;
      if (point.longitude < southWestLng) southWestLng = point.longitude;
      if (point.latitude > northEastLat) northEastLat = point.latitude;
      if (point.longitude > northEastLng) northEastLng = point.longitude;
    }

    final padding = 0.05;
    southWestLat -= padding;
    southWestLng -= padding;
    northEastLat += padding;
    northEastLng += padding;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(southWestLat, southWestLng),
          northeast: LatLng(northEastLat, northEastLng),
        ),
        50.0,
      ),
    );
  }

  // Active buses list widget
  Widget _buildActiveBusesList(TrackingService trackingService) {
    if (trackingService.activeBuses.isEmpty) {
      return Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Buses',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      size: 40,
                      color: AppColors.grey600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active buses found for this route',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppColors.grey600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pull down to refresh or try another route',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.grey600,
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

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Buses',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${trackingService.activeBuses.length} BUSES',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.shadowGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trackingService.activeBuses.length,
                itemBuilder: (context, index) {
                  final bus = trackingService.activeBuses[index];
                  final busId = bus['id'];

                  // Get ETA info if available
                  String etaText = '';
                  if (trackingService.etaInfo.containsKey(busId)) {
                    final etaMinutes =
                        trackingService.etaInfo[busId]['minutes'];
                    final etaTime =
                        trackingService.etaInfo[busId]['arrivalTime']
                            as DateTime;
                    final formattedTime =
                        '${etaTime.hour.toString().padLeft(2, '0')}:${etaTime.minute.toString().padLeft(2, '0')}';
                    etaText = '$etaMinutes min ($formattedTime)';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.directions_bus,
                              color: AppColors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bus['busNumber'].toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.speed,
                                    size: 14,
                                    color: AppColors.grey600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${bus['speed'].toStringAsFixed(1)} km/h',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.grey600,
                                    ),
                                  ),
                                ],
                              ),
                              if (etaText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.deepOrange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ETA: $etaText',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final location = bus['location'];
                            if (location != null && _mapController != null) {
                              _mapController!.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(location.latitude, location.longitude),
                                  17.0,
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            Icons.visibility,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                          tooltip: 'Focus on bus',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stops list widget
  Widget _buildStopsList(TrackingService trackingService) {
    final mainStops = trackingService.selectedRouteDetails?['main_stops'] ?? [];
    final subStops = trackingService.selectedRouteDetails?['sub_stops'] ?? [];

    if (mainStops.isEmpty && subStops.isEmpty) return const SizedBox();

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route Stops',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            if (mainStops.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 150, 0, 40),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Main Stops',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.shadowGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mainStops.length > 3 ? 3 : mainStops.length,
                  itemBuilder: (context, index) {
                    final stop = mainStops[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(
                                255,
                                150,
                                0,
                                40,
                              ).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color.fromARGB(255, 150, 0, 40),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stop['name'] ?? 'Main Stop ${index + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final location = stop['location'];
                              if (location != null && _mapController != null) {
                                _mapController!.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                    16.0,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.share_location_rounded,
                              color: Color.fromARGB(255, 150, 0, 40),
                              size: 18,
                            ),
                            tooltip: 'Show on map',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (mainStops.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) =>
                                  _buildAllStopsDialog(trackingService),
                        );
                      },
                      child: Text(
                        'View All ${mainStops.length} Stops',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (subStops.isNotEmpty)
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 91, 128, 156),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sub Stops (${subStops.length})',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => _buildAllStopsDialog(
                              trackingService,
                              showSubStops: true,
                            ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // All stops dialog widget
  Widget _buildAllStopsDialog(
    TrackingService trackingService, {
    bool showSubStops = false,
  }) {
    final mainStops = trackingService.selectedRouteDetails?['main_stops'] ?? [];
    final subStops = trackingService.selectedRouteDetails?['sub_stops'] ?? [];

    final stopsToShow = showSubStops ? subStops : mainStops;
    final color =
        showSubStops
            ? const Color.fromARGB(255, 91, 128, 156)
            : const Color.fromARGB(255, 150, 0, 40);
    final title = showSubStops ? 'Sub Stops' : 'Main Stops';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryDark,
        ),
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 400),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: stopsToShow.length,
          itemBuilder: (context, index) {
            final stop = stopsToShow[index];
            return ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              title: Text(
                stop['name'] ?? 'Stop ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryDark,
                ),
              ),
              trailing: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  final location = stop['location'];
                  if (location != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(location.latitude, location.longitude),
                        16.0,
                      ),
                    );
                  }
                },
                icon: Icon(
                  showSubStops
                      ? Icons.location_pin
                      : Icons.share_location_rounded,
                  color: color,
                ),
                tooltip: 'Show on map',
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
