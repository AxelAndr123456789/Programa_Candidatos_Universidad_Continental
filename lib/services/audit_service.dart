import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;

/// Modelo para registrar cada intento de votación con fines de auditoría
class VoteAuditEntry {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String? userEmail;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final bool isWithinGeofence;
  final double? distanceFromCampus;
  final String voteResult; // 'success', 'outside_geofence', 'error', 'cancelled'
  final String? candidateId;
  final String? errorMessage;
  final String deviceInfo;
  final String appVersion;

  VoteAuditEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    this.userEmail,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.isWithinGeofence,
    this.distanceFromCampus,
    required this.voteResult,
    this.candidateId,
    this.errorMessage,
    required this.deviceInfo,
    required this.appVersion,
  });

  /// Convertir a JSON para almacenamiento
  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
        'userEmail': userEmail,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'isWithinGeofence': isWithinGeofence,
        'distanceFromCampus': distanceFromCampus,
        'voteResult': voteResult,
        'candidateId': candidateId,
        'errorMessage': errorMessage,
        'deviceInfo': deviceInfo,
        'appVersion': appVersion,
      };

  /// Crear desde JSON
  factory VoteAuditEntry.fromJson(Map<String, dynamic> json) {
    return VoteAuditEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
      userEmail: json['userEmail'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
      isWithinGeofence: json['isWithinGeofence'] as bool,
      distanceFromCampus:
          json['distanceFromCampus'] != null ? (json['distanceFromCampus'] as num).toDouble() : null,
      voteResult: json['voteResult'] as String,
      candidateId: json['candidateId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      deviceInfo: json['deviceInfo'] as String,
      appVersion: json['appVersion'] as String,
    );
  }

  /// Resumen legible del registro
  String getSummary() {
    final status = isWithinGeofence ? 'DENTRO' : 'FUERA';
    final distanceStr = distanceFromCampus != null ? '${distanceFromCampus!.round()}m' : 'N/A';
    return '[${timestamp.toString()}] Usuario: $userEmail | Estado: $status | Distancia: $distanceStr | Resultado: $voteResult';
  }
}

/// Servicio de auditoría para registrar todos los intentos de votación
class AuditService {
  static const String _auditStorageKey = 'vote_audit_logs';
  static const int _maxAuditEntries = 1000; // Mantener hasta 1000 registros

  final SharedPreferences _prefs;

  AuditService({required SharedPreferences prefs}) : _prefs = prefs;

  /// Generar un ID único para el registro
  static String generateAuditId() {
    return 'audit_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomSuffix()}';
  }

  static String _generateRandomSuffix() {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = StringBuffer();
    for (int i = 0; i < 8; i++) {
      random.write(chars[_getRandomInt(chars.length)]);
    }
    return random.toString();
  }

  static int _getRandomInt(int max) {
    return DateTime.now().microsecondsSinceEpoch % max;
  }

  /// Registrar un intento de votación
  Future<void> logVoteAttempt({
    required String userId,
    String? userEmail,
    required Position position,
    required bool isWithinGeofence,
    double? distanceFromCampus,
    required String voteResult,
    String? candidateId,
    String? errorMessage,
    String deviceInfo = 'Unknown',
    String appVersion = '1.0.0',
  }) async {
    final entry = VoteAuditEntry(
      id: generateAuditId(),
      timestamp: DateTime.now(),
      userId: userId,
      userEmail: userEmail,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      isWithinGeofence: isWithinGeofence,
      distanceFromCampus: distanceFromCampus,
      voteResult: voteResult,
      candidateId: candidateId,
      errorMessage: errorMessage,
      deviceInfo: deviceInfo,
      appVersion: appVersion,
    );

    await _saveAuditEntry(entry);
  }

  /// Registrar verificación de geolocalización sin voto
  Future<void> logLocationCheck({
    required String userId,
    String? userEmail,
    required Position position,
    required bool isWithinGeofence,
    double? distanceFromCampus,
    String? errorMessage,
    String deviceInfo = 'Unknown',
    String appVersion = '1.0.0',
  }) async {
    final entry = VoteAuditEntry(
      id: generateAuditId(),
      timestamp: DateTime.now(),
      userId: userId,
      userEmail: userEmail,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      isWithinGeofence: isWithinGeofence,
      distanceFromCampus: distanceFromCampus,
      voteResult: 'location_check',
      errorMessage: errorMessage,
      deviceInfo: deviceInfo,
      appVersion: appVersion,
    );

    await _saveAuditEntry(entry);
  }

  /// Guardar un registro de auditoría
  Future<void> _saveAuditEntry(VoteAuditEntry entry) async {
    try {
      final existingLogs = await getAuditLogs();
      existingLogs.insert(0, entry);

      // Limitar a los últimos _maxAuditEntries registros
      if (existingLogs.length > _maxAuditEntries) {
        existingLogs.removeRange(_maxAuditEntries, existingLogs.length);
      }

      // Convertir a JSON strings
      final jsonStrings = existingLogs.map((e) => jsonEncode(e.toJson())).toList();
      await _prefs.setStringList(_auditStorageKey, jsonStrings);
    } catch (e) {
      // Log de error pero no fallar la operación principal
      developer.log('Error al guardar registro de auditoría: $e');
    }
  }

  /// Obtener todos los registros de auditoría
  Future<List<VoteAuditEntry>> getAuditLogs() async {
    try {
      final jsonStrings = _prefs.getStringList(_auditStorageKey);
      if (jsonStrings == null || jsonStrings.isEmpty) {
        return [];
      }

      return jsonStrings.map((jsonStr) {
        try {
          return VoteAuditEntry.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
        } catch (e) {
          return null;
        }
      }).where((entry) => entry != null).cast<VoteAuditEntry>().toList();
    } catch (e) {
      developer.log('Error al obtener registros de auditoría: $e');
      return [];
    }
  }

  /// Obtener registros de auditoría para un usuario específico
  Future<List<VoteAuditEntry>> getAuditLogsForUser(String userId) async {
    final allLogs = await getAuditLogs();
    return allLogs.where((entry) => entry.userId == userId).toList();
  }

  /// Obtener registros de auditoría para un rango de fechas
  Future<List<VoteAuditEntry>> getAuditLogsForDateRange(DateTime start, DateTime end) async {
    final allLogs = await getAuditLogs();
    return allLogs
        .where((entry) => entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end))
        .toList();
  }

  /// Obtener estadísticas de auditoría
  Future<AuditStatistics> getAuditStatistics() async {
    final logs = await getAuditLogs();

    final totalAttempts = logs.length;
    final successfulVotes = logs.where((e) => e.voteResult == 'success').length;
    final failedDueToGeofence = logs.where((e) => e.voteResult == 'outside_geofence').length;
    final errors = logs.where((e) => e.voteResult == 'error').length;

    final insideCampus = logs.where((e) => e.isWithinGeofence).length;
    final outsideCampus = logs.where((e) => !e.isWithinGeofence).length;

    // Calcular distancia promedio cuando está fuera
    final outsideLogs = logs.where((e) => !e.isWithinGeofence && e.distanceFromCampus != null);
    final avgDistanceOutside = outsideLogs.isNotEmpty
        ? outsideLogs.map((e) => e.distanceFromCampus!).reduce((a, b) => a + b) / outsideLogs.length
        : 0.0;

    return AuditStatistics(
      totalAttempts: totalAttempts,
      successfulVotes: successfulVotes,
      failedDueToGeofence: failedDueToGeofence,
      errors: errors,
      insideCampus: insideCampus,
      outsideCampus: outsideCampus,
      averageDistanceOutside: avgDistanceOutside,
    );
  }

  /// Limpiar registros de auditoría antiguos
  Future<void> clearOldLogs({int keepLast = 100}) async {
    final logs = await getAuditLogs();
    if (logs.length > keepLast) {
      final logsToKeep = logs.sublist(0, keepLast);
      final jsonStrings = logsToKeep.map((e) => jsonEncode(e.toJson())).toList();
      await _prefs.setStringList(_auditStorageKey, jsonStrings);
    }
  }

  /// Exportar registros de auditoría como JSON
  Future<String> exportAuditLogsAsJson() async {
    final logs = await getAuditLogs();
    final jsonData = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalEntries': logs.length,
      'entries': logs.map((e) => e.toJson()).toList(),
    };
    return jsonEncode(jsonData);
  }

  /// Exportar registros de auditoría como CSV
  Future<String> exportAuditLogsAsCsv() async {
    final logs = await getAuditLogs();
    final buffer = StringBuffer();

    // Header
    buffer.write('ID,Timestamp,User ID,Email,Latitude,Longitude,Accuracy,Within Geofence,Distance (m),Vote Result,Candidate ID,Error Message,Device Info,App Version\n');

    // Data rows
    for (final entry in logs) {
      buffer.write('${entry.id},');
      buffer.write('${entry.timestamp.toIso8601String()},');
      buffer.write('${entry.userId},');
      buffer.write('${entry.userEmail ?? 'N/A'},');
      buffer.write('${entry.latitude},');
      buffer.write('${entry.longitude},');
      buffer.write('${entry.accuracy?.toString() ?? 'N/A'},');
      buffer.write('${entry.isWithinGeofence ? 'Yes' : 'No'},');
      buffer.write('${entry.distanceFromCampus?.toString() ?? 'N/A'},');
      buffer.write('${entry.voteResult},');
      buffer.write('${entry.candidateId ?? 'N/A'},');
      buffer.write('"${entry.errorMessage?.replaceAll('"', '""') ?? 'N/A'}",');
      buffer.write('"${entry.deviceInfo}",');
      buffer.write('${entry.appVersion}\n');
    }

    return buffer.toString();
  }
}

/// Estadísticas de auditoría
class AuditStatistics {
  final int totalAttempts;
  final int successfulVotes;
  final int failedDueToGeofence;
  final int errors;
  final int insideCampus;
  final int outsideCampus;
  final double averageDistanceOutside;

  AuditStatistics({
    required this.totalAttempts,
    required this.successfulVotes,
    required this.failedDueToGeofence,
    required this.errors,
    required this.insideCampus,
    required this.outsideCampus,
    required this.averageDistanceOutside,
  });

  double get successRate => totalAttempts > 0 ? (successfulVotes / totalAttempts) * 100 : 0;
  double get geofenceFailureRate => totalAttempts > 0 ? (failedDueToGeofence / totalAttempts) * 100 : 0;
}
