import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'geofence_config.dart';

/// Exception types for geofence-related errors
class GeofenceException implements Exception {
  final String message;
  final GeofenceErrorType type;

  GeofenceException(this.message, this.type);

  @override
  String toString() => message;
}

enum GeofenceErrorType {
  permissionDenied,
  permissionPermanentlyDenied,
  locationDisabled,
  locationUnavailable,
  timeout,
  outsideGeofence,
  mockLocationDetected,
  accuracyTooLow,
  locationCacheExpired,
  unknown
}

/// Result of a geofence check operation
class GeofenceResult {
  final bool isWithinGeofence;
  final double? distanceInMeters;
  final Position? currentPosition;
  final GeofenceException? error;
  final DateTime? timestamp;
  final bool isFromCache;

  GeofenceResult({
    required this.isWithinGeofence,
    this.distanceInMeters,
    this.currentPosition,
    this.error,
    this.timestamp,
    this.isFromCache = false,
  });

  bool get hasError => error != null;
  bool get isFresh => !isFromCache && timestamp != null && DateTime.now().difference(timestamp!) < Duration(minutes: 5);
}

/// Enhanced geofence service with offline support, anti-manipulation, and battery optimization
class GeofenceService {
  // Configuration loaded from environment or storage
  static late GeofenceConfig _config;
  
  // Polygon geofence for complex campus boundaries (optional)
  PolygonGeofence? _polygonGeofence;
  
  // Location cache for offline support
  static const String _locationCacheKey = 'cached_location';
  static const String _geofenceValidationKey = 'geofence_validation_time';
  static const String _geofenceStatusKey = 'geofence_last_status';
  
  // Anti-manipulation checks
  static const double _maxSpeedThreshold = 50.0; // m/s - unrealistic speed
  static const int _minAccuracyForMockCheck = 50; // meters

  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  
  // Stream subscription for continuous monitoring
  StreamSubscription<Position>? _positionStreamSubscription;
  
  // Cached validation state

  /// Initialize the geofence service with configuration
  static Future<void> initialize() async {
    _config = await GeofenceConfig.loadFromStorage();
  }

  /// Get current configuration
  static GeofenceConfig get config => _config;

  /// Set polygon geofence for complex boundaries
  void setPolygonGeofence(PolygonGeofence polygon) {
    _polygonGeofence = polygon;
  }

  /// Check if location permissions are granted
  Future<bool> hasLocationPermission() async {
    try {
      final permission = await _geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  /// Request location permissions from the user
  Future<LocationPermission> requestLocationPermission() async {
    try {
      return await _geolocator.requestPermission();
    } catch (e) {
      return LocationPermission.denied;
    }
  }

  /// Check if location services are enabled on the device
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await _geolocator.isLocationServiceEnabled();
    } catch (e) {
      return false;
    }
  }

  /// Detect mock location or GPS spoofing
  Future<GeofenceException?> _detectMockLocation(Position position) async {
    try {
      // Check if location is coming from mock provider
      if (position.isMocked) {
        return GeofenceException(
          'Se ha detectado una ubicación simulada. Por favor, desactive cualquier aplicación de suplantación de GPS.',
          GeofenceErrorType.mockLocationDetected,
        );
      }

      // Check for unrealistic speed (indicator of GPS spoofing
      if (position.speed > _maxSpeedThreshold && position.accuracy < _minAccuracyForMockCheck) {
        return GeofenceException(
          'Se ha detectado un movimiento irreal. La votación requiere ubicación física real.',
          GeofenceErrorType.mockLocationDetected,
        );
      }

      // Check accuracy against threshold
      if (position.accuracy > _config.maxAccuracyThreshold) {
        return GeofenceException(
          'La precisión de GPS es insuficiente (${position.accuracy.round()}m). Por favor, muévase a un área con mejor señal GPS.',
          GeofenceErrorType.accuracyTooLow,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the current device position with mock location detection
  Future<Position?> getCurrentPosition({
    bool enableHighAccuracy = true,
    int timeoutSeconds = 15,
    bool skipCache = false,
  }) async {
    try {
      // First check if location services are enabled
      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        throw GeofenceException(
          'Los servicios de ubicación están desactivados. Por favor, active el GPS.',
          GeofenceErrorType.locationDisabled,
        );
      }

      // Check and request permissions
      final hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        final permission = await requestLocationPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw GeofenceException(
            'Se requiere permiso de ubicación para verificar su posición dentro del campus.',
            permission == LocationPermission.deniedForever
                ? GeofenceErrorType.permissionPermanentlyDenied
                : GeofenceErrorType.permissionDenied,
          );
        }
      }

      // Check cache first if not skipping
      if (!skipCache) {
        final cachedResult = await _getCachedValidation();
        if (cachedResult != null && cachedResult.isFresh) {
          return cachedResult.currentPosition;
        }
      }

      // Get current position with timeout
      final position = await _geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: enableHighAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
          distanceFilter: 0,
          timeLimit: Duration(seconds: timeoutSeconds),
        ),
      );

      // Detect mock locations
      final mockError = await _detectMockLocation(position);
      if (mockError != null) {
        throw mockError;
      }

      // Cache the position
      await _cacheLocation(position);

      return position;
    } on GeofenceException {
      rethrow;
    } catch (e) {
      // Try to return cached position as fallback
      final cachedResult = await _getCachedValidation();
      if (cachedResult != null) {
        return cachedResult.currentPosition;
      }
      
      throw GeofenceException(
        'No se pudo obtener la ubicación: ${e.toString()}',
        GeofenceErrorType.locationUnavailable,
      );
    }
  }

  /// Cache location data for offline support
  Future<void> _cacheLocation(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache position
      await prefs.setString(_locationCacheKey, position.toJson().toString());
      
      // Cache validation time
      await prefs.setInt(_geofenceValidationKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Silent fail - caching is not critical
    }
  }

  /// Get cached validation result
  Future<GeofenceResult?> _getCachedValidation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cachedLocation = prefs.getString(_locationCacheKey);
      final validationTime = prefs.getInt(_geofenceValidationKey);
      final cachedStatus = prefs.getBool(_geofenceStatusKey);

      if (cachedLocation == null || validationTime == null || cachedStatus == null) {
        return null;
      }

      // Check if cache is expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - validationTime;
      final cacheDuration = Duration(minutes: _config.locationCacheDurationMinutes);

      if (cacheAge > cacheDuration.inMilliseconds) {
        return GeofenceResult(
          isWithinGeofence: false,
          error: GeofenceException(
            'La ubicación almacenada en caché ha expirado. Por favor, verifique su ubicación actual.',
            GeofenceErrorType.locationCacheExpired,
          ),
          isFromCache: true,
        );
      }

      // Parse cached position (simplified - in production, use proper JSON parsing)
      final cachedPosition = await getCurrentPosition(skipCache: true);

      return GeofenceResult(
        isWithinGeofence: cachedStatus,
        currentPosition: cachedPosition,
        timestamp: DateTime.fromMillisecondsSinceEpoch(validationTime),
        isFromCache: true,
      );
    } catch (e) {
      return null;
    }
  }

  /// Cache geofence validation status
  Future<void> _cacheValidationStatus(bool isWithinGeofence) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_geofenceStatusKey, isWithinGeofence);
    } catch (e) {
      // Silent fail
    }
  }

  /// Calculate distance using Haversine formula
  static double calculateHaversineDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadius = 6371000; // Earth's radius in meters

    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);

    final a = pow(sin(dLat / 2), 2).toDouble() +
        cos(_toRadians(startLat)) *
            cos(_toRadians(endLat)) *
            pow(sin(dLng / 2), 2).toDouble();

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Validate if the current position is within the geofence
  Future<GeofenceResult> validateGeofence({
    bool enableHighAccuracy = true,
    bool requireHighAccuracy = false,
    bool skipCache = false,
  }) async {
    try {
      final position = await getCurrentPosition(
        enableHighAccuracy: enableHighAccuracy,
        skipCache: skipCache,
      );

      if (position == null) {
        return GeofenceResult(
          isWithinGeofence: false,
          error: GeofenceException(
            'No se pudo obtener la ubicación del dispositivo.',
            GeofenceErrorType.locationUnavailable,
          ),
        );
      }

      // Check if accuracy is acceptable
      if (requireHighAccuracy && position.accuracy > _config.maxAccuracyThreshold) {
        return GeofenceResult(
          isWithinGeofence: false,
          currentPosition: position,
          error: GeofenceException(
            'La precisión de GPS es insuficiente. Por favor, muévase a un área con mejor señal.',
            GeofenceErrorType.accuracyTooLow,
          ),
        );
      }

      // Check using polygon geofence if defined
      if (_polygonGeofence != null) {
        final point = GeofencePoint(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        
        final isWithinPolygon = _polygonGeofence!.containsPoint(point);
        
        if (!isWithinPolygon) {
          return GeofenceResult(
            isWithinGeofence: false,
            currentPosition: position,
            timestamp: DateTime.now(),
            error: GeofenceException(
              'Su ubicación actual está fuera del campus universitario. '
              'Aún puede continuar con su voto. Esta información será registrada para efectos de auditoría.',
              GeofenceErrorType.outsideGeofence,
            ),
          );
        }
        
        await _cacheValidationStatus(true);
        return GeofenceResult(
          isWithinGeofence: true,
          currentPosition: position,
          timestamp: DateTime.now(),
        );
      }

      // Calculate distance using Haversine formula (circular geofence)
      final distance = calculateHaversineDistance(
        position.latitude,
        position.longitude,
        _config.centerLatitude,
        _config.centerLongitude,
      );

      final isWithinGeofence = distance <= _config.radiusMeters;

      // Cache the validation result
      await _cacheValidationStatus(isWithinGeofence);

      if (!isWithinGeofence) {
        return GeofenceResult(
          isWithinGeofence: false,
          distanceInMeters: distance,
          currentPosition: position,
          timestamp: DateTime.now(),
          error: GeofenceException(
            'Su ubicación actual está a ${distance.round()}m del campus (límite: ${_config.radiusMeters.round()}m). '
            'Aún puede continuar con su voto. Esta información será registrada para efectos de auditoría.',
            GeofenceErrorType.outsideGeofence,
          ),
        );
      }

      return GeofenceResult(
        isWithinGeofence: true,
        distanceInMeters: distance,
        currentPosition: position,
        timestamp: DateTime.now(),
      );
    } on GeofenceException catch (e) {
      await _cacheValidationStatus(false);
      return GeofenceResult(
        isWithinGeofence: false,
        error: e,
      );
    } catch (e) {
      await _cacheValidationStatus(false);
      return GeofenceResult(
        isWithinGeofence: false,
        error: GeofenceException(
          'Error al validar la ubicación: ${e.toString()}',
          GeofenceErrorType.unknown,
        ),
      );
    }
  }

  /// Stream of position updates for continuous monitoring with battery optimization
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int? distanceFilter,
    bool batteryOptimized = false,
  }) {
    final filter = distanceFilter ?? (batteryOptimized ? 10 : 5);

    return _geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: filter,
      ),
    );
  }

  /// Check geofence status with continuous monitoring
  Stream<GeofenceResult> monitorGeofence({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int? distanceFilter,
    bool batteryOptimized = false,
  }) {
    return getPositionStream(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      batteryOptimized: batteryOptimized,
    ).asyncMap((position) async {
      // Detect mock locations
      final mockError = await _detectMockLocation(position);
      if (mockError != null) {
        return GeofenceResult(
          isWithinGeofence: false,
          currentPosition: position,
          error: mockError,
        );
      }

      // Check using polygon or circular geofence
      if (_polygonGeofence != null) {
        final point = GeofencePoint(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        
        final isWithinPolygon = _polygonGeofence!.containsPoint(point);
        
        return GeofenceResult(
          isWithinGeofence: isWithinPolygon,
          currentPosition: position,
          timestamp: DateTime.now(),
          error: isWithinPolygon
              ? null
              : GeofenceException(
                  'Está fuera del área del campus. Su voto será registrado con esta información.',
                  GeofenceErrorType.outsideGeofence,
                ),
        );
      }

      // Circular geofence check
      final distance = calculateHaversineDistance(
        position.latitude,
        position.longitude,
        _config.centerLatitude,
        _config.centerLongitude,
      );

      final isWithinGeofence = distance <= _config.radiusMeters;

      return GeofenceResult(
        isWithinGeofence: isWithinGeofence,
        distanceInMeters: distance,
        currentPosition: position,
        timestamp: DateTime.now(),
        error: isWithinGeofence
            ? null
            : GeofenceException(
                'Está a ${distance.round()}m del campus (límite: ${_config.radiusMeters.round()}m). '
                'Su voto será registrado con esta información.',
                GeofenceErrorType.outsideGeofence,
              ),
      );
    });
  }

  /// Start continuous geofence monitoring
  Stream<GeofenceResult> startContinuousMonitoring({
    bool batteryOptimized = false,
  }) {
    // Cancel any existing subscription
    _positionStreamSubscription?.cancel();

    return monitorGeofence(batteryOptimized: batteryOptimized);
  }

  /// Stop continuous geofence monitoring
  void stopContinuousMonitoring() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Get a human-readable error message for the user
  static String getErrorMessage(GeofenceException exception) {
    switch (exception.type) {
      case GeofenceErrorType.permissionDenied:
        return 'Se ha denegado el permiso de ubicación. Por favor, habilite los permisos de ubicación en la configuración de la aplicación para continuar.';
      case GeofenceErrorType.permissionPermanentlyDenied:
        return 'El permiso de ubicación ha sido permanentemente denegado. Por favor, habilite los permisos de ubicación en la configuración de su dispositivo.';
      case GeofenceErrorType.locationDisabled:
        return 'El GPS está desactivado. Por favor, active los servicios de ubicación para continuar con la verificación.';
      case GeofenceErrorType.locationUnavailable:
        return 'No se pudo obtener su ubicación. Verifique que el GPS esté activado y tenga buena señal.';
      case GeofenceErrorType.timeout:
        return 'La solicitud de ubicación agotó el tiempo de espera. Por favor, intente de nuevo.';
      case GeofenceErrorType.outsideGeofence:
        return 'Su ubicación actual está fuera del radio de 200m del campus universitario. '
            'Aún puede continuar con su voto. Esta información será registrada para efectos de auditoría.';
      case GeofenceErrorType.mockLocationDetected:
        return 'Se ha detectado una ubicación simulada o manipulada. La votación requiere ubicación física real.\n\n'
            'Por favor, desactive cualquier aplicación de suplantación de GPS.';
      case GeofenceErrorType.accuracyTooLow:
        return 'La precisión de su GPS es insuficiente. Por favor, muévase a un área abierta con mejor señal GPS.';
      case GeofenceErrorType.locationCacheExpired:
        return 'La ubicación almacenada ha expirado. Por favor, verifique su ubicación actual.';
      case GeofenceErrorType.unknown:
        return 'Ocurrió un error inesperado al verificar su ubicación. Por favor, intente de nuevo.';
    }
  }

  /// Open device location settings to allow user to enable GPS
  static Future<void> openLocationSettings() async {
    final GeolocatorPlatform geolocatorPlatform = GeolocatorPlatform.instance;
    try {
      await geolocatorPlatform.openLocationSettings();
    } catch (e) {
      throw GeofenceException(
        'No se pudo abrir la configuración de ubicación. Por favor, habilite el GPS manualmente en la configuración de su dispositivo.',
        GeofenceErrorType.locationDisabled,
      );
    }
  }

  /// Open app settings to allow user to grant location permissions
  static Future<void> openAppSettings() async {
    final GeolocatorPlatform geolocatorPlatform = GeolocatorPlatform.instance;
    try {
      await geolocatorPlatform.openAppSettings();
    } catch (e) {
      throw GeofenceException(
        'No se pudo abrir la configuración de la aplicación. Por favor, otorgue los permisos de ubicación manualmente en la configuración de su dispositivo.',
        GeofenceErrorType.permissionPermanentlyDenied,
      );
    }
  }

  /// Clear location cache (useful for testing or when location changes significantly)
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_locationCacheKey);
      await prefs.remove(_geofenceValidationKey);
      await prefs.remove(_geofenceStatusKey);
    } catch (e) {
      // Silent fail
    }
  }

  /// Get cached validation status (quick check without GPS)
  Future<bool?> getCachedValidationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_geofenceStatusKey);
    } catch (e) {
      return null;
    }
  }

  /// Check if device is likely in a location that has been previously validated
  Future<bool> wasPreviouslyWithinGeofence() async {
    final cachedStatus = await getCachedValidationStatus();
    return cachedStatus ?? false;
  }

  /// Dispose of resources
  void dispose() {
    stopContinuousMonitoring();
  }
}
