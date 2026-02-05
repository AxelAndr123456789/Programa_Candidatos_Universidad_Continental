import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/candidate_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService;
  final CandidateService _candidateService;
  
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEmailValid = false;
  String _errorMessage = '';
  bool _passwordVisible = false;
  
  LoginViewModel(this._authService, this._candidateService);

  bool get isLoading => _isLoading;
  bool get isEmailValid => _isEmailValid;
  String get errorMessage => _errorMessage;
  bool get passwordVisible => _passwordVisible;

  void togglePasswordVisibility() {
    _passwordVisible = !_passwordVisible;
    notifyListeners();
  }

  Color getEmailBorderColor() {
    return _authService.getEmailBorderColor(emailController.text);
  }

  Widget? getEmailValidationIcon() {
    return _authService.getEmailValidationIcon(emailController.text);
  }

  void onEmailChanged(String value) {
    _isEmailValid = _authService.validateEmailForLogin(value);
    
    if (_errorMessage.isNotEmpty && _isEmailValid) {
      _errorMessage = '';
    }
    notifyListeners();
  }

  Future<LoginResult> login() async {
    final email = emailController.text.trim();
    
    if (!_authService.validateEmailForLogin(email)) {
      _errorMessage = 'Solo correos @continental.edu.pe pueden votar';
      notifyListeners();
      return LoginResult(error: _errorMessage);
    }

    if (passwordController.text.isEmpty) {
      _errorMessage = 'Ingresa tu contraseña';
      notifyListeners();
      return LoginResult(error: _errorMessage);
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final user = await _authService.login(email, passwordController.text.trim());
      
      if (user != null) {
        final storedPassword = user['password'] as String;
        final inputPassword = passwordController.text.trim();
        
        if (inputPassword == storedPassword) {
          await _candidateService.saveCurrentUser(email);
          
          // En lugar de decidir aquí, simplemente indicar éxito
          // La redirección real se hará en el HomeRedirector
          return LoginResult(success: true);
        } else {
          _errorMessage = 'Contraseña incorrecta';
        }
      } else {
        _errorMessage = 'Usuario no encontrado';
      }
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
    return LoginResult(error: _errorMessage);
  }
}

class LoginResult {
  final bool success;
  final String? error;
  final bool shouldGoToCandidates;
  final bool shouldShowWinnerDialog;

  LoginResult({
    this.success = false,
    this.error,
    this.shouldGoToCandidates = true,
    this.shouldShowWinnerDialog = false,
  });
}