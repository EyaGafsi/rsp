import 'dart:async';
import 'package:tsyproject/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyHome extends StatelessWidget {
  const MyHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 245, 198, 235),
        title: const Text("Home"),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signout(context: context);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const GoogleMapFlutter(),
    );
  }
}

class GoogleMapFlutter extends StatefulWidget {
  const GoogleMapFlutter({super.key});

  @override
  State<GoogleMapFlutter> createState() => _GoogleMapFlutterState();
}

class _GoogleMapFlutterState extends State<GoogleMapFlutter> {
  late GoogleMapController _mapController;
  LatLng myCurrentLocation =
      const LatLng(36.89835701003654, 10.192763449710098);
  BitmapDescriptor? _customMarkerIcon;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _routeOrder = [];
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
    _getCurrentLocation();
    _fetchMarkersFromFirebase();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshPage();
    });
  }

  Future<void> _refreshPage() async {
    await _getCurrentLocation();
    await _fetchMarkersFromFirebase();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadCustomMarkerIcon() async {
    _customMarkerIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(13, 13)),
      'assets/truck.png',
    );
  }

  Future<void> _fetchMarkersFromFirebase() async {
    final trashCollection = FirebaseFirestore.instance.collection('trash');

    try {
      final querySnapshot = await trashCollection.get();
      final fetchedMarkers = <Marker>{};
      final validMarkerPositions = <LatLng>[];

      setState(() {
        _polylines.clear();
      });

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('position')) {
          final position = data['position'];
          final latitude = position.latitude;
          final longitude = position.longitude;
          final niveau = data['niveau'] ?? 0;

          fetchedMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(latitude, longitude),
              infoWindow: InfoWindow(
                title: 'Niveau: $niveau',
              ),
              icon: await _getMarkerIcon(niveau),
            ),
          );

          if (niveau > 40) {
            validMarkerPositions.add(LatLng(latitude, longitude));
          }
        }
      }

      setState(() {
        _markers.addAll(fetchedMarkers);
        _routeOrder = validMarkerPositions;
      });

      _fetchRoutesToMarkers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching markers: $e")),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enable location services.")),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied.")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Location permissions are permanently denied.")),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      myCurrentLocation = LatLng(position.latitude, position.longitude);

      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: myCurrentLocation, zoom: 15),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: myCurrentLocation,
          icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(
            title: 'You are here!',
          ),
        ),
      );
    });
  }

  Future<void> _fetchRoutesToMarkers() async {
    for (LatLng markerPosition in _routeOrder) {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${myCurrentLocation.longitude},${myCurrentLocation.latitude};'
        '${markerPosition.longitude},${markerPosition.latitude}'
        '?overview=full&geometries=polyline',
      );

      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            final encodedPolyline = data['routes'][0]['geometry'];
            final polylinePoints = _decodePolyline(encodedPolyline);

            setState(() {
              _polylines.add(Polyline(
                polylineId: PolylineId(markerPosition.toString()),
                points: polylinePoints,
                color: Colors.blue,
                width: 4,
              ));
            });
            myCurrentLocation = markerPosition;
          }
        }
      } catch (e) {
        print("Error fetching route: $e");
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<BitmapDescriptor> _getMarkerIcon(int niveau) async {
    if (niveau < 40) {
      return await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(24, 24)),
        'assets/green_can.png',
      );
    } else if (niveau > 60) {
      return await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(),
        'assets/red_can.png',
      );
    } else {
      return await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(),
        'assets/orange_can.png',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
      },
      initialCameraPosition:
          CameraPosition(target: myCurrentLocation, zoom: 15),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
    );
  }
}
