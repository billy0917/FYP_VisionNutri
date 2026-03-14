-- 修復註冊觸發器
-- 在 Supabase SQL Editor 中執行此腳本

-- 1. 先刪除現有的觸發器和函數
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- 2. 重新建立簡化版的函數（只建立 profile，不建立 gamification_stats）
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 只建立 profile
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;  -- 避免重複插入
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- 記錄錯誤但不中斷註冊流程
        RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
        RETURN NEW;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- 3. 重新建立觸發器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 4. 測試：查看觸發器是否正確安裝
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgfoid::regproc as function_name,
    tgenabled as enabled
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';
