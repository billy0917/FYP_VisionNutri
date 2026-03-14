/// SmartDiet AI - Supabase Service
/// 
/// Handles Supabase client initialization and authentication.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_diet_ai/core/config/app_config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  static User? get currentUser => client.auth.currentUser;
  
  static bool get isAuthenticated => currentUser != null;
  
  /// Initialize Supabase client.
  /// Call this in main() before runApp().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }
  
  /// Sign up with email and password.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }
  
  /// Sign in with email and password.
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  /// Sign out the current user.
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  /// Reset password via email.
  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }
  
  /// Listen to auth state changes.
  static Stream<AuthState> get authStateChanges => 
      client.auth.onAuthStateChange;
  
  /// Get user profile from profiles table.
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    
    return response;
  }
  
  /// Update user profile.
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    
    await client
        .from('profiles')
        .update(data)
        .eq('id', userId);
  }
  
  /// Upload file to Supabase Storage.
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> fileBytes,
    String? contentType,
  }) async {
    await client.storage.from(bucket).uploadBinary(
      path,
      fileBytes as dynamic,
      fileOptions: FileOptions(contentType: contentType),
    );
    
    return client.storage.from(bucket).getPublicUrl(path);
  }
}
