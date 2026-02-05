import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../services/audit_service.dart';

class ElectionRepository {
  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<void> saveCurrentUser(String email) async {
    final prefs = await _prefs;
    await prefs.setString('current_user', email);
  }

  Future<String?> getCurrentUser() async {
    final prefs = await _prefs;
    return prefs.getString('current_user');
  }

  Future<void> removeCurrentUser() async {
    final prefs = await _prefs;
    await prefs.remove('current_user');
  }

  Future<void> saveCandidateVotes(String candidateId, int votes) async {
    final prefs = await _prefs;
    await prefs.setInt('candidate_${candidateId}_votes', votes);
  }

  Future<int> getCandidateVotes(String candidateId) async {
    final prefs = await _prefs;
    return prefs.getInt('candidate_${candidateId}_votes') ?? 0;
  }

  Future<void> setTotalVotes(int votes) async {
    final prefs = await _prefs;
    await prefs.setInt('total_votes', votes);
  }

  Future<int> getTotalVotes() async {
    final prefs = await _prefs;
    return prefs.getInt('total_votes') ?? 0;
  }

  Future<void> markUserAsVoted(String email) async {
    final prefs = await _prefs;
    final votedEmails = prefs.getStringList('voted_emails') ?? [];
    if (!votedEmails.contains(email)) {
      votedEmails.add(email);
      await prefs.setStringList('voted_emails', votedEmails);
    }
  }

  Future<bool> hasUserVoted(String email) async {
    final prefs = await _prefs;
    final votedEmails = prefs.getStringList('voted_emails') ?? [];
    return votedEmails.contains(email);
  }

  Future<void> setShowWinnerDialog(bool show) async {
    final prefs = await _prefs;
    await prefs.setBool('show_winner_dialog', show);
  }

  Future<bool> getShowWinnerDialog() async {
    final prefs = await _prefs;
    return prefs.getBool('show_winner_dialog') ?? false;
  }

  // ========== MÉTODOS DE AUDITORÍA ==========

  /// Registrar un intento de votación con auditoría
  Future<void> logVoteAttemptWithAudit({
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
    try {
      final prefs = await _prefs;
      final auditService = AuditService(prefs: prefs);

      await auditService.logVoteAttempt(
        userId: userId,
        userEmail: userEmail,
        position: position,
        isWithinGeofence: isWithinGeofence,
        distanceFromCampus: distanceFromCampus,
        voteResult: voteResult,
        candidateId: candidateId,
        errorMessage: errorMessage,
        deviceInfo: deviceInfo,
        appVersion: appVersion,
      );
    } catch (e) {
      // Silent fail - la auditoría no debe fallar la operación principal
      if (kDebugMode) {
        print('Error al registrar auditoría: $e');
      }
    }
  }

  /// Registrar verificación de ubicación sin voto
  Future<void> logLocationCheckWithAudit({
    required String userId,
    String? userEmail,
    required Position position,
    required bool isWithinGeofence,
    double? distanceFromCampus,
    String? errorMessage,
    String deviceInfo = 'Unknown',
    String appVersion = '1.0.0',
  }) async {
    try {
      final prefs = await _prefs;
      final auditService = AuditService(prefs: prefs);

      await auditService.logLocationCheck(
        userId: userId,
        userEmail: userEmail,
        position: position,
        isWithinGeofence: isWithinGeofence,
        distanceFromCampus: distanceFromCampus,
        errorMessage: errorMessage,
        deviceInfo: deviceInfo,
        appVersion: appVersion,
      );
    } catch (e) {
      // Silent fail
      if (kDebugMode) {
        print('Error al registrar auditoría de ubicación: $e');
      }
    }
  }

  /// Obtener todos los registros de auditoría
  Future<List<VoteAuditEntry>> getAuditLogs() async {
    try {
      final prefs = await _prefs;
      final auditService = AuditService(prefs: prefs);
      return await auditService.getAuditLogs();
    } catch (e) {
      return [];
    }
  }

  /// Obtener estadísticas de auditoría
  Future<AuditStatistics> getAuditStatistics() async {
    try {
      final prefs = await _prefs;
      final auditService = AuditService(prefs: prefs);
      return await auditService.getAuditStatistics();
    } catch (e) {
      return AuditStatistics(
        totalAttempts: 0,
        successfulVotes: 0,
        failedDueToGeofence: 0,
        errors: 0,
        insideCampus: 0,
        outsideCampus: 0,
        averageDistanceOutside: 0,
      );
    }
  }

  /// Exportar registros de auditoría como JSON
  Future<String> exportAuditLogsAsJson() async {
    final prefs = await _prefs;
    final auditService = AuditService(prefs: prefs);
    return await auditService.exportAuditLogsAsJson();
  }

  /// Exportar registros de auditoría como CSV
  Future<String> exportAuditLogsAsCsv() async {
    final prefs = await _prefs;
    final auditService = AuditService(prefs: prefs);
    return await auditService.exportAuditLogsAsCsv();
  }
}