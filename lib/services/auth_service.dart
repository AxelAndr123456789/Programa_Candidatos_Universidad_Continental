import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AuthService {
  static const String _correctDomain = 'continental.edu.pe';
  static const String _fullCorrectEmail = '@$_correctDomain';

  bool validateEmailForLogin(String email) {
    if (email.isEmpty) return false;
    return email.endsWith(_fullCorrectEmail);
  }

  Color getEmailBorderColor(String email) {
    if (email.isEmpty) return Colors.grey.shade300;
    
    final atIndex = email.indexOf('@');
    
    if (atIndex == -1) {
      return const Color(0xFF0066CC);
    }
    
    final domain = email.substring(atIndex + 1);
    
    if (domain.isEmpty) {
      return const Color(0xFF0066CC);
    }
    
    if (_correctDomain.startsWith(domain)) {
      return Colors.green;
    }
    
    if (email.endsWith(_fullCorrectEmail)) {
      return Colors.green;
    }
    
    for (int i = 0; i < domain.length && i < _correctDomain.length; i++) {
      if (domain[i] != _correctDomain[i]) {
        return Colors.red;
      }
    }
    
    if (domain.length > _correctDomain.length) {
      return Colors.red;
    }
    
    return const Color(0xFF0066CC);
  }

  Widget? getEmailValidationIcon(String email) {
    if (email.isEmpty) return null;
    
    final atIndex = email.indexOf('@');
    
    if (atIndex == -1 || atIndex == email.length - 1) {
      return null;
    }
    
    final domain = email.substring(atIndex + 1);
    
    if (domain.isEmpty) return null;
    
    if (_correctDomain.startsWith(domain)) {
      return const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 20,
      );
    }
    
    if (email.endsWith(_fullCorrectEmail)) {
      return const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 20,
      );
    }
    
    if (domain.isNotEmpty) {
      if (domain.isNotEmpty && _correctDomain.isNotEmpty && 
          !_correctDomain.startsWith(domain[0])) {
        return const Icon(
          Icons.cancel,
          color: Colors.red,
          size: 20,
        );
      }
      
      for (int i = 0; i < domain.length && i < _correctDomain.length; i++) {
        if (domain[i] != _correctDomain[i]) {
          return const Icon(
            Icons.cancel,
            color: Colors.red,
            size: 20,
          );
        }
      }
      
      if (domain.length > _correctDomain.length) {
        return const Icon(
          Icons.cancel,
          color: Colors.red,
          size: 20,
        );
      }
    }
    
    return null;
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await supabase
          .from('usuarios')
          .select()
          .eq('correo', email)
          .maybeSingle();
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(String email, String password) async {
    try {
      await supabase.from('usuarios').insert({
        'correo': email,
        'password': password,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> checkUserExists(String email) async {
    try {
      return await supabase
          .from('usuarios')
          .select()
          .eq('correo', email)
          .maybeSingle();
    } catch (e) {
      rethrow;
    }
  }

  bool validatePassword(String password) {
    return password.length >= 6;
  }
}