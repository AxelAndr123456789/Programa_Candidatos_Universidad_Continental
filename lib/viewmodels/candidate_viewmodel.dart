import 'package:flutter/material.dart';
import '../services/candidate_service.dart';
import '../services/geofence_service.dart';

class CandidateViewModel extends ChangeNotifier {
  final CandidateService _candidateService;
  
  List<Candidate> _candidates = [];
  String? _selectedCandidateId;
  bool _isVoting = false;
  bool _hasVoted = false;
  String? _currentUserEmail;
  int _currentVotes = 0;
  
  // Estado de geofence
  bool _isLocationVerified = false;
  bool _isWithinGeofence = false;
  GeofenceException? _geofenceError;
  double? _distanceFromCampus;
  
  CandidateViewModel(this._candidateService);

  List<Candidate> get candidates => _candidates;
  String? get selectedCandidateId => _selectedCandidateId;
  bool get isVoting => _isVoting;
  bool get hasVoted => _hasVoted;
  String? get currentUserEmail => _currentUserEmail;
  int get currentVotes => _currentVotes;
  int get maxVotes => _candidateService.maxVotes;
  
  // Getters de geofence
  bool get isLocationVerified => _isLocationVerified;
  bool get isWithinGeofence => _isWithinGeofence;
  bool get canVote => _isWithinGeofence && !_hasVoted && _currentVotes < _maxVotes;
  int get _maxVotes => _candidateService.maxVotes;
  GeofenceException? get geofenceError => _geofenceError;
  double? get distanceFromCampus => _distanceFromCampus;

  Future<void> initialize() async {
    await _loadCandidates();
    await _checkIfUserHasVoted();
    await _loadVoteCount();
  }

  Future<void> _loadCandidates() async {
    _candidates = await _candidateService.getCandidatesWithVotes();
    _calculatePercentages();
    notifyListeners();
  }

  Future<void> _checkIfUserHasVoted() async {
    _currentUserEmail = await _candidateService.getCurrentUser();
    
    if (_currentUserEmail != null) {
      _hasVoted = await _candidateService.hasUserVoted(_currentUserEmail!);
      notifyListeners();
    }
  }

  Future<void> _loadVoteCount() async {
    _currentVotes = await _candidateService.getCurrentVoteCount();
    notifyListeners();
  }

  void _calculatePercentages() {
    for (var candidate in _candidates) {
      candidate.percentage = (candidate.votes / _maxVotes) * 100;
    }
  }

  void selectCandidate(String candidateId) {
    if (!canVote) return;
    
    _selectedCandidateId = candidateId;
    notifyListeners();
  }

  Future<VoteResult> submitVote() async {
    if (!canVote || _selectedCandidateId == null) {
      return VoteResult(success: false);
    }

    _isVoting = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    if (_currentUserEmail != null) {
      await _candidateService.voteForCandidate(_selectedCandidateId!, _currentUserEmail!);
    }

    await _loadCandidates();
    await _checkIfUserHasVoted();
    await _loadVoteCount();
    
    _isVoting = false;
    notifyListeners();

    final isMaxVotesReached = _currentVotes >= _maxVotes;
    final candidate = _candidates.firstWhere(
      (c) => c.id == _selectedCandidateId,
      orElse: () => _candidates.first,
    );

    return VoteResult(
      success: true,
      candidate: candidate,
      isMaxVotesReached: isMaxVotesReached,
    );
  }

  Future<bool> shouldShowWinnerDialog() async {
    return await _candidateService.shouldShowWinnerDialog();
  }

  Future<List<Candidate>> getWinners() async {
    return _candidateService.getWinners(_candidates);
  }

  Future<void> logout() async {
    await _candidateService.logout();
  }

  // Métodos de geofence
  Future<void> verifyLocation(GeofenceResult result) async {
    _isLocationVerified = true;
    _isWithinGeofence = result.isWithinGeofence;
    _geofenceError = result.error;
    _distanceFromCampus = result.distanceInMeters;
    notifyListeners();
  }

  void clearLocationVerification() {
    _isLocationVerified = false;
    _isWithinGeofence = false;
    _geofenceError = null;
    _distanceFromCampus = null;
    notifyListeners();
  }
}

class VoteResult {
  final bool success;
  final Candidate? candidate;
  final bool isMaxVotesReached;

  VoteResult({
    required this.success,
    this.candidate,
    this.isMaxVotesReached = false,
  });
}