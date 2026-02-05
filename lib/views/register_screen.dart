import 'package:flutter/material.dart';
import '../viewmodels/register_viewmodel.dart';
import '../../utils/responsive_utils.dart';

class RegisterScreen extends StatefulWidget {
  final RegisterViewModel viewModel;
  
  const RegisterScreen({super.key, required this.viewModel});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
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

  Future<void> _register() async {
    await widget.viewModel.register();
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
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.padding(0.05)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: context.spacing(30)),
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
                          Icons.person_add,
                          size: iconSize,
                          color: const Color(0xFF003366),
                        ),
                      ),
                      SizedBox(height: context.spacing(20)),
                      Text(
                        'Registrarse',
                        style: TextStyle(
                          fontSize: context.fontSize(28),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: context.spacing(8)),
                      Text(
                        'Crear una cuenta para votar',
                        style: TextStyle(
                          fontSize: context.fontSize(16),
                          color: Colors.white70,
                        ),
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
                        blurRadius: context.spacing(30),
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Correo institucional',
                            style: TextStyle(
                              color: const Color(0xFF003366),
                              fontWeight: FontWeight.w600,
                              fontSize: context.fontSize(14),
                            ),
                          ),
                          SizedBox(height: context.spacing(8)),
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
                                vertical: context.spacing(16),
                                horizontal: context.spacing(20),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              widget.viewModel.onEmailChanged(value);
                            },
                          ),
                        ],
                      ),
                      
                      SizedBox(height: context.spacing(20)),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contraseña',
                            style: TextStyle(
                              color: const Color(0xFF003366),
                              fontWeight: FontWeight.w600,
                              fontSize: context.fontSize(14),
                            ),
                          ),
                          SizedBox(height: context.spacing(8)),
                          TextFormField(
                            controller: widget.viewModel.passwordController,
                            decoration: InputDecoration(
                              hintText: 'Mínimo 6 caracteres',
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
                                vertical: context.spacing(16),
                                horizontal: context.spacing(20),
                              ),
                            ),
                            obscureText: !widget.viewModel.passwordVisible,
                          ),
                        ],
                      ),
                      
                      SizedBox(height: context.spacing(20)),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirmar contraseña',
                            style: TextStyle(
                              color: const Color(0xFF003366),
                              fontWeight: FontWeight.w600,
                              fontSize: context.fontSize(14),
                            ),
                          ),
                          SizedBox(height: context.spacing(8)),
                          TextFormField(
                            controller: widget.viewModel.confirmPasswordController,
                            decoration: InputDecoration(
                              hintText: 'Repite tu contraseña',
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: const Icon(
                                Icons.lock_reset_rounded,
                                color: Color(0xFF003366),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  widget.viewModel.confirmPasswordVisible 
                                    ? Icons.visibility_off_rounded 
                                    : Icons.visibility_rounded,
                                  color: const Color(0xFF003366).withValues(alpha: 0.7),
                                ),
                                onPressed: () {
                                  widget.viewModel.toggleConfirmPasswordVisibility();
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
                                vertical: context.spacing(16),
                                horizontal: context.spacing(20),
                              ),
                            ),
                            obscureText: !widget.viewModel.confirmPasswordVisible,
                          ),
                        ],
                      ),
                      
                      if (widget.viewModel.errorMessage.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: context.spacing(20)),
                          child: Container(
                            padding: EdgeInsets.all(context.spacing(15)),
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
                                  size: context.iconSize(22),
                                ),
                                SizedBox(width: context.spacing(12)),
                                Expanded(
                                  child: Text(
                                    widget.viewModel.errorMessage,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: context.fontSize(14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      if (widget.viewModel.successMessage.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: context.spacing(20)),
                          child: Container(
                            padding: EdgeInsets.all(context.spacing(15)),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(context.borderRadius(12)),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.green.shade700,
                                  size: context.iconSize(22),
                                ),
                                SizedBox(width: context.spacing(12)),
                                Expanded(
                                  child: Text(
                                    widget.viewModel.successMessage,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: context.fontSize(14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      SizedBox(height: context.spacing(30)),
                      
                      SizedBox(
                        width: double.infinity,
                        height: context.buttonHeight(55),
                        child: ElevatedButton(
                          onPressed: (widget.viewModel.isEmailValid && !widget.viewModel.isLoading) 
                              ? _register 
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
                                      width: context.iconSize(20),
                                      height: context.iconSize(20),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                    SizedBox(width: context.spacing(12)),
                                    Text(
                                      'REGISTRANDO...',
                                      style: TextStyle(
                                        fontSize: context.fontSize(16),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add, size: context.iconSize(22)),
                                    SizedBox(width: context.spacing(10)),
                                    Text(
                                      'REGISTRARSE',
                                      style: TextStyle(
                                        fontSize: context.fontSize(16),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      SizedBox(height: context.spacing(20)),
                      
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            '¿Ya tienes cuenta? Iniciar Sesión',
                            style: TextStyle(
                              color: const Color(0xFF003366),
                              fontWeight: FontWeight.w600,
                              fontSize: context.fontSize(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
