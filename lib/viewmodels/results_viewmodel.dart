import 'package:flutter/material.dart';
import '../services/candidate_service.dart';

class ResultsViewModel extends ChangeNotifier {
  final CandidateService _candidateService;
  
  List<Candidate> _candidates = [];
  List<Candidate> _winners = [];
  
  ResultsViewModel(this._candidateService);

  List<Candidate> get candidates => _candidates;
  List<Candidate> get winners => _winners;
  bool get isTie => _winners.length > 1;

  Future<void> initialize() async {
    await _loadResults();
  }

  Future<void> _loadResults() async {
    _candidates = await _candidateService.getCandidatesWithVotes();
    _candidates.sort((a, b) => b.votes.compareTo(a.votes));
    
    // Calcular porcentajes
    for (var candidate in _candidates) {
      candidate.percentage = (candidate.votes / 5) * 100;
    }
    
    // Determinar ganadores
    if (_candidates.isNotEmpty) {
      int maxVotes = _candidates[0].votes;
      _winners = _candidates.where((c) => c.votes == maxVotes).toList();
    }
    
    notifyListeners();
  }

  Future<void> logout() async {
    await _candidateService.logout();
  }
}