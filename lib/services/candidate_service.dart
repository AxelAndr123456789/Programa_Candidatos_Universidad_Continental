import 'package:flutter/material.dart';
import '../repositories/election_repository.dart';

class Candidate {
  final String id;
  final String name;
  final String description;
  final String plan;
  final Color cardColor;
  final String avatarLetters;
  final List<String> propuestas;
  final String ciclo;
  final double promedio;
  final String imagePath;
  int votes;
  double percentage;

  Candidate({
    required this.id,
    required this.name,
    required this.description,
    required this.plan,
    required this.cardColor,
    required this.avatarLetters,
    required this.propuestas,
    required this.ciclo,
    required this.promedio,
    required this.imagePath,
    this.votes = 0,
    this.percentage = 0.0,
  });
}

class CandidateService {
  final ElectionRepository _repository = ElectionRepository();
  final int _maxVotes = 5;

  int get maxVotes => _maxVotes;

  final List<Candidate> _candidatesData = [
    Candidate(
      id: '1',
      name: 'BRAYAN ESTIF GUILLÉN SANABRIA',
      description: 'Participante en PERUMIN 35 y Buddys Contihelp',
      plan: 'Mejorar reputación y presencia de la carrera',
      cardColor: const Color(0xFF003366),
      avatarLetters: 'BG',
      ciclo: '6to Ciclo',
      promedio: 16.5,
      imagePath: 'assets/images/candidates/candidate1.jpg',
      propuestas: [
        'Mejorar reputación de la facultad',
        'Mayor presencia en actividades',
        'Proyectos de investigación',
        'Apoyo a estudiantes nuevos',
      ],
    ),
    Candidate(
      id: '2',
      name: 'ÁNGEL ADDAIR JEREMÍAS AVELLANEDA',
      description: 'Enfoque en crecimiento y oportunidades',
      plan: 'Impulsar participación estudiantil',
      cardColor: const Color(0xFF4A148C),
      avatarLetters: 'AA',
      ciclo: '5to Ciclo',
      promedio: 17.2,
      imagePath: 'assets/images/candidates/candidate2.jpg',
      propuestas: [
        'Cursos y talleres técnicos',
        'Proyectos colaborativos',
        'Comunicación directa',
        'Fortalecer formación académica',
      ],
    ),
    Candidate(
      id: '3',
      name: 'GABRIEL DAVID LANDA SABUCO',
      description: 'Enfoque en comunicación estudiantil',
      plan: 'Representación estudiantil activa',
      cardColor: const Color(0xFF00695C),
      avatarLetters: 'GL',
      ciclo: '6to Ciclo',
      promedio: 16.8,
      imagePath: 'assets/images/candidates/candidate3.jpg',
      propuestas: [
        'Comunicación constante',
        'Canalización de necesidades',
        'Representación de intereses',
        'Vinculación con escuela profesional',
      ],
    ),
    Candidate(
      id: '4',
      name: 'ANTHONY ALEXIS PEREZ ORDOÑEZ',
      description: 'Exdelegado de deporte',
      plan: 'Mejorar actividades académicas y deportivas',
      cardColor: const Color(0xFFD84315),
      avatarLetters: 'AP',
      ciclo: '7mo Ciclo',
      promedio: 17.0,
      imagePath: 'assets/images/candidates/candidate4.jpg',
      propuestas: [
        'Mayor organización',
        'Participación estudiantil',
        'Desarrollo integral',
        'Actividades deportivas',
      ],
    ),
  ];

  List<Candidate> getCandidatesData() {
    return List.from(_candidatesData);
  }

  Future<List<Candidate>> getCandidatesWithVotes() async {
    final List<Candidate> candidates = [];
    
    for (var candidateData in _candidatesData) {
      final votes = await _repository.getCandidateVotes(candidateData.id);
      final totalVotes = await _repository.getTotalVotes();
      final percentage = totalVotes > 0 ? (votes / _maxVotes) * 100 : 0.0;
      
      candidates.add(Candidate(
        id: candidateData.id,
        name: candidateData.name,
        description: candidateData.description,
        plan: candidateData.plan,
        cardColor: candidateData.cardColor,
        avatarLetters: candidateData.avatarLetters,
        propuestas: List.from(candidateData.propuestas),
        ciclo: candidateData.ciclo,
        promedio: candidateData.promedio,
        imagePath: candidateData.imagePath,
        votes: votes,
        percentage: percentage,
      ));
    }
    
    return candidates;
  }

  Future<void> voteForCandidate(String candidateId, String userEmail) async {
    final currentVotes = await _repository.getCandidateVotes(candidateId);
    final newVotes = currentVotes + 1;
    
    await _repository.saveCandidateVotes(candidateId, newVotes);
    await _repository.markUserAsVoted(userEmail);
    
    final totalVotes = await _repository.getTotalVotes();
    await _repository.setTotalVotes(totalVotes + 1);
    
    if (totalVotes + 1 >= _maxVotes) {
      await _repository.setShowWinnerDialog(true);
    }
  }

  Future<List<Candidate>> getWinners(List<Candidate> candidates) async {
    if (candidates.isEmpty) return [];

    int maxVotes = candidates.map((c) => c.votes).reduce((a, b) => a > b ? a : b);
    
    return candidates.where((c) => c.votes == maxVotes).toList();
  }

  // AÑADE ESTE NUEVO MÉTODO
  Future<List<Candidate>> getWinnersFromCandidates(List<Candidate> candidates) async {
    if (candidates.isEmpty) return [];

    int maxVotes = candidates.map((c) => c.votes).reduce((a, b) => a > b ? a : b);
    
    return candidates.where((c) => c.votes == maxVotes).toList();
  }

  Future<String?> getCurrentUser() async {
    return await _repository.getCurrentUser();
  }

  Future<void> saveCurrentUser(String email) async {
    await _repository.saveCurrentUser(email);
  }

  Future<void> logout() async {
    await _repository.removeCurrentUser();
  }

  Future<bool> hasUserVoted(String email) async {
    return await _repository.hasUserVoted(email);
  }

  Future<int> getCurrentVoteCount() async {
    return await _repository.getTotalVotes();
  }

  Future<bool> shouldShowWinnerDialog() async {
    return await _repository.getShowWinnerDialog();
  }
}