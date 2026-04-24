import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  Timer? _locationTimer;
  Position? _currentPosition;

  // Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        print('Location permission denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = position;
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Start tracking location (updates every 30 seconds)
  void startTracking(Function(double lat, double lng) onLocationUpdate) {
    _locationTimer?.cancel();

    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        final position = await getCurrentLocation();
        if (position != null) {
          onLocationUpdate(position.latitude, position.longitude);
        }
      },
    );

    // Also get location immediately
    getCurrentLocation().then((position) {
      if (position != null) {
        onLocationUpdate(position.latitude, position.longitude);
      }
    });
  }

  // Stop tracking
  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // Get last known position
  Position? get lastPosition => _currentPosition;

  // Dispose
  void dispose() {
    stopTracking();
  }
}