import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // CREDENCIAIS DIRETAS - funcionam no Flutter Web
  static const String supabaseUrl = 'https://ctwhqrdqilzqcwmzzjlp.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0d2hxcmRxaWx6cWN3bXp6amxwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4MjMxOTMsImV4cCI6MjA3NzM5OTE5M30.eWPj0ve1x2SeRQ7JW58u43G5K2rKQCWNyom4A_tKZxc';

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      print('✅ Supabase inicializado com sucesso!');
    } catch (e) {
      print('❌ Erro ao inicializar Supabase: $e');
      rethrow;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}