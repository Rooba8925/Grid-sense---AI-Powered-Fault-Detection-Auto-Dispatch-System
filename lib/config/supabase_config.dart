import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // TODO: Replace with YOUR actual credentials
  static const String supabaseUrl = 'https://zjgorwwogcanatbacecm.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpqZ29yd3dvZ2NhbmF0YmFjZWNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2NjAxNTksImV4cCI6MjA4NTIzNjE1OX0.5ZwzxK-C9br8htwyLwSqD_aASJNbTZU1lmz--oPu4lg';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  // Easy access to Supabase client
  static SupabaseClient get client => Supabase.instance.client;
}