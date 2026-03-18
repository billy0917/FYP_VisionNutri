-- 啟用 pgvector 擴展（免費 Supabase 都支援）
CREATE EXTENSION IF NOT EXISTS vector;

-- 建立 CFS 食物數據表
CREATE TABLE cfs_foods (
  id          SERIAL PRIMARY KEY,
  food_id     TEXT UNIQUE,
  food_name_chi TEXT,
  food_name_eng TEXT,
  category_name_eng TEXT,
  serving_size TEXT,
  energy_kcal NUMERIC,
  protein_g   NUMERIC,
  carbohydrate_g NUMERIC,
  fat_g       NUMERIC,
  dietary_fibre_g NUMERIC,
  sugar_g     NUMERIC,
  sodium_mg   NUMERIC,
  embedding   vector(768)  -- text-embedding-004 是 768 維
);

-- 建立向量搜尋 RPC 函數
CREATE OR REPLACE FUNCTION match_cfs_food(
  query_embedding vector(768),
  match_count int DEFAULT 3,
  match_threshold float DEFAULT 0.6
)
RETURNS TABLE (
  food_id TEXT,
  food_name_chi TEXT,
  food_name_eng TEXT,
  category_name_eng TEXT,
  serving_size TEXT,
  energy_kcal NUMERIC,
  protein_g NUMERIC,
  carbohydrate_g NUMERIC,
  fat_g NUMERIC,
  dietary_fibre_g NUMERIC,
  sugar_g NUMERIC,
  sodium_mg NUMERIC,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.food_id, c.food_name_chi, c.food_name_eng,
    c.category_name_eng, c.serving_size,
    c.energy_kcal, c.protein_g, c.carbohydrate_g,
    c.fat_g, c.dietary_fibre_g, c.sugar_g, c.sodium_mg,
    1 - (c.embedding <=> query_embedding) AS similarity
  FROM cfs_foods c
  WHERE 1 - (c.embedding <=> query_embedding) > match_threshold
  ORDER BY c.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 建立向量索引提升搜尋速度
CREATE INDEX ON cfs_foods USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);