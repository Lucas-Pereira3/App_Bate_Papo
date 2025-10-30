class EnvConfig {
  static late String supabaseUrl;
  static late String supabaseAnonKey;

  static Future<void> load() async {
    // Em produção, essas variáveis são injetadas no build
    supabaseUrl = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://ctwhqrdqilzqcwmzzjlp.supabase.co',
    );
    
    supabaseAnonKey = const String.fromEnvironment(
      'SUPABASE_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0d2hxcmRxaWx6cWN3bXp6amxwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4MjMxOTMsImV4cCI6MjA3NzM5OTE5M30.eWPj0ve1x2SeRQ7JW58u43G5K2rKQCWNyom4A_tKZxc',
    );
  }
}