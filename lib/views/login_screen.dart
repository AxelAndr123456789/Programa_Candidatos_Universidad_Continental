import 'package:flutter/material.dart';
import '../viewmodels/login_viewmodel.dart';
import '../../utils/responsive_utils.dart';

class LoginScreen extends StatefulWidget {
  final LoginViewModel viewModel;
  
  const LoginScreen({super.key, required this.viewModel});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
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

  Future<void> _login() async {
    final result = await widget.viewModel.login();
    
    if (result.success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final circularSize = context.circularSize(100);
    final iconSize = context.iconSize(50);
    final containerWidth = context.width(0.9);
    
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.padding(0.05)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: context.spacing(24)),
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
                                blurRadius: context.spacing(16),
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.how_to_vote,
                            size: iconSize,
                            color: const Color(0xFF003366),
                          ),
                        ),
                        SizedBox(height: context.spacing(20)),
                        Text(
                          'Elección Delegado 2026',
                          style: TextStyle(
                            fontSize: context.fontSize(24),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.spacing(6)),
                        Text(
                          'Ingeniería de Sistemas e Informática',
                          style: TextStyle(
                            fontSize: context.fontSize(16),
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.spacing(4)),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: context.circularSize(22),
                              height: context.circularSize(22),
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
                                  width: context.circularSize(22),
                                  height: context.circularSize(22),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(context.borderRadius(4)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'UC',
                                          style: TextStyle(
                                            fontSize: context.fontSize(7),
                                            fontWeight: FontWeight.bold,
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
                                  fontSize: context.fontSize(14),
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    width: containerWidth,
                    padding: EdgeInsets.all(context.padding(0.07)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(context.borderRadius(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: context.spacing(24),
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: context.fontSize(22),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF003366),
                          ),
                        ),
                        SizedBox(height: context.spacing(4)),
                        Text(
                          'Ingresa tus credenciales para votar',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: context.fontSize(13),
                          ),
                        ),
                        
                        SizedBox(height: context.spacing(20)),
                        
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Correo institucional',
                              style: TextStyle(
                                color: const Color(0xFF003366),
                                fontWeight: FontWeight.w600,
                                fontSize: context.fontSize(13),
                              ),
                            ),
                            SizedBox(height: context.spacing(6)),
                            TextFormField(
                              controller: widget.viewModel.emailController,
                              decoration: InputDecoration(
                                hintText: 'usuario@continental.edu.pe',
                                hintStyle: const TextStyle(color: Colors.grey),
                                prefixIcon: const Icon(
                                  Icons.email_rounded,
                                  color: Color(0xFF003366),
                                ),
                                suffixIcon: widget.viewModel.getEmailValidationIcon(),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                  borderSide: BorderSide(
                                    color: widget.viewModel.getEmailBorderColor(),
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                  borderSide: BorderSide(
                                    color: widget.viewModel.getEmailBorderColor(),
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: context.spacing(14),
                                  horizontal: context.spacing(16),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (value) {
                                widget.viewModel.onEmailChanged(value);
                              },
                            ),
                          ],
                        ),
                        
                        SizedBox(height: context.spacing(16)),
                        
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contraseña',
                              style: TextStyle(
                                color: const Color(0xFF003366),
                                fontWeight: FontWeight.w600,
                                fontSize: context.fontSize(13),
                              ),
                            ),
                            SizedBox(height: context.spacing(6)),
                            TextFormField(
                              controller: widget.viewModel.passwordController,
                              decoration: InputDecoration(
                                hintText: 'Ingresa tu contraseña',
                                hintStyle: const TextStyle(color: Colors.grey),
                                prefixIcon: const Icon(
                                  Icons.lock_rounded,
                                  color: Color(0xFF003366),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    widget.viewModel.passwordVisible 
                                        ? Icons.visibility_off_rounded 
                                        : Icons.visibility_rounded,
                                    color: const Color(0xFF003366).withValues(alpha: 0.7),
                                  ),
                                  onPressed: () {
                                    widget.viewModel.togglePasswordVisibility();
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0066CC),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: context.spacing(14),
                                  horizontal: context.spacing(16),
                                ),
                              ),
                              obscureText: !widget.viewModel.passwordVisible,
                            ),
                          ],
                        ),
                        
                        if (widget.viewModel.errorMessage.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: context.spacing(16)),
                            child: Container(
                              padding: EdgeInsets.all(context.spacing(12)),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(context.borderRadius(12)),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.red.shade700,
                                    size: context.iconSize(20),
                                  ),
                                  SizedBox(width: context.spacing(10)),
                                  Expanded(
                                    child: Text(
                                      widget.viewModel.errorMessage,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: context.fontSize(13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        SizedBox(height: context.spacing(24)),
                        
                        SizedBox(
                          width: double.infinity,
                          height: context.buttonHeight(50),
                          child: ElevatedButton(
                            onPressed: (widget.viewModel.isEmailValid && !widget.viewModel.isLoading) 
                                ? _login 
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.borderRadius(12)),
                              ),
                              elevation: 3,
                            ),
                            child: widget.viewModel.isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: context.iconSize(18),
                                        height: context.iconSize(18),
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                      SizedBox(width: context.spacing(10)),
                                      Text(
                                        'VERIFICANDO...',
                                        style: TextStyle(
                                          fontSize: context.fontSize(14),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded, size: context.iconSize(20)),
                                      SizedBox(width: context.spacing(8)),
                                      Text(
                                        'INGRESAR PARA VOTAR',
                                        style: TextStyle(
                                          fontSize: context.fontSize(14),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        
                        SizedBox(height: context.spacing(12)),
                        
                        SizedBox(
                          width: double.infinity,
                          height: context.buttonHeight(50),
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF003366),
                              side: const BorderSide(color: Color(0xFF003366), width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.borderRadius(12)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add, size: context.iconSize(20)),
                                SizedBox(width: context.spacing(8)),
                                Text(
                                  'REGISTRARSE',
                                  style: TextStyle(
                                    fontSize: context.fontSize(14),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: context.spacing(24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
