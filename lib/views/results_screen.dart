import 'package:flutter/material.dart';
import '../viewmodels/results_viewmodel.dart';
import '../services/candidate_service.dart';
import '../../utils/responsive_utils.dart';

class ResultsScreen extends StatefulWidget {
  final ResultsViewModel viewModel;
  
  const ResultsScreen({super.key, required this.viewModel});

  @override
  ResultsScreenState createState() => ResultsScreenState();
}

class ResultsScreenState extends State<ResultsScreen> {
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

  Future<void> _initialize() async {
    await widget.viewModel.initialize();
  }

  Widget _buildCandidateResult(Candidate candidate, int index) {
    final bool isWinner = widget.viewModel.winners.contains(candidate);
    final bool isTie = widget.viewModel.isTie;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: context.spacing(8), horizontal: context.spacing(16)),
      padding: EdgeInsets.all(context.spacing(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.borderRadius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: context.spacing(12),
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
        border: isWinner
            ? Border.all(
                color: candidate.cardColor,
                width: 3,
              )
            : Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: context.circularSize(40),
                height: context.circularSize(40),
                decoration: BoxDecoration(
                  color: isWinner ? candidate.cardColor : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: context.fontSize(18),
                      fontWeight: FontWeight.bold,
                      color: isWinner ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              
              SizedBox(width: context.spacing(12)),
              
              Container(
                width: context.circularSize(50),
                height: context.circularSize(50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: candidate.cardColor,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.borderRadius(25)),
                  child: Image.asset(
                    candidate.imagePath,
                    width: context.circularSize(50),
                    height: context.circularSize(50),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              candidate.cardColor,
                              candidate.cardColor.withValues(alpha: 0.8),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            candidate.avatarLetters,
                            style: TextStyle(
                              fontSize: context.fontSize(16),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              SizedBox(width: context.spacing(12)),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: TextStyle(
                        fontSize: context.fontSize(14),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF003366),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.spacing(4)),
                    Row(
                      children: [
                        Icon(
                          Icons.how_to_vote_rounded,
                          color: candidate.cardColor,
                          size: context.iconSize(12),
                        ),
                        SizedBox(width: context.spacing(4)),
                        Text(
                          '${candidate.votes} votos',
                          style: TextStyle(
                            fontSize: context.fontSize(12),
                            color: candidate.cardColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (isWinner)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.spacing(8), vertical: context.spacing(4)),
                  decoration: BoxDecoration(
                    color: candidate.cardColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(context.borderRadius(12)),
                    border: Border.all(
                      color: candidate.cardColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTie ? Icons.groups : Icons.emoji_events,
                        size: context.iconSize(12),
                        color: candidate.cardColor,
                      ),
                      SizedBox(width: context.spacing(4)),
                      Text(
                        isTie ? 'EMPATE' : 'GANADOR',
                        style: TextStyle(
                          fontSize: context.fontSize(10),
                          fontWeight: FontWeight.bold,
                          color: candidate.cardColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          SizedBox(height: context.spacing(12)),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: context.spacing(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(context.borderRadius(4)),
                ),
                child: FractionallySizedBox(
                  widthFactor: candidate.percentage / 100,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          candidate.cardColor,
                          candidate.cardColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(context.borderRadius(4)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;
    final bool isDesktop = screenWidth > 900;
    
    // Ajustar tamaños según el dispositivo
    final circularSize = isDesktop ? context.circularSize(120) : (isTablet ? context.circularSize(100) : context.circularSize(80));
    final iconSize = isDesktop ? context.iconSize(60) : (isTablet ? context.iconSize(55) : context.circularSize(50));
    final headerPadding = isDesktop ? context.spacing(40) : (isTablet ? context.spacing(35) : context.spacing(30));
    
    return Scaffold(
      body: Container(
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
        child: isDesktop ? _buildDesktopLayout(circularSize, iconSize, headerPadding)
            : _buildMobileLayout(circularSize, iconSize, headerPadding),
      ),
    );
  }

  Widget _buildDesktopLayout(double circularSize, double iconSize, double headerPadding) {
    return Row(
      children: [
        // Panel izquierdo - Header
        Expanded(
          flex: 1,
          child: Container(
            padding: EdgeInsets.all(headerPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: circularSize,
                  height: circularSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: context.spacing(20),
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.viewModel.isTie ? Icons.groups : Icons.emoji_events,
                    size: iconSize,
                    color: const Color(0xFF003366),
                  ),
                ),
                SizedBox(height: context.spacing(20)),
                Text(
                  widget.viewModel.isTie ? 'Resultados - Empate' : 'Resultados Oficiales',
                  style: TextStyle(
                    fontSize: context.fontSize(28),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.spacing(8)),
                Text(
                  'Elección Delegado 2026',
                  style: TextStyle(
                    fontSize: context.fontSize(18),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.spacing(4)),
                Text(
                  'Ingeniería de Sistemas e Informática',
                  style: TextStyle(
                    fontSize: context.fontSize(14),
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: context.spacing(4)),
                Text(
                  'Universidad Continental',
                  style: TextStyle(
                    fontSize: context.fontSize(12),
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Panel derecho - Lista de resultados
        Expanded(
          flex: 2,
          child: _buildResultsList(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(double circularSize, double iconSize, double headerPadding) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: headerPadding, vertical: headerPadding),
          child: Column(
            children: [
              Container(
                width: circularSize,
                height: circularSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: context.spacing(20),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  widget.viewModel.isTie ? Icons.groups : Icons.emoji_events,
                  size: iconSize,
                  color: const Color(0xFF003366),
                ),
              ),
              SizedBox(height: context.spacing(15)),
              Text(
                widget.viewModel.isTie ? 'Resultados - Empate' : 'Resultados Oficiales',
                style: TextStyle(
                  fontSize: context.fontSize(28),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.spacing(6)),
              Text(
                'Elección Delegado 2026',
                style: TextStyle(
                  fontSize: context.fontSize(18),
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: context.spacing(3)),
              Text(
                'Ingeniería de Sistemas e Informática',
                style: TextStyle(
                  fontSize: context.fontSize(14),
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: context.spacing(3)),
              Text(
                'Universidad Continental',
                style: TextStyle(
                  fontSize: context.fontSize(12),
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildResultsList(),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: context.spacing(5)),
          Container(
            padding: EdgeInsets.symmetric(vertical: context.spacing(10), horizontal: context.spacing(20)),
            child: Text(
              'Clasificación Final',
              style: TextStyle(
                fontSize: context.fontSize(22),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF003366),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.viewModel.candidates.length,
              itemBuilder: (context, index) {
                return _buildCandidateResult(widget.viewModel.candidates[index], index);
              },
            ),
          ),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      padding: EdgeInsets.all(context.spacing(20)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey,
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: context.buttonHeight(55),
        child: ElevatedButton(
          onPressed: () async {
            await widget.viewModel.logout();
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.pushReplacementNamed(context, '/login');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003366),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.borderRadius(12)),
            ),
            elevation: 3,
          ),
          child: Text(
            'CERRAR SESIÓN',
            style: TextStyle(
              fontSize: context.fontSize(16),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
