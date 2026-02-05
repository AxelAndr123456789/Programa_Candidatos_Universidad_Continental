import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/responsive_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _controller.forward();
    
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: context.width(0.08)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = context.isLandscape;
              final maxWidth = isLandscape ? context.screenWidth * 0.4 : context.screenWidth;
              
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: context.height(0.1)),
                        
                        // Responsive main icon
                        FractionallySizedBox(
                          widthFactor: isLandscape ? 0.4 : 0.35,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ScaleTransition(
                              scale: _animation,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF003366), Color(0xFF0066CC)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0066CC).withValues(alpha: 0.3),
                                      blurRadius: context.spacing(20),
                                      spreadRadius: 5,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.how_to_vote_outlined,
                                  size: context.circularSize(50),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: context.height(0.04)),
                        
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Elección Delegado 2026',
                                  style: TextStyle(
                                    fontSize: context.fontSize(22),
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF003366),
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: context.spacing(6)),
                                Text(
                                  'Ingeniería de Sistemas e Informática',
                                  style: TextStyle(
                                    fontSize: context.fontSize(14),
                                    color: const Color(0xFF0066CC),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: context.spacing(4)),
                                
                                // University logo row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: context.circularSize(20),
                                      height: context.circularSize(20),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(context.borderRadius(4)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(context.borderRadius(4)),
                                        child: Image.asset(
                                          'assets/images/candidates/logo.jpg',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF003366),
                                                borderRadius: BorderRadius.circular(context.borderRadius(4)),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'UC',
                                                  style: TextStyle(
                                                    fontSize: context.fontSize(6),
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
                                    Flexible(
                                      child: Text(
                                        'Universidad Continental',
                                        style: TextStyle(
                                          fontSize: context.fontSize(12),
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: context.height(0.06)),
                                
                                // Loading indicator
                                SizedBox(
                                  width: context.iconSize(36),
                                  height: context.iconSize(36),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      const Color(0xFF0066CC).withValues(alpha: 0.8),
                                    ),
                                    strokeWidth: 3,
                                    backgroundColor: const Color(0xFF003366).withValues(alpha: 0.1),
                                  ),
                                ),
                                
                                SizedBox(height: context.spacing(12)),
                                
                                Text(
                                  'Iniciando sistema de votación...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: context.fontSize(11),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: context.height(0.1)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
