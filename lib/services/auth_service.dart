import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;
  User? _currentUser;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn(String email, String password) async {
    final res = await _client.auth.signInWithPassword(email: email, password: password);
    notifyListeners();
    return res;
  }

  Future<AuthResponse> signUp(String email, String password) async {
    final res = await _client.auth.signUp(email: email, password: password);
    notifyListeners();
    return res;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    notifyListeners();
  }
}