/// SmartDiet AI - Application Configuration
/// 
/// Contains app-wide configuration constants.
/// In production, use environment variables or a secure config solution.
library;

class AppConfig {
  // Prevent instantiation
  AppConfig._();
  
  // App info
  static const String appName = 'SmartDiet AI';
  static const String appVersion = '1.0.0';
  
  // Supabase configuration
  // TODO: Replace with your actual Supabase credentials
  static const String supabaseUrl = 'https://vaxmpwjuubmjavwppwnm.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZheG1wd2p1dWJtamF2d3Bwd25tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3NzkxNTAsImV4cCI6MjA4MTM1NTE1MH0.3UNbqFGeP3_gCpejk8XYbAMJHclzZTBb8gApTzuntwQ';
  
  // Vision AI - direct call from app (no local server needed)
  static const String visionApiUrl = 'https://api.apiplus.org/v1/chat/completions';
  static const String visionApiKey = 'sk-MHOUpYHg1MDV6LG1RjXdxmDoZ7t4ujGwsxzbBociNEw3xsob';
  static const String visionModel = 'gemini-3.1-pro-preview';
  
  // Storage bucket names
  static const String foodImagesBucket = 'food-images';
  static const String avatarsBucket = 'avatars';
  
  // Gamification settings
  static const int pointsPerMeal = 10;
  static const int pointsForProteinGoal = 25;
  static const int pointsForCalorieGoal = 25;
  static const int pointsPerStreakDay = 5;
  
  // Level thresholds
  static const List<int> levelThresholds = [
    0,      // Level 1
    100,    // Level 2
    250,    // Level 3
    500,    // Level 4
    1000,   // Level 5
    2000,   // Level 6
    3500,   // Level 7
    5500,   // Level 8
    8000,   // Level 9
    12000,  // Level 10
  ];
}
