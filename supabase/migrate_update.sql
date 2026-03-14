-- =============================================
-- SmartDiet AI — Safe Migration Script
-- 安全地補上缺少的欄位，不影響現有數據
-- 在 Supabase SQL Editor 執行此腳本
-- =============================================

-- =============================================
-- 1. food_logs — 補上缺少的欄位
-- =============================================

ALTER TABLE food_logs
    ADD COLUMN IF NOT EXISTS local_image_path TEXT,
    ADD COLUMN IF NOT EXISTS image_url TEXT,
    ADD COLUMN IF NOT EXISTS image_storage_path TEXT,
    ADD COLUMN IF NOT EXISTS food_description TEXT,
    ADD COLUMN IF NOT EXISTS fiber NUMERIC(6, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS sugar NUMERIC(6, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS sodium NUMERIC(7, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS serving_size NUMERIC(6, 2),
    ADD COLUMN IF NOT EXISTS serving_unit TEXT,
    ADD COLUMN IF NOT EXISTS number_of_servings NUMERIC(4, 2) DEFAULT 1,
    ADD COLUMN IF NOT EXISTS ai_confidence_score NUMERIC(3, 2),
    ADD COLUMN IF NOT EXISTS ai_reasoning TEXT,
    ADD COLUMN IF NOT EXISTS ai_model_used TEXT,
    ADD COLUMN IF NOT EXISTS is_manually_edited BOOLEAN DEFAULT FALSE;

-- =============================================
-- 2. profiles — 補上缺少的欄位
-- =============================================

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS gender gender_enum,
    ADD COLUMN IF NOT EXISTS date_of_birth DATE,
    ADD COLUMN IF NOT EXISTS height_cm NUMERIC(5, 2),
    ADD COLUMN IF NOT EXISTS weight_kg NUMERIC(5, 2),
    ADD COLUMN IF NOT EXISTS activity_level activity_level_enum DEFAULT 'moderately_active',
    ADD COLUMN IF NOT EXISTS tdee NUMERIC(7, 2),
    ADD COLUMN IF NOT EXISTS bmr NUMERIC(7, 2),
    ADD COLUMN IF NOT EXISTS goal_type goal_type_enum DEFAULT 'general_health',
    ADD COLUMN IF NOT EXISTS target_calories INTEGER,
    ADD COLUMN IF NOT EXISTS target_protein INTEGER,
    ADD COLUMN IF NOT EXISTS target_carbs INTEGER,
    ADD COLUMN IF NOT EXISTS target_fat INTEGER,
    ADD COLUMN IF NOT EXISTS dietary_restrictions JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS allergies JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS preferred_cuisines JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS is_onboarding_complete BOOLEAN DEFAULT FALSE;

-- =============================================
-- 3. gamification_stats — 補上缺少的欄位
-- =============================================

ALTER TABLE gamification_stats
    ADD COLUMN IF NOT EXISTS longest_streak INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_activity_date DATE,
    ADD COLUMN IF NOT EXISTS experience_points INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_meals_logged INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_days_logged INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS protein_goals_hit INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS calorie_goals_hit INTEGER DEFAULT 0;

-- =============================================
-- 4. 修復 handle_new_user trigger
--    原本的 trigger 在 gamification_stats insert 失敗時會中斷註冊
--    新版：只建立 profile，gamification_stats 用 ON CONFLICT 保護
-- =============================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 建立 profile（如已存在則略過）
    INSERT INTO profiles (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO NOTHING;

    -- 建立 gamification_stats（如已存在則略過）
    INSERT INTO gamification_stats (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- 即使發生錯誤也不中斷註冊流程
    RAISE WARNING 'handle_new_user error for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 重建 trigger（先刪除舊的）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================
-- 5. 為現有用戶補建 gamification_stats（如缺少）
-- =============================================

INSERT INTO gamification_stats (user_id)
SELECT id FROM profiles
WHERE id NOT IN (SELECT user_id FROM gamification_stats)
ON CONFLICT (user_id) DO NOTHING;

-- =============================================
-- 6. 確認索引存在
-- =============================================

CREATE INDEX IF NOT EXISTS idx_food_logs_user_date ON food_logs(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_food_logs_meal_type ON food_logs(user_id, meal_type);
CREATE INDEX IF NOT EXISTS idx_daily_stats_user_date ON daily_stats(user_id, date DESC);

-- =============================================
-- 7. 驗證結果
-- =============================================

SELECT 
    'food_logs columns' AS check_item,
    COUNT(*) AS count
FROM information_schema.columns
WHERE table_name = 'food_logs'
UNION ALL
SELECT 
    'profiles columns',
    COUNT(*)
FROM information_schema.columns
WHERE table_name = 'profiles'
UNION ALL
SELECT 
    'gamification_stats rows',
    COUNT(*)
FROM gamification_stats;
