# CFS Food Nutrition Dataset — Supabase Schema

**Source**: Hong Kong Centre for Food Safety (香港食物安全中心, CFS)  
**Total records**: ~6,811  
**Supabase table**: `cfs_foods`  
**SQL setup file**: `supabase/CFS_pgvertor.sql`  
**Indexing script**: `dataset/build_index.py`

---

## Table Schema

| Column            | Type          | Notes                                              |
|-------------------|---------------|----------------------------------------------------|
| `id`              | SERIAL PK     | Auto-increment primary key                         |
| `food_id`         | TEXT UNIQUE   | Original CFS food ID (e.g. `"06170014009"`)        |
| `food_name_chi`   | TEXT          | Chinese food name (e.g. `"白飯"`)                  |
| `food_name_eng`   | TEXT          | English food name (e.g. `"Rice, white, cooked"`)   |
| `category_name_eng` | TEXT        | Food category (e.g. `"Cereals & grains"`)          |
| `serving_size`    | TEXT          | Always `"100克"` — all nutrition values are per 100g |
| `energy_kcal`     | NUMERIC       | Energy in kcal per 100g                            |
| `protein_g`       | NUMERIC       | Protein in grams per 100g                          |
| `carbohydrate_g`  | NUMERIC       | Carbohydrates in grams per 100g                    |
| `fat_g`           | NUMERIC       | Fat in grams per 100g                              |
| `dietary_fibre_g` | NUMERIC       | Dietary fibre in grams per 100g (may be NULL)      |
| `sugar_g`         | NUMERIC       | Sugar in grams per 100g (may be NULL)              |
| `sodium_mg`       | NUMERIC       | Sodium in mg per 100g (may be NULL)                |
| `embedding`       | `vector(768)` | Semantic embedding via `text-embedding-3-small`    |

> **NULL values**: CFS raw data uses `"NA"` / `"ND"` for missing values — these are stored as `NULL` in Supabase.

---

## Embedding Details

| Property      | Value                                              |
|---------------|----------------------------------------------------|
| Model         | `text-embedding-3-small` (via OpenAI-compatible API) |
| Dimensions    | 768                                                |
| API endpoint  | `https://api.apiplus.org/v1/embeddings`            |
| Input text    | `{food_name_eng} {food_name_chi} {category_name_eng}` |

---

## Vector Search RPC (`match_cfs_food`)

Function defined in `supabase/CFS_pgvertor.sql`:

```sql
SELECT * FROM match_cfs_food(
  query_embedding := '[0.01, -0.02, ...]'::vector(768),
  match_count     := 3,       -- number of results to return
  match_threshold := 0.6      -- minimum cosine similarity (0.0–1.0)
);
```

**Returns** same columns as `cfs_foods` plus `similarity` (float, cosine similarity).

---

## RAG Pipeline in App

```
Photo
 │
 ▼
[Step 1] Gemini Vision (gemini-3.1-flash-lite-preview)
         → identifies food name: "White Rice"
 │
 ▼
[Step 2] text-embedding-3-small
         → embeds "White Rice" → vector[768]
         → Supabase match_cfs_food RPC
         → returns top-3 CFS matches with similarity scores
 │
 ▼
[Step 3] Gemini Vision (gemini-3.1-flash-lite-preview) + CFS context
         → estimates portion weight from image
         → calculates total nutrition from CFS per-100g data
         → returns final result tagged "cfs_official" or "ai_estimate"
 │
 ▼
App displays nutrition + source badge (食安中心官方數據 / AI Estimate)
```

**Data source tags**:
- `cfs_official` — matched CFS record with similarity ≥ 0.6; nutrients calculated from official data
- `ai_estimate`  — no CFS match found; pure AI estimation

---

## Raw JSON Sample (from `cfs_food_nutrition.json`)

```json
{
  "food_id": "06170014009",
  "food_name_chi": "代基里酒(罐裝)",
  "food_name_eng": "Alcoholic beverage, daiquiri, canned",
  "category_id": "17",
  "category_name_chi": "酒精飲料",
  "category_name_eng": "Alcoholic beverages",
  "data_source": "A",
  "alias": "NA",
  "serving_size": "100克",
  "energy_kcal": "125",
  "protein_g": "0.00",
  "carbohydrate_g": "15.70",
  "fat_g": "NA",
  "dietary_fibre_g": "0.0",
  "sugar_g": "NA",
  "sodium_mg": "40",
  "calcium_mg": "0",
  "vitamin_c_mg": "1.3"
}
```

> Note: `category_id`, `data_source`, `alias`, `calcium_mg`, `vitamin_c_mg` and other micronutrients are in the raw JSON but **not stored** in Supabase (only macronutrients needed for the app are stored).
