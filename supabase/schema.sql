-- SmartDiet AI Database Schema
-- Supabase/PostgreSQL Schema for personalized nutrition ecosystem

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- ENUM TYPES
-- =============================================

-- Goal type enum for user profiles
CREATE TYPE goal_type_enum AS ENUM ('hypertrophy', 'weight_loss', 'maintenance', 'general_health');

-- Meal type enum for food logs
CREATE TYPE meal_type_enum AS ENUM ('breakfast', 'lunch', 'dinner', 'snack');

-- Action type enum for point history (gamification)
CREATE TYPE action_type_enum AS ENUM (
    'logged_meal',
    'hit_protein_goal',
    'hit_calorie_goal',
    'daily_streak',
    'weekly_streak',
    'first_meal_of_day',
    'completed_profile',
    'shared_achievement',
    'recipe_completed',
    'chat_session'
);

-- Activity level enum for TDEE calculation
CREATE TYPE activity_level_enum AS ENUM (
    'sedentary',        -- Little or no exercise
    'lightly_active',   -- Light exercise 1-3 days/week
    'moderately_active', -- Moderate exercise 3-5 days/week
    'very_active',      -- Hard exercise 6-7 days/week
    'extra_active'      -- Very hard exercise & physical job
);

-- Gender enum for profile
CREATE TYPE gender_enum AS ENUM ('male', 'female', 'other', 'prefer_not_to_say');

-- =============================================
-- PROFILES TABLE
-- =============================================
-- Links to Supabase auth.users for authentication
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    
    -- Physical stats for TDEE calculation
    gender gender_enum,
    date_of_birth DATE,
    height_cm NUMERIC(5, 2),  -- Height in centimeters
    weight_kg NUMERIC(5, 2),  -- Weight in kilograms
    activity_level activity_level_enum DEFAULT 'moderately_active',
    
    -- Calculated/Target values
    tdee NUMERIC(7, 2),  -- Total Daily Energy Expenditure
    bmr NUMERIC(7, 2),   -- Basal Metabolic Rate
    goal_type goal_type_enum DEFAULT 'general_health',
    target_calories INTEGER,
    target_protein INTEGER,  -- in grams
    target_carbs INTEGER,    -- in grams
    target_fat INTEGER,      -- in grams
    
    -- Preferences
    dietary_restrictions JSONB DEFAULT '[]'::jsonb,  -- e.g., ["vegetarian", "gluten-free"]
    allergies JSONB DEFAULT '[]'::jsonb,             -- e.g., ["peanuts", "shellfish"]
    preferred_cuisines JSONB DEFAULT '[]'::jsonb,    -- e.g., ["asian", "mediterranean"]
    
    -- Onboarding status
    is_onboarding_complete BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- FOOD LOGS TABLE
-- =============================================
-- Main table for tracking food consumption
CREATE TABLE food_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Image data (stored locally on user device)
    local_image_path TEXT,  -- Path on user's device
    image_url TEXT,  -- Optional: External URL (if user uploads to other service)
    image_storage_path TEXT,  -- Legacy field, kept for backward compatibility
    
    -- Food identification
    food_name TEXT NOT NULL,
    food_description TEXT,
    
    -- Macronutrients
    calories INTEGER NOT NULL DEFAULT 0,
    protein NUMERIC(6, 2) DEFAULT 0,  -- in grams
    carbs NUMERIC(6, 2) DEFAULT 0,    -- in grams
    fat NUMERIC(6, 2) DEFAULT 0,      -- in grams
    fiber NUMERIC(6, 2) DEFAULT 0,    -- in grams
    sugar NUMERIC(6, 2) DEFAULT 0,    -- in grams
    sodium NUMERIC(7, 2) DEFAULT 0,   -- in milligrams
    
    -- Serving info
    serving_size NUMERIC(6, 2),
    serving_unit TEXT,  -- e.g., "grams", "cup", "piece"
    number_of_servings NUMERIC(4, 2) DEFAULT 1,
    
    -- Meal categorization
    meal_type meal_type_enum NOT NULL,
    
    -- AI analysis metadata
    ai_confidence_score NUMERIC(3, 2),  -- 0.00 to 1.00
    ai_reasoning TEXT,                   -- AI's explanation
    ai_model_used TEXT,                  -- e.g., "gpt-4o", "gemini-pro-vision"
    is_manually_edited BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    logged_at TIMESTAMPTZ DEFAULT NOW(),  -- When the food was eaten
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster queries by user and date
CREATE INDEX idx_food_logs_user_date ON food_logs(user_id, logged_at DESC);
CREATE INDEX idx_food_logs_meal_type ON food_logs(user_id, meal_type);

-- =============================================
-- DAILY STATS TABLE
-- =============================================
-- Aggregated daily statistics for quick lookups
CREATE TABLE daily_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    
    -- Aggregated macros
    total_calories INTEGER DEFAULT 0,
    total_protein NUMERIC(7, 2) DEFAULT 0,
    total_carbs NUMERIC(7, 2) DEFAULT 0,
    total_fat NUMERIC(7, 2) DEFAULT 0,
    total_fiber NUMERIC(6, 2) DEFAULT 0,
    
    -- Meal counts
    meals_logged INTEGER DEFAULT 0,
    
    -- Goal tracking
    target_calories INTEGER,
    target_protein INTEGER,
    is_calorie_target_met BOOLEAN DEFAULT FALSE,
    is_protein_target_met BOOLEAN DEFAULT FALSE,
    
    -- Percentage of goals achieved
    calorie_percentage NUMERIC(5, 2) DEFAULT 0,  -- e.g., 85.50%
    protein_percentage NUMERIC(5, 2) DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint for one entry per user per day
    UNIQUE(user_id, date)
);

-- Index for faster queries
CREATE INDEX idx_daily_stats_user_date ON daily_stats(user_id, date DESC);

-- =============================================
-- GAMIFICATION STATS TABLE
-- =============================================
-- User's overall gamification progress
CREATE TABLE gamification_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Streak tracking
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_activity_date DATE,
    
    -- Points and levels
    total_points INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    experience_points INTEGER DEFAULT 0,  -- XP within current level
    
    -- Achievement counters
    total_meals_logged INTEGER DEFAULT 0,
    total_days_logged INTEGER DEFAULT 0,
    protein_goals_hit INTEGER DEFAULT 0,
    calorie_goals_hit INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- POINT HISTORY TABLE
-- =============================================
-- Detailed log of how points were earned
CREATE TABLE point_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Action details
    action_type action_type_enum NOT NULL,
    action_description TEXT,
    points_earned INTEGER NOT NULL,
    
    -- Reference to related entity (optional)
    reference_id UUID,        -- e.g., food_log_id
    reference_type TEXT,      -- e.g., "food_log", "recipe"
    
    -- Multipliers applied (for streaks, bonuses, etc.)
    multiplier NUMERIC(3, 2) DEFAULT 1.00,
    base_points INTEGER,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for user history queries
CREATE INDEX idx_point_history_user ON point_history(user_id, created_at DESC);

-- =============================================
-- ACHIEVEMENTS TABLE
-- =============================================
-- Definition of available achievements
CREATE TABLE achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,  -- e.g., "first_meal", "streak_7"
    name TEXT NOT NULL,
    description TEXT,
    icon_url TEXT,
    
    -- Requirements
    requirement_type TEXT,      -- e.g., "streak", "meals_logged", "points"
    requirement_value INTEGER,  -- e.g., 7 for "streak_7"
    
    -- Rewards
    points_reward INTEGER DEFAULT 0,
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- USER ACHIEVEMENTS TABLE
-- =============================================
-- Tracks which achievements users have unlocked
CREATE TABLE user_achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    
    -- When achieved
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Prevent duplicate achievements
    UNIQUE(user_id, achievement_id)
);

-- Index for user achievements lookup
CREATE INDEX idx_user_achievements ON user_achievements(user_id);

-- =============================================
-- RECIPES TABLE
-- =============================================
-- Recipes for AI agent recommendations
CREATE TABLE recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    
    -- Recipe details (JSONB for flexibility)
    ingredients JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- Format: [{"name": "chicken breast", "amount": 200, "unit": "g"}, ...]
    
    macros JSONB NOT NULL DEFAULT '{}'::jsonb,
    -- Format: {"calories": 450, "protein": 40, "carbs": 30, "fat": 15}
    
    steps JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- Format: ["Step 1: ...", "Step 2: ...", ...]
    
    -- Nutritional info (denormalized for quick queries)
    total_calories INTEGER,
    total_protein NUMERIC(6, 2),
    total_carbs NUMERIC(6, 2),
    total_fat NUMERIC(6, 2),
    
    -- Recipe metadata
    servings INTEGER DEFAULT 1,
    prep_time_minutes INTEGER,
    cook_time_minutes INTEGER,
    difficulty_level TEXT,  -- "easy", "medium", "hard"
    
    -- Categorization
    cuisine_type TEXT,
    meal_types JSONB DEFAULT '[]'::jsonb,  -- ["breakfast", "lunch"]
    dietary_tags JSONB DEFAULT '[]'::jsonb,  -- ["high-protein", "low-carb", "vegetarian"]
    
    -- AI recommendation metadata
    is_ai_generated BOOLEAN DEFAULT FALSE,
    source TEXT,  -- "user", "ai", "admin"
    
    -- Status
    is_published BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for recipe search
CREATE INDEX idx_recipes_dietary_tags ON recipes USING GIN(dietary_tags);
CREATE INDEX idx_recipes_meal_types ON recipes USING GIN(meal_types);

-- =============================================
-- USER FAVORITE RECIPES TABLE
-- =============================================
CREATE TABLE user_favorite_recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, recipe_id)
);

-- =============================================
-- CHAT SESSIONS TABLE
-- =============================================
-- Track user chat sessions with AI nutritionist
CREATE TABLE chat_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Session metadata
    title TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- FastGPT conversation ID (if applicable)
    external_conversation_id TEXT,
    
    -- Timestamps
    started_at TIMESTAMPTZ DEFAULT NOW(),
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

-- Index for user sessions
CREATE INDEX idx_chat_sessions_user ON chat_sessions(user_id, started_at DESC);

-- =============================================
-- CHAT MESSAGES TABLE
-- =============================================
-- Individual messages in chat sessions
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Message content
    role TEXT NOT NULL,  -- "user" or "assistant"
    content TEXT NOT NULL,
    
    -- Metadata
    tokens_used INTEGER,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for message retrieval
CREATE INDEX idx_chat_messages_session ON chat_messages(session_id, created_at ASC);

-- =============================================
-- WEIGHT LOGS TABLE
-- =============================================
-- Track user weight over time
CREATE TABLE weight_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    weight_kg NUMERIC(5, 2) NOT NULL,
    notes TEXT,
    
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for weight history
CREATE INDEX idx_weight_logs_user ON weight_logs(user_id, logged_at DESC);

-- =============================================
-- FUNCTIONS AND TRIGGERS
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_food_logs_updated_at
    BEFORE UPDATE ON food_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_stats_updated_at
    BEFORE UPDATE ON daily_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_gamification_stats_updated_at
    BEFORE UPDATE ON gamification_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_recipes_updated_at
    BEFORE UPDATE ON recipes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email)
    VALUES (NEW.id, NEW.email);
    
    -- Also create gamification stats entry
    INSERT INTO gamification_stats (user_id)
    VALUES (NEW.id);
    
    RETURN NEW;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Trigger for new user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE gamification_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorite_recipes ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Food logs policies
CREATE POLICY "Users can view own food logs" ON food_logs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own food logs" ON food_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own food logs" ON food_logs
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own food logs" ON food_logs
    FOR DELETE USING (auth.uid() = user_id);

-- Daily stats policies
CREATE POLICY "Users can view own daily stats" ON daily_stats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own daily stats" ON daily_stats
    FOR ALL USING (auth.uid() = user_id);

-- Gamification stats policies
CREATE POLICY "Users can view own gamification stats" ON gamification_stats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own gamification stats" ON gamification_stats
    FOR UPDATE USING (auth.uid() = user_id);

-- Point history policies
CREATE POLICY "Users can view own point history" ON point_history
    FOR SELECT USING (auth.uid() = user_id);

-- User achievements policies
CREATE POLICY "Users can view own achievements" ON user_achievements
    FOR SELECT USING (auth.uid() = user_id);

-- Chat sessions policies
CREATE POLICY "Users can manage own chat sessions" ON chat_sessions
    FOR ALL USING (auth.uid() = user_id);

-- Chat messages policies
CREATE POLICY "Users can manage own chat messages" ON chat_messages
    FOR ALL USING (auth.uid() = user_id);

-- Weight logs policies
CREATE POLICY "Users can manage own weight logs" ON weight_logs
    FOR ALL USING (auth.uid() = user_id);

-- Favorite recipes policies
CREATE POLICY "Users can manage own favorite recipes" ON user_favorite_recipes
    FOR ALL USING (auth.uid() = user_id);

-- Recipes are publicly readable
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Recipes are viewable by everyone" ON recipes
    FOR SELECT USING (is_published = TRUE);

-- Achievements are publicly readable
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Achievements are viewable by everyone" ON achievements
    FOR SELECT USING (is_active = TRUE);

-- =============================================
-- SEED DATA: Default Achievements
-- =============================================

INSERT INTO achievements (code, name, description, requirement_type, requirement_value, points_reward) VALUES
('first_meal', 'First Bite', 'Log your first meal', 'meals_logged', 1, 50),
('meals_10', 'Getting Started', 'Log 10 meals', 'meals_logged', 10, 100),
('meals_50', 'Consistent Logger', 'Log 50 meals', 'meals_logged', 50, 250),
('meals_100', 'Meal Master', 'Log 100 meals', 'meals_logged', 100, 500),
('streak_3', 'Three Day Streak', 'Log meals for 3 consecutive days', 'streak', 3, 75),
('streak_7', 'Week Warrior', 'Log meals for 7 consecutive days', 'streak', 7, 150),
('streak_14', 'Two Week Champion', 'Log meals for 14 consecutive days', 'streak', 14, 300),
('streak_30', 'Monthly Master', 'Log meals for 30 consecutive days', 'streak', 30, 750),
('protein_hit_7', 'Protein Pro', 'Hit your protein goal 7 times', 'protein_goals_hit', 7, 200),
('calorie_hit_7', 'Calorie Counter', 'Hit your calorie goal 7 times', 'calorie_goals_hit', 7, 200);
