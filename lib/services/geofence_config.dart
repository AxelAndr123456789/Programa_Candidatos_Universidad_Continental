import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration model for geofence settings
class GeofenceConfig {
  final double centerLatitude;
  final double centerLongitude;
  final double radiusMeters;
  final int locationTimeoutSeconds;
  final double maxAccuracyThreshold;
  final bool requireHighAccuracy;
  final bool enableBatteryOptimization;
  final int locationCacheDurationMinutes;

  const GeofenceConfig({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    this.locationTimeoutSeconds = 15,
    this.maxAccuracyThreshold = 100.0,
    this.requireHighAccuracy = true,
    this.enableBatteryOptimization = false,
    this.locationCacheDurationMinutes = 5,
  });

  /// Universidad Continental campus principal - Huancayo, Perú
  /// Coordenadas: -12.0475 latitud, -75.198611 longitud (12°02′51″S 75°11′55″O)
  /// Radio de verificación: 750 metros
  static const double kCampusLatitude = -12.0475;
  static const double kCampusLongitude = -75.198611;
  static const double kDefaultRadiusMeters = 750.0; // 750 metros desde el punto central

  /// Factory constructor for default configuration with Universidad Continental coordinates
  factory GeofenceConfig.defaultConfig() {
    return GeofenceConfig(
      centerLatitude: kCampusLatitude,
      centerLongitude: kCampusLongitude,
      radiusMeters: kDefaultRadiusMeters,
    );
  }

  /// Load configuration from environment variables or SharedPreferences
  static Future<GeofenceConfig> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    return GeofenceConfig(
      // Usar coordenadas de la Universidad Continental por defecto
      centerLatitude: prefs.getDouble('geofence_latitude') ?? kCampusLatitude,
      centerLongitude: prefs.getDouble('geofence_longitude') ?? kCampusLongitude,
      radiusMeters: prefs.getDouble('geofence_radius') ?? kDefaultRadiusMeters,
      locationTimeoutSeconds: prefs.getInt('geofence_timeout') ?? 15,
      maxAccuracyThreshold: prefs.getDouble('geofence_accuracy_threshold') ?? 100.0,
      requireHighAccuracy: prefs.getBool('geofence_require_high_accuracy') ?? true,
      enableBatteryOptimization: prefs.getBool('geofence_battery_optimization') ?? false,
      locationCacheDurationMinutes: prefs.getInt('geofence_cache_duration') ?? 5,
    );
  }

  /// Save configuration to SharedPreferences
  Future<void> saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('geofence_latitude', centerLatitude);
    await prefs.setDouble('geofence_longitude', centerLongitude);
    await prefs.setDouble('geofence_radius', radiusMeters);
    await prefs.setInt('geofence_timeout', locationTimeoutSeconds);
    await prefs.setDouble('geofence_accuracy_threshold', maxAccuracyThreshold);
    await prefs.setBool('geofence_require_high_accuracy', requireHighAccuracy);
    await prefs.setBool('geofence_battery_optimization', enableBatteryOptimization);
    await prefs.setInt('geofence_cache_duration', locationCacheDurationMinutes);
  }
}

/// Polygon geofence definition for complex campus boundaries
class PolygonGeofence {
  final List<GeofencePoint> vertices;
  final String name;

  PolygonGeofence({required this.vertices, this.name = 'Campus'});

  /// Check if a point is inside the polygon using ray casting algorithm
  bool containsPoint(GeofencePoint point) {
    if (vertices.isEmpty) return false;

    bool inside = false;
    int j = vertices.length - 1;

    for (int i = 0; i < vertices.length; i++) {
      final xi = vertices[i].longitude;
      final yi = vertices[i].latitude;
      final xj = vertices[j].longitude;
      final yj = vertices[j].latitude;

      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Get the centroid of the polygon for distance calculations
  GeofencePoint get centroid {
    if (vertices.isEmpty) {
      return GeofencePoint(latitude: 0, longitude: 0);
    }

    double latSum = 0;
    double lngSum = 0;

    for (final vertex in vertices) {
      latSum += vertex.latitude;
      lngSum += vertex.longitude;
    }

    return GeofencePoint(
      latitude: latSum / vertices.length,
      longitude: lngSum / vertices.length,
    );
  }

  /// Get bounding box of the polygon
  BoundingBox get boundingBox {
    if (vertices.isEmpty) {
      return BoundingBox(
        minLatitude: 0,
        maxLatitude: 0,
        minLongitude: 0,
        maxLongitude: 0,
      );
    }

    double minLat = vertices[0].latitude;
    double maxLat = vertices[0].latitude;
    double minLng = vertices[0].longitude;
    double maxLng = vertices[0].longitude;

    for (final vertex in vertices) {
      if (vertex.latitude < minLat) minLat = vertex.latitude;
      if (vertex.latitude > maxLat) maxLat = vertex.latitude;
      if (vertex.longitude < minLng) minLng = vertex.longitude;
      if (vertex.longitude > maxLng) maxLng = vertex.longitude;
    }

    return BoundingBox(
      minLatitude: minLat,
      maxLatitude: maxLat,
      minLongitude: minLng,
      maxLongitude: maxLng,
    );
  }
}

/// A single point in a geofence
class GeofencePoint {
  final double latitude;
  final double longitude;

  GeofencePoint({required this.latitude, required this.longitude});

  /// Calculate distance to another point using Haversine formula
  double distanceTo(GeofencePoint other) {
    const earthRadius = 6371000; // meters

    final dLat = _toRadians(other.latitude - latitude);
    final dLng = _toRadians(other.longitude - longitude);

    final a = _haversine(dLat) +
        _toRadians(latitude) *
            _toRadians(other.latitude) *
            _haversine(dLng);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  double _haversine(double radians) => pow(sin(radians / 2), 2).toDouble();

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory GeofencePoint.fromJson(Map<String, dynamic> json) {
    return GeofencePoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }
}

/// Bounding box for quick pre-filtering of geofence checks
class BoundingBox {
  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  BoundingBox({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  /// Quick check if a point is within the bounding box
  bool containsPoint(GeofencePoint point) {
    return point.latitude >= minLatitude &&
        point.latitude <= maxLatitude &&
        point.longitude >= minLongitude &&
        point.longitude <= maxLongitude;
  }
}
