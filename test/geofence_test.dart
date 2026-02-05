import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/geofence_config.dart';

void main() {
  group('GeofenceConfig Tests', () {
    test('Default configuration values are correct', () {
      final config = GeofenceConfig.defaultConfig();
      
      expect(config.centerLatitude, 12.0475);
      expect(config.centerLongitude, 75.1986);
      expect(config.radiusMeters, 100);
      expect(config.locationTimeoutSeconds, 15);
      expect(config.maxAccuracyThreshold, 100.0);
    });

    test('Custom configuration values are set correctly', () {
      final config = GeofenceConfig(
        centerLatitude: 40.7128,
        centerLongitude: -74.0060,
        radiusMeters: 200,
        locationTimeoutSeconds: 30,
        maxAccuracyThreshold: 50.0,
        requireHighAccuracy: false,
        enableBatteryOptimization: true,
        locationCacheDurationMinutes: 10,
      );
      
      expect(config.centerLatitude, 40.7128);
      expect(config.centerLongitude, -74.0060);
      expect(config.radiusMeters, 200);
      expect(config.locationTimeoutSeconds, 30);
      expect(config.maxAccuracyThreshold, 50.0);
      expect(config.requireHighAccuracy, false);
      expect(config.enableBatteryOptimization, true);
      expect(config.locationCacheDurationMinutes, 10);
    });
  });

  group('GeofencePoint Tests', () {
    test('Distance calculation is correct', () {
      // New York City coordinates
      final point1 = GeofencePoint(latitude: 40.7128, longitude: -74.0060);
      // Los Angeles coordinates (approximately 3935 km)
      final point2 = GeofencePoint(latitude: 34.0522, longitude: -118.2437);
      
      final distance = point1.distanceTo(point2);
      
      // Distance should be approximately 3935 km (3,935,000 meters)
      expect(distance, greaterThan(3900000));
      expect(distance, lessThan(4000000));
    });

    test('Distance to same point is zero', () {
      final point = GeofencePoint(latitude: 40.7128, longitude: -74.0060);
      final samePoint = GeofencePoint(latitude: 40.7128, longitude: -74.0060);
      
      expect(point.distanceTo(samePoint), equals(0.0));
    });

    test('JSON serialization works', () {
      final point = GeofencePoint(latitude: 12.0475, longitude: 75.1986);
      final json = point.toJson();
      
      expect(json['latitude'], 12.0475);
      expect(json['longitude'], 75.1986);
    });

    test('JSON deserialization works', () {
      final json = {'latitude': 12.0475, 'longitude': 75.1986};
      final point = GeofencePoint.fromJson(json);
      
      expect(point.latitude, 12.0475);
      expect(point.longitude, 75.1986);
    });
  });

  group('PolygonGeofence Tests', () {
    test('Point inside polygon returns true', () {
      // Simple square polygon around (0,0)
      final polygon = PolygonGeofence(
        vertices: [
          GeofencePoint(latitude: -1, longitude: -1),
          GeofencePoint(latitude: 1, longitude: -1),
          GeofencePoint(latitude: 1, longitude: 1),
          GeofencePoint(latitude: -1, longitude: 1),
        ],
      );
      
      final point = GeofencePoint(latitude: 0, longitude: 0);
      
      expect(polygon.containsPoint(point), isTrue);
    });

    test('Point outside polygon returns false', () {
      final polygon = PolygonGeofence(
        vertices: [
          GeofencePoint(latitude: -1, longitude: -1),
          GeofencePoint(latitude: 1, longitude: -1),
          GeofencePoint(latitude: 1, longitude: 1),
          GeofencePoint(latitude: -1, longitude: 1),
        ],
      );
      
      final point = GeofencePoint(latitude: 2, longitude: 2);
      
      expect(polygon.containsPoint(point), isFalse);
    });

    test('Empty polygon contains no points', () {
      final polygon = PolygonGeofence(vertices: []);
      final point = GeofencePoint(latitude: 0, longitude: 0);
      
      expect(polygon.containsPoint(point), isFalse);
    });

    test('Centroid calculation is correct', () {
      final polygon = PolygonGeofence(
        vertices: [
          GeofencePoint(latitude: 0, longitude: 0),
          GeofencePoint(latitude: 2, longitude: 0),
          GeofencePoint(latitude: 2, longitude: 2),
          GeofencePoint(latitude: 0, longitude: 2),
        ],
      );
      
      final centroid = polygon.centroid;
      
      expect(centroid.latitude, equals(1.0));
      expect(centroid.longitude, equals(1.0));
    });

    test('Bounding box contains all vertices', () {
      final polygon = PolygonGeofence(
        vertices: [
          GeofencePoint(latitude: 0, longitude: 0),
          GeofencePoint(latitude: 2, longitude: 0),
          GeofencePoint(latitude: 2, longitude: 2),
          GeofencePoint(latitude: 0, longitude: 2),
        ],
      );
      
      final bbox = polygon.boundingBox;
      
      expect(bbox.minLatitude, equals(0.0));
      expect(bbox.maxLatitude, equals(2.0));
      expect(bbox.minLongitude, equals(0.0));
      expect(bbox.maxLongitude, equals(2.0));
    });
  });

  group('BoundingBox Tests', () {
    test('Point inside bounding box returns true', () {
      final bbox = BoundingBox(
        minLatitude: 0,
        maxLatitude: 10,
        minLongitude: 0,
        maxLongitude: 10,
      );
      
      final point = GeofencePoint(latitude: 5, longitude: 5);
      
      expect(bbox.containsPoint(point), isTrue);
    });

    test('Point outside bounding box returns false', () {
      final bbox = BoundingBox(
        minLatitude: 0,
        maxLatitude: 10,
        minLongitude: 0,
        maxLongitude: 10,
      );
      
      final point = GeofencePoint(latitude: 15, longitude: 15);
      
      expect(bbox.containsPoint(point), isFalse);
    });

    test('Point on boundary is considered inside', () {
      final bbox = BoundingBox(
        minLatitude: 0,
        maxLatitude: 10,
        minLongitude: 0,
        maxLongitude: 10,
      );
      
      final point1 = GeofencePoint(latitude: 0, longitude: 5);
      final point2 = GeofencePoint(latitude: 5, longitude: 0);
      final point3 = GeofencePoint(latitude: 10, longitude: 5);
      final point4 = GeofencePoint(latitude: 5, longitude: 10);
      
      expect(bbox.containsPoint(point1), isTrue);
      expect(bbox.containsPoint(point2), isTrue);
      expect(bbox.containsPoint(point3), isTrue);
      expect(bbox.containsPoint(point4), isTrue);
    });
  });
}
