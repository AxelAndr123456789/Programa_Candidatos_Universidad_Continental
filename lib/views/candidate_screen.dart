import 'package:flutter/material.dart';
import '../viewmodels/candidate_viewmodel.dart';
import '../services/candidate_service.dart';
import '../repositories/election_repository.dart';
import '../services/geofence_service.dart';
import '../views/geofence_verification_screen.dart';
import '../../utils/responsive_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class CandidateScreen extends StatefulWidget {
  final CandidateViewModel viewModel;
   
  const CandidateScreen({super.key, required this.viewModel});

  @override
  CandidateScreenState createState() => CandidateScreenState();
}

class CandidateScreenState extends State<CandidateScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  final ElectionRepository _electionRepository = ElectionRepository();

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
    _initialize();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await supabase.Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _initialize() async {
    await widget.viewModel.initialize();
    await _validateGeofence();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowWinnerDialog();
    });
  }

  Future<void> _validateGeofence() async {
    // La validación de geofence se hace en segundo plano para auditoría
    try {
      final result = await _geofenceService.validateGeofence();
      
      // Actualizar estado del viewModel
      await widget.viewModel.verifyLocation(result);
      
      // Registrar verificación de ubicación con auditoría
      if (result.currentPosition != null) {
        await _logLocationCheck(result);
      }
    } catch (e) {
      // Silencioso - no mostrar errores al usuario
    }
  }

  /// Abrir pantalla de verificación de geofence con mapa
  Future<void> _openGeofenceVerification() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceVerificationScreen(
          onVerificationComplete: (isVerified) async {
            // La verificación se maneja en el stream
          },
        ),
      ),
    );
    
    // Actualizar estado después de volver
    if (result == true || result == null) {
      await _validateGeofence();
    }
  }

  /// Mostrar overlay de bloqueo cuando está fuera del geofence
  Widget _buildGeofenceBlockedOverlay() {
    // Solo mostrar bloqueo si está verificado pero fuera del geofence
    if (widget.viewModel.isLocationVerified && !widget.viewModel.isWithinGeofence) {
      return Container(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.spacing(16)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                child: Container(
                  padding: EdgeInsets.all(context.spacing(20)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(context.borderRadius(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: context.spacing(24),
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: context.circularSize(64),
                        height: context.circularSize(64),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_off,
                          size: context.iconSize(32),
                          color: Colors.red.shade700,
                        ),
                      ),
                      SizedBox(height: context.spacing(16)),
                      Text(
                        'UBICACIÓN FUERA DEL CAMPUS',
                        style: TextStyle(
                          fontSize: context.fontSize(18),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF003366),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.spacing(12)),
                      Text(
                        'La aplicación de votación solo funciona dentro del campus universitario.',
                        style: TextStyle(
                          fontSize: context.fontSize(14),
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Mensaje de distancia desde el campus
                      Text(
                        'Estás a ${widget.viewModel.distanceFromCampus?.round() ?? 0}m del campus (límite: 750m)',
                        style: TextStyle(
                          fontSize: context.fontSize(13),
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.spacing(20)),
                      SizedBox(
                        width: double.infinity,
                        height: context.buttonHeight(48),
                        child: ElevatedButton.icon(
                          onPressed: _openGeofenceVerification,
                          icon: Icon(Icons.my_location, size: context.iconSize(18)),
                          label: Text('VERIFICAR MI UBICACIÓN', style: TextStyle(fontSize: context.fontSize(13))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(context.borderRadius(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  /// Registrar verificación de ubicación con auditoría
  Future<void> _logLocationCheck(GeofenceResult result) async {
    try {
      final currentUser = supabase.Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await _electionRepository.logLocationCheckWithAudit(
        userId: currentUser.id,
        userEmail: currentUser.email,
        position: result.currentPosition!,
        isWithinGeofence: result.isWithinGeofence,
        distanceFromCampus: result.distanceInMeters,
        errorMessage: result.error?.message,
      );
    } catch (e) {
      // Silent fail - la auditoría no debe fallar la operación principal
    }
  }

  Future<void> _checkAndShowWinnerDialog() async {
    final shouldShowDialog = await widget.viewModel.shouldShowWinnerDialog();
    
    if (shouldShowDialog && widget.viewModel.currentVotes >= widget.viewModel.maxVotes) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _showWinnerDialogToAll();
      }
    }
  }

  void _showWinnerDialogToAll() async {
    final winners = await widget.viewModel.getWinners();
    
    if (winners.isEmpty) return;

    final bool isTie = winners.length > 1;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SingleChildScrollView(
            child: Container(
              width: context.width(0.9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF003366),
                    Color(0xFF0066CC),
                  ],
                ),
                borderRadius: BorderRadius.circular(context.borderRadius(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: context.spacing(40),
                    spreadRadius: 10,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.spacing(25)),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFFFA500),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  size: context.iconSize(80),
                                ),
                                Icon(
                                  isTie ? Icons.groups : Icons.emoji_events,
                                  size: context.iconSize(60),
                                  color: Colors.white,
                                ),
                              ],
                            ),
                            SizedBox(height: context.spacing(20)),
                            Text(
                              isTie ? '¡EMPATE TÉCNICO!' : '¡GANADOR OFICIAL!',
                              style: TextStyle(
                                fontSize: context.fontSize(28),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black26,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: context.spacing(8)),
                            Text(
                              'Elección Delegado 2026',
                              style: TextStyle(
                                fontSize: context.fontSize(16),
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Padding(
                        padding: EdgeInsets.all(context.spacing(25)),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: context.buttonHeight(55),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  final electionRepository = ElectionRepository();
                                  electionRepository.setShowWinnerDialog(false);
                                  if (mounted) {
                                    Navigator.pushReplacementNamed(context, '/results');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF003366),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(context.borderRadius(16)),
                                  ),
                                  elevation: 4,
                                ),
                                child: Text(
                                  'VER RESULTADOS COMPLETOS',
                                  style: TextStyle(
                                    fontSize: context.fontSize(16),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  Positioned(
                    top: context.spacing(15),
                    right: context.spacing(15),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: context.circularSize(40),
                        height: context.circularSize(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: context.spacing(8),
                              spreadRadius: 1,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: context.iconSize(22),
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitVote() async {
    if (widget.viewModel.selectedCandidateId == null) return;
    
    final candidate = widget.viewModel.candidates.firstWhere(
      (c) => c.id == widget.viewModel.selectedCandidateId,
    );
    
    _showVoteConfirmation(candidate);
  }

  void _showVoteConfirmation(Candidate candidate) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.92,
            ),
            child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      candidate.cardColor.withValues(alpha: 0.95),
                      candidate.cardColor.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(context.borderRadius(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: context.spacing(24),
                      spreadRadius: 8,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Candidate info section
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(context.spacing(20)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(context.borderRadius(24)),
                          topRight: Radius.circular(context.borderRadius(24)),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: context.circularSize(80),
                            height: context.circularSize(80),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: context.spacing(8),
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(context.borderRadius(40)),
                              child: Image.asset(
                                candidate.imagePath,
                                width: context.circularSize(80),
                                height: context.circularSize(80),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.2),
                                          Colors.white.withValues(alpha: 0.1),
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: context.iconSize(40),
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: context.spacing(12)),
                          Text(
                            candidate.name,
                            style: TextStyle(
                              fontSize: context.fontSize(18),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: context.spacing(4)),
                          Text(
                            candidate.ciclo,
                            style: TextStyle(
                              fontSize: context.fontSize(13),
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          SizedBox(height: context.spacing(8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacing(12),
                              vertical: context.spacing(4),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(context.borderRadius(20)),
                            ),
                            child: Text(
                              candidate.plan,
                              style: TextStyle(
                                fontSize: context.fontSize(11),
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Confirmation section
                    Padding(
                      padding: EdgeInsets.all(context.spacing(20)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '¿Estás seguro de tu voto?',
                            style: TextStyle(
                              fontSize: context.fontSize(16),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: context.spacing(8)),
                          Text(
                            'Esta acción no se puede deshacer',
                            style: TextStyle(
                              fontSize: context.fontSize(12),
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: context.spacing(20)),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: context.buttonHeight(48),
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white, width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                      ),
                                      minimumSize: const Size(120, 48),
                                    ),
                                    child: Text(
                                      'Cancelar',
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontSize: context.fontSize(14),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: context.spacing(12)),
                              Expanded(
                                child: SizedBox(
                                  height: context.buttonHeight(48),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await widget.viewModel.submitVote();
                                      // Verificar si se alcanzó el límite de votos
                                      if (widget.viewModel.currentVotes >= widget.viewModel.maxVotes) {
                                        if (mounted) {
                                          // ignore: use_build_context_synchronously
                                          Navigator.pushReplacementNamed(context, '/results');
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: candidate.cardColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: Text(
                                      'Confirmar',
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontSize: context.fontSize(14),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'VOTACIÓN\nDELEGADO 2026',
            style: TextStyle(
              fontSize: context.fontSize(16),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 90,
        actions: [
          // Botón de verificación de ubicación con indicador visual
          Padding(
            padding: EdgeInsets.only(right: context.spacing(8)),
            child: IconButton(
              onPressed: _openGeofenceVerification,
              icon: Container(
                padding: EdgeInsets.all(context.spacing(6)),
                decoration: BoxDecoration(
                  color: widget.viewModel.isLocationVerified 
                    ? (widget.viewModel.isWithinGeofence ? Colors.green : Colors.red)
                    : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.viewModel.isLocationVerified
                    ? (widget.viewModel.isWithinGeofence ? Icons.check : Icons.close)
                    : Icons.location_on,
                  color: widget.viewModel.isLocationVerified ? Colors.white : Colors.grey,
                  size: context.iconSize(18),
                ),
              ),
              tooltip: widget.viewModel.isLocationVerified
                ? (widget.viewModel.isWithinGeofence
                    ? 'Ubicación verificada - Dentro del campus'
                    : 'Ubicación verificada - Fuera del campus')
                : 'Verificar ubicación',
            ),
          ),
          // Botón de salir/volver al login
          Padding(
            padding: EdgeInsets.only(right: context.spacing(8)),
            child: IconButton(
              onPressed: _logout,
              icon: Icon(
                Icons.logout,
                color: Colors.white,
                size: context.iconSize(20),
              ),
              tooltip: 'Salir',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF003366),
                  Color(0xFF0066CC),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                
                // Lista de candidatos
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(context.borderRadius(24)),
                        topRight: Radius.circular(context.borderRadius(24)),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(context.borderRadius(24)),
                        topRight: Radius.circular(context.borderRadius(24)),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.all(context.spacing(16)),
                        itemCount: widget.viewModel.candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = widget.viewModel.candidates[index];
                          final isSelected = widget.viewModel.selectedCandidateId == candidate.id;
                          
                          return Padding(
                            padding: EdgeInsets.only(bottom: context.spacing(16)),
                            child: GestureDetector(
                              onTap: () {
                                if (widget.viewModel.canVote) {
                                  widget.viewModel.selectCandidate(candidate.id);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected ? candidate.cardColor.withValues(alpha: 0.15) : Colors.white,
                                  borderRadius: BorderRadius.circular(context.borderRadius(16)),
                                  border: Border.all(
                                    color: isSelected ? candidate.cardColor : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected 
                                        ? candidate.cardColor.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.05),
                                      blurRadius: context.spacing(16),
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(context.spacing(16)),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: context.circularSize(72),
                                        height: context.circularSize(72),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: candidate.cardColor.withValues(alpha: 0.3),
                                            width: 3,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(context.borderRadius(36)),
                                          child: Image.asset(
                                            candidate.imagePath,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      candidate.cardColor.withValues(alpha: 0.2),
                                                      candidate.cardColor.withValues(alpha: 0.1),
                                                    ],
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.person,
                                                  size: context.iconSize(36),
                                                  color: candidate.cardColor,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: context.spacing(16)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              candidate.name,
                                              style: TextStyle(
                                                fontSize: context.fontSize(16),
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF003366),
                                              ),
                                            ),
                                            SizedBox(height: context.spacing(2)),
                                            Text(
                                              candidate.ciclo,
                                              style: TextStyle(
                                                fontSize: context.fontSize(13),
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            SizedBox(height: context.spacing(8)),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: context.spacing(10),
                                                vertical: context.spacing(4),
                                              ),
                                              decoration: BoxDecoration(
                                                color: candidate.cardColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                              ),
                                              child: Text(
                                                candidate.plan,
                                                style: TextStyle(
                                                  fontSize: context.fontSize(11),
                                                  color: candidate.cardColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          width: context.circularSize(32),
                                          height: context.circularSize(32),
                                          decoration: BoxDecoration(
                                            color: candidate.cardColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: candidate.cardColor.withValues(alpha: 0.4),
                                                blurRadius: context.spacing(8),
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: context.iconSize(18),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                // Botón de votar
                Container(
                  padding: EdgeInsets.all(context.spacing(20)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: context.spacing(24),
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: context.buttonHeight(52),
                      child: ElevatedButton(
                        onPressed: widget.viewModel.selectedCandidateId != null && widget.viewModel.canVote
                            ? _submitVote
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.borderRadius(14)),
                          ),
                          elevation: widget.viewModel.selectedCandidateId != null ? 2 : 0,
                        ),
                        child: Text(
                          widget.viewModel.selectedCandidateId == null
                              ? 'SELECCIONA UN CANDIDATO'
                              : 'VOTAR',
                          style: TextStyle(
                            fontSize: context.fontSize(14),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Overlay de bloqueo de geofence
          _buildGeofenceBlockedOverlay(),
        ],
      ),
    );
  }
}
