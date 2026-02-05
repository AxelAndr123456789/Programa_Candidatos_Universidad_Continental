import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Views
import 'views/splash_screen.dart';
import 'views/login_screen.dart';
import 'views/register_screen.dart';
import 'views/candidate_screen.dart';
import 'views/results_screen.dart';
import 'views/geofence_verification_screen.dart';

// ViewModels
import 'viewmodels/login_viewmodel.dart';
import 'viewmodels/register_viewmodel.dart';
import 'viewmodels/candidate_viewmodel.dart';
import 'viewmodels/results_viewmodel.dart';

// Services
import 'services/auth_service.dart';
import 'services/candidate_service.dart';
import 'services/geofence_service.dart';
import 'repositories/election_repository.dart';

// Utils
import 'utils/responsive_utils.dart';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Geofence Service
  await GeofenceService.initialize();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const EleccionDelegadoApp());
  });
}

class EleccionDelegadoApp extends StatelessWidget {
  const EleccionDelegadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF003366),
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    
    // Inicializar servicios
    final authService = AuthService();
    final candidateService = CandidateService();
    
    return MaterialApp(
      title: 'Elección Delegado - Ing. de Sistemas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF003366),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
          accentColor: const Color(0xFF0066CC),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF003366),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF003366)),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => LoginScreen(viewModel: LoginViewModel(authService, candidateService)),
        '/register': (context) => RegisterScreen(viewModel: RegisterViewModel(authService)),
        '/candidates': (context) => CandidateScreen(viewModel: CandidateViewModel(candidateService)),
        '/results': (context) => ResultsScreen(viewModel: ResultsViewModel(candidateService)),
        '/geofence-verification': (context) => GeofenceVerificationScreen(
              onVerificationComplete: (isVerified) {
                // La verificación se maneja en el stream
              },
            ),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          return MaterialPageRoute(
            builder: (context) => _HomeRedirector(
              candidateService: candidateService,
            ),
          );
        }
        return null;
      },
    );
  }
}

// Widget especial para manejar la redirección después del login
class _HomeRedirector extends StatefulWidget {
  final CandidateService candidateService;
  
  const _HomeRedirector({required this.candidateService});
  
  @override
  __HomeRedirectorState createState() => __HomeRedirectorState();
}

class __HomeRedirectorState extends State<_HomeRedirector> {
  bool _isLoading = true;
  bool _hasVoted = false;
  
  @override
  void initState() {
    super.initState();
    _checkUserVoteStatus();
  }
  
  Future<void> _checkUserVoteStatus() async {
    try {
      final currentUser = supabase.auth.currentUser;
      
      if (currentUser != null) {
        final electionRepository = ElectionRepository();
        _hasVoted = await electionRepository.hasUserVoted(currentUser.id);
      }
    } catch (e) {
      _hasVoted = false;
    }
    
    _checkElectionStatus();
  }
  
  Future<void> _checkElectionStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      final electionRepository = ElectionRepository();
      final int currentVotes = await electionRepository.getTotalVotes();
      final bool showWinnerDialog = await electionRepository.getShowWinnerDialog();
      final int maxVotes = 5;
      
      if (mounted) {
        if (currentVotes >= maxVotes) {
          if (showWinnerDialog) {
            Navigator.pushReplacementNamed(context, '/results');
            await Future.delayed(const Duration(milliseconds: 800));
            
            if (mounted) {
              _showWinnerDialogOnResults();
            }
          } else {
            Navigator.pushReplacementNamed(context, '/results');
          }
        } 
        else if (_hasVoted) {
          Navigator.pushReplacementNamed(context, '/results');
        } 
        else {
          Navigator.pushReplacementNamed(context, '/candidates');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _showWinnerDialogOnResults() {
    widget.candidateService.getCandidatesWithVotes().then((candidates) async {
      List<Candidate> winners = [];
      if (candidates.isNotEmpty) {
        int maxVotes = candidates.map((c) => c.votes).reduce((a, b) => a > b ? a : b);
        winners = candidates.where((c) => c.votes == maxVotes).toList();
      }
      
      if (winners.isNotEmpty && mounted) {
        final bool isTie = winners.length > 1;
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.85),
          builder: (context) {
            return _WinnerDialog(winners: winners, isTie: isTie);
          },
        );
        
        if (mounted) {
          try {
            final electionRepository = ElectionRepository();
            await electionRepository.setShowWinnerDialog(false);
          } catch (e) {
            // Error clearing winner dialog flag
          }
        }
      }
    }).catchError((error) {
      // Error showing winner dialog
    });
  }
  
  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final circularSize = context.circularSize(100);
    final iconSize = context.iconSize(50);
    final fontSizeTitle = context.fontSize(20);
    final progressSize = context.iconSize(40);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF003366),
        body: Center(
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
                    ),
                  ],
                ),
                child: Icon(
                  Icons.how_to_vote,
                  size: iconSize,
                  color: const Color(0xFF003366),
                ),
              ),
              SizedBox(height: context.spacing(30)),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontSize: fontSizeTitle,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.spacing(20)),
              SizedBox(
                width: progressSize,
                height: progressSize,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container();
  }
}

// Diálogo del ganador responsivo
class _WinnerDialog extends StatelessWidget {
  final List<Candidate> winners;
  final bool isTie;
  
  const _WinnerDialog({required this.winners, required this.isTie});
  
  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final dialogWidth = context.width(0.9);
    final iconSize = context.iconSize(50);
    final titleFontSize = context.fontSize(28);
    final subtitleFontSize = context.fontSize(16);
    final cardImageSize = 140.0;
    final borderRadius = context.borderRadius(30);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SingleChildScrollView(
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF003366),
                Color(0xFF0066CC),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
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
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFD700),
                          Color(0xFFFFA500),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(borderRadius),
                        topRight: Radius.circular(borderRadius),
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
                              size: iconSize * 1.2,
                            ),
                            Icon(
                              isTie ? Icons.groups : Icons.emoji_events,
                              size: iconSize,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        SizedBox(height: context.spacing(20)),
                        Text(
                          isTie ? '¡EMPATE TÉCNICO!' : '¡GANADOR OFICIAL!',
                          style: TextStyle(
                            fontSize: titleFontSize,
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
                            fontSize: subtitleFontSize,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: EdgeInsets.all(context.spacing(25)),
                    child: Column(
                      children: [
                        if (isTie)
                          Column(
                            children: [
                              Text(
                                'Se ha producido un empate entre:',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: context.fontSize(18),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: context.spacing(20)),
                              ...winners.map((winner) => _buildWinnerCard(context, winner, isTie: true)),
                              SizedBox(height: context.spacing(20)),
                              Container(
                                padding: EdgeInsets.all(context.spacing(15)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(context.borderRadius(20)),
                                ),
                                child: Text(
                                  'Se requerirá una segunda vuelta para definir al ganador',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: context.fontSize(14),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              Container(
                                margin: EdgeInsets.only(bottom: context.spacing(20)),
                                padding: EdgeInsets.all(context.spacing(4)),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFFA500),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(context.borderRadius(25)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.yellow.withValues(alpha: 0.4),
                                      blurRadius: context.spacing(20),
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: EdgeInsets.all(context.spacing(4)),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(context.borderRadius(20)),
                                  ),
                                  child: Container(
                                    width: cardImageSize,
                                    height: cardImageSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: winners.first.cardColor,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          blurRadius: context.spacing(20),
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(context.borderRadius(35)),
                                      child: Image.asset(
                                        winners.first.imagePath,
                                        width: cardImageSize,
                                        height: cardImageSize,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  winners.first.cardColor,
                                                  winners.first.cardColor.withValues(alpha: 0.8),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                winners.first.avatarLetters,
                                                style: TextStyle(
                                                  fontSize: context.fontSize(40),
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
                                ),
                              ),
                              
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.spacing(20), 
                                  vertical: context.spacing(15)
                                ),
                                margin: EdgeInsets.only(bottom: context.spacing(15)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(context.borderRadius(20)),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      winners.first.name.split(' ').take(2).join(' '),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: context.fontSize(22),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: context.spacing(5)),
                                    Text(
                                      winners.first.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: context.fontSize(14),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              Container(
                                padding: EdgeInsets.all(context.spacing(20)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(context.borderRadius(20)),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStatItemDialog(
                                          icon: Icons.how_to_vote_rounded,
                                          label: 'Votos',
                                          value: '${winners.first.votes}',
                                          color: Colors.white,
                                        ),
                                        _buildStatItemDialog(
                                          icon: Icons.percent_rounded,
                                          label: 'Porcentaje',
                                          value: '${winners.first.percentage.toStringAsFixed(1)}%',
                                          color: Colors.white,
                                        ),
                                        _buildStatItemDialog(
                                          icon: Icons.school_rounded,
                                          label: 'Ciclo',
                                          value: winners.first.ciclo,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: context.spacing(15)),
                                    Container(
                                      padding: EdgeInsets.all(context.spacing(12)),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Propuesta Principal:',
                                            style: TextStyle(
                                              fontSize: context.fontSize(14),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: context.spacing(8)),
                                          Text(
                                            winners.first.plan,
                                            style: TextStyle(
                                              fontSize: context.fontSize(14),
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        
                        SizedBox(height: context.spacing(25)),
                        
                        Container(
                          padding: EdgeInsets.all(context.spacing(16)),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(context.borderRadius(16)),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.flag_rounded,
                                color: Colors.white,
                                size: context.iconSize(24),
                              ),
                              SizedBox(height: context.spacing(10)),
                              Text(
                                'Proceso electoral finalizado',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: context.fontSize(16),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: context.spacing(5)),
                              Text(
                                'Gracias por participar en la elección',
                                style: TextStyle(
                                  fontSize: context.fontSize(14),
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: context.spacing(20)),
                        
                        SizedBox(
                          width: double.infinity,
                          height: context.buttonHeight(55),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
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
  }
  
  Widget _buildWinnerCard(BuildContext ctx, Candidate winner, {bool isTie = false}) {
    ResponsiveUtils.init(ctx);
    return Container(
      margin: EdgeInsets.only(bottom: ctx.spacing(15)),
      padding: EdgeInsets.all(ctx.spacing(15)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(
          color: winner.cardColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: ctx.circularSize(50),
            height: ctx.circularSize(50),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: winner.cardColor,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ctx.borderRadius(25)),
              child: Image.asset(
                winner.imagePath,
                width: ctx.circularSize(50),
                height: ctx.circularSize(50),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          winner.cardColor,
                          winner.cardColor.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        winner.avatarLetters,
                        style: TextStyle(
                          fontSize: ctx.fontSize(16),
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
          SizedBox(width: ctx.spacing(15)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winner.name,
                  style: TextStyle(
                    fontSize: ctx.fontSize(14),
                    fontWeight: FontWeight.bold,
                    color: winner.cardColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ctx.spacing(5)),
                Row(
                  children: [
                    Icon(
                      Icons.how_to_vote_rounded,
                      color: winner.cardColor,
                      size: ctx.iconSize(14),
                    ),
                    SizedBox(width: ctx.spacing(5)),
                    Text(
                      '${winner.votes} votos (${winner.percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: ctx.fontSize(12),
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ctx.spacing(8), 
              vertical: ctx.spacing(4)
            ),
            decoration: BoxDecoration(
              color: winner.cardColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(ctx.borderRadius(12)),
              border: Border.all(
                color: winner.cardColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: ctx.iconSize(12),
                  color: winner.cardColor,
                ),
                SizedBox(width: ctx.spacing(4)),
                Text(
                  'EMPATE',
                  style: TextStyle(
                    fontSize: ctx.fontSize(10),
                    fontWeight: FontWeight.bold,
                    color: winner.cardColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItemDialog({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
