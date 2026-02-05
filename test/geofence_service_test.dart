import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/geofence_service.dart';

void main() {
  group('Haversine Distance Calculation Tests', () {
    test('Distance between same point is zero', () {
      final distance = GeofenceService.calculateHaversineDistance(
        40.7128,
        -74.0060,
        40.7128,
        -74.0060,
      );
      
      expect(distance, equals(0.0));
    });

    test('Distance between NYC and LA is approximately 3935 km', () {
      // New York City
      final nycLat = 40.7128;
      final nycLng = -74.0060;
      
      // Los Angeles
      final laLat = 34.0522;
      final laLng = -118.2437;
      
      final distance = GeofenceService.calculateHaversineDistance(
        nycLat, nycLng,
        laLat, laLng,
      );
      
      // Expected: approximately 3,935,000 meters
      expect(distance, greaterThan(3900000));
      expect(distance, lessThan(4000000));
    });

    test('Distance between London and Paris is approximately 343 km', () {
      // London
      final londonLat = 51.5074;
      final londonLng = -0.1278;
      
      // Paris
      final parisLat = 48.8566;
      final parisLng = 2.3522;
      
      final distance = GeofenceService.calculateHaversineDistance(
        londonLat, londonLng,
        parisLat, parisLng,
      );
      
      // Expected: approximately 343,000 meters
      expect(distance, greaterThan(340000));
      expect(distance, lessThan(350000));
    });

    test('Distance calculation is symmetric', () {
      final point1Lat = 40.7128;
      final point1Lng = -74.0060;
      
      final point2Lat = 34.0522;
      final point2Lng = -118.2437;
      
      final distance1 = GeofenceService.calculateHaversineDistance(
        point1Lat, point1Lng,
        point2Lat, point2Lng,
      );
      
      final distance2 = GeofenceService.calculateHaversineDistance(
        point2Lat, point2Lng,
        point1Lat, point1Lng,
      );
      
      expect(distance1, equals(distance2));
    });

    test('Distance calculation handles negative coordinates', () {
      // Sydney, Australia
      final sydneyLat = -33.8688;
      final sydneyLng = 151.2093;
      
      // Cape Town, South Africa
      final capeTownLat = -33.9249;
      final capeTownLng = 18.4241;
      
      final distance = GeofenceService.calculateHaversineDistance(
        sydneyLat, sydneyLng,
        capeTownLat, capeTownLng,
      );
      
      // Should be a valid distance (not NaN or infinity)
      expect(distance.isFinite, isTrue);
      expect(distance, greaterThan(0));
    });

    test('Distance calculation handles equatorial points', () {
      // Quito, Ecuador (near equator)
      final quitoLat = -0.1807;
      final quitoLng = -78.4678;
      
      // Nairobi, Kenya (also near equator)
      final nairobiLat = -1.2921;
      final nairobiLng = 36.8219;
      
      final distance = GeofenceService.calculateHaversineDistance(
        quitoLat, quitoLng,
        nairobiLat, nairobiLng,
      );
      
      expect(distance.isFinite, isTrue);
      expect(distance, greaterThan(0));
    });

    test('Distance calculation handles polar regions', () {
      // North Pole
      final northPoleLat = 90.0;
      final northPoleLng = 0.0;
      
      // South Pole
      final southPoleLat = -90.0;
      final southPoleLng = 0.0;
      
      final distance = GeofenceService.calculateHaversineDistance(
        northPoleLat, northPoleLng,
        southPoleLat, southPoleLng,
      );
      
      // Should be approximately Earth's diameter (~20,000,000 meters)
      expect(distance, greaterThan(19000000));
      expect(distance, lessThan(21000000));
    });

    test('Geofence validation returns correct result for point inside', () {
      // Test point at the exact center of the default geofence
      final centerLat = 12.0475;
      final centerLng = 75.1986;
      const radius = 100.0; // meters
      
      final distance = GeofenceService.calculateHaversineDistance(
        centerLat, centerLng,
        centerLat, centerLng,
      );
      
      expect(distance <= radius, isTrue);
    });

    test('Geofence validation returns correct result for point far away', () {
      // Default geofence center
      final centerLat = 12.0475;
      final centerLng = 75.1986;
      const radius = 100.0; // meters
      
      // A point 1 km away
      final farPointLat = centerLat + 0.009; // approximately 1 km north
      final farPointLng = centerLng;
      
      final distance = GeofenceService.calculateHaversineDistance(
        centerLat, centerLng,
        farPointLat, farPointLng,
      );
      
      expect(distance > radius, isTrue);
    });
  });

  group('Error Message Tests', () {
    test('Error message for permission denied is correct', () {
      final exception = GeofenceException(
        'Permission denied',
        GeofenceErrorType.permissionDenied,
      );
      
      final message = GeofenceService.getErrorMessage(exception);
      
      expect(message, contains('permiso de ubicación'));
      expect(message, contains('configuración'));
    });

    test('Error message for location disabled is correct', () {
      final exception = GeofenceException(
        'GPS disabled',
        GeofenceErrorType.locationDisabled,
      );
      
      final message = GeofenceService.getErrorMessage(exception);
      
      expect(message, contains('GPS'));
      expect(message, contains('desactivado'));
    });

    test('Error message for outside geofence is correct', () {
      final exception = GeofenceException(
        'Outside geofence',
        GeofenceErrorType.outsideGeofence,
      );
      
      final message = GeofenceService.getErrorMessage(exception);
      
      expect(message, contains('campus'));
      expect(message, contains('votación'));
    });

    test('Error message for mock location detected is correct', () {
      final exception = GeofenceException(
        'Mock location detected',
        GeofenceErrorType.mockLocationDetected,
      );
      
      final message = GeofenceService.getErrorMessage(exception);
      
      expect(message, contains('simulada'));
      expect(message, contains('manipulada'));
    });
  });
}
