import 'package:supabase/supabase.dart';

SupabaseClient? _client;

SupabaseClient? getRealtimeSupabaseClient() {
  final url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '').trim();
  final anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '').trim();
  if (url.isEmpty || anonKey.isEmpty) {
    return null;
  }
  _client ??= SupabaseClient(url, anonKey);
  return _client;
}
