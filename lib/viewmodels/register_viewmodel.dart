import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterViewModel extends ChangeNotifier {
  final AuthService _authService;
  
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEmailValid = false;
  String _errorMessage = '';
  String _successMessage = '';
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  
  RegisterViewModel(this._authService);

  bool get isLoading => _isLoading;
  bool get isEmailValid => _isEmailValid;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  bool get passwordVisible => _passwordVisible;
  bool get confirmPasswordVisible => _confirmPasswordVisible;

  void togglePasswordVisibility() {
    _passwordVisible = !_passwordVisible;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _confirmPasswordVisible = !_confirmPasswordVisible;
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

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    
    if (!_authService.validateEmailForLogin(email)) {
      _errorMessage = 'Solo correos @continental.edu.pe pueden registrarse';
      notifyListeners();
      return;
    }

    if (!_authService.validatePassword(password)) {
      _errorMessage = 'La contraseña debe tener al menos 6 caracteres';
      notifyListeners();
      return;
    }

    if (password != confirmPassword) {
      _errorMessage = 'Las contraseñas no coinciden';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final userExists = await _authService.checkUserExists(email);
      
      if (userExists != null) {
        _errorMessage = 'El usuario ya está registrado';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      await _authService.register(email, password);
      
      _successMessage = 'Registro exitoso. Ahora puedes iniciar sesión.';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }
}