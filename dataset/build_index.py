"""
CFS Food Nutrition RAG Indexer
=================================
One-time script to embed all CFS food records and upload to Supabase pgvector.

Uses OpenAI-compatible embedding API (works with third-party relays like apiplus.org).
The embedding model text-embedding-3-small outputs 768-dim vectors to match the
vector(768) column created in the Supabase SQL.

Usage:
    pip install openai supabase
    python build_index.py
"""

import json
import time
import os

from openai import OpenAI
from supabase import create_client

# ── Configuration ─────────────────────────────────────────────────────────────
API_KEY          = "sk-XSgyv0BxhhHwSGWmgTkJg7wj2fOMcXDgAN0MVW4z8yJEtpE0"
API_BASE_URL     = "https://api.apiplus.org/v1"

SUPABASE_URL     = "https://vaxmpwjuubmjavwppwnm.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZheG1wd2p1dWJtamF2d3Bwd25tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTc3OTE1MCwiZXhwIjoyMDgxMzU1MTUwfQ.HN3NfMbP6qJzAZPQsYJinvCNUL9DvYaoFDEAs2uSXtc"

# text-embedding-3-small supports custom output dimensions
# We request 768 to match the vector(768) column in Supabase
EMBED_MODEL      = "text-embedding-3-small"
EMBED_DIMENSIONS = 768

DATASET_PATH     = os.path.join(os.path.dirname(__file__), "cfs_food_nutrition.json")
BATCH_SIZE       = 20    # upsert to Supabase every N records
SLEEP_SECONDS    = 0.5   # seconds between batches (avoid rate limits)
MAX_CONSECUTIVE_ERRORS = 10  # stop if this many errors in a row (service down)
# ──────────────────────────────────────────────────────────────────────────────


def safe_float(val):
    """Convert CFS value (may be 'NA', 'ND', None) to float or None."""
    try:
        return float(val) if val not in (None, "NA", "ND", "") else None
    except (ValueError, TypeError):
        return None


def build_embed_text(food: dict) -> str:
    """
    Combine Chinese name + English name + category for richer embeddings.
    The more descriptive the text, the better the vector search accuracy.
    """
    parts = [
        food.get("food_name_eng", ""),
        food.get("food_name_chi", ""),
        food.get("category_name_eng", ""),
    ]
    return " ".join(p for p in parts if p and p != "NA").strip()


def main():
    print("Initialising OpenAI-compatible embedding client...")
    client = OpenAI(api_key=API_KEY, base_url=API_BASE_URL)

    print("Connecting to Supabase...")
    supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    print(f"Loading dataset from {DATASET_PATH} ...")
    with open(DATASET_PATH, encoding="utf-8") as f:
        foods = json.load(f)

    total = len(foods)
    print(f"Total food records: {total}")

    # ── Resume: fetch already-indexed food_ids to skip them ──────────────────
    print("Checking already-indexed records (for resume)...")
    done_ids = set()
    page = 0
    while True:
        rows = supabase.table("cfs_foods") \
            .select("food_id") \
            .range(page * 1000, (page + 1) * 1000 - 1) \
            .execute()
        batch = rows.data
        if not batch:
            break
        done_ids.update(r["food_id"] for r in batch if r.get("food_id"))
        if len(batch) < 1000:
            break
        page += 1
    print(f"Already indexed: {len(done_ids)} records — will skip these.\n")
    print("Starting indexing...\n")
    # ─────────────────────────────────────────────────────────────────────────

    success_count = 0
    error_count   = 0
    consecutive_errors = 0

    for i, food in enumerate(foods):
        food_id = food.get("food_id")

        # Skip already indexed
        if food_id in done_ids:
            continue

        embed_text = build_embed_text(food)
        if not embed_text:
            print(f"  [{i+1}/{total}] SKIP  — no text for food_id={food_id}")
            continue

        try:
            # Step 1: Get embedding via OpenAI-compatible API
            resp = client.embeddings.create(
                model=EMBED_MODEL,
                input=embed_text,
                dimensions=EMBED_DIMENSIONS,
            )
            embedding = resp.data[0].embedding  # list of 768 floats

            # Step 2: Upsert to Supabase
            row = {
                "food_id":          food_id,
                "food_name_chi":    food.get("food_name_chi"),
                "food_name_eng":    food.get("food_name_eng"),
                "category_name_eng": food.get("category_name_eng"),
                "serving_size":     food.get("serving_size"),
                "energy_kcal":      safe_float(food.get("energy_kcal")),
                "protein_g":        safe_float(food.get("protein_g")),
                "carbohydrate_g":   safe_float(food.get("carbohydrate_g")),
                "fat_g":            safe_float(food.get("fat_g")),
                "dietary_fibre_g":  safe_float(food.get("dietary_fibre_g")),
                "sugar_g":          safe_float(food.get("sugar_g")),
                "sodium_mg":        safe_float(food.get("sodium_mg")),
                "embedding":        embedding,
            }
            supabase.table("cfs_foods").upsert(row, on_conflict="food_id").execute()
            success_count += 1
            consecutive_errors = 0  # reset on success

            if (i + 1) % 50 == 0:
                print(f"  Progress: {i+1}/{total}  ✓ ok={success_count}  ✗ err={error_count}")

        except Exception as e:
            error_count += 1
            consecutive_errors += 1
            print(f"  [{i+1}/{total}] ERROR  {food.get('food_name_eng')} — {e}")

            if consecutive_errors >= MAX_CONSECUTIVE_ERRORS:
                print(f"\n⚠️  {MAX_CONSECUTIVE_ERRORS} consecutive errors — API service appears to be down.")
                print(f"   Re-run this script later to resume from where it stopped.")
                print(f"   Already indexed: {len(done_ids) + success_count} records total.")
                break

            wait = min(5 * consecutive_errors, 60)  # exponential backoff, max 60s
            print(f"   Waiting {wait}s before retrying...")
            time.sleep(wait)
            continue

        # Throttle to avoid Gemini free-tier rate limit (1500 req/min)
        if (i + 1) % BATCH_SIZE == 0:
            time.sleep(SLEEP_SECONDS)

    print(f"\nDone!  ✓ {success_count} inserted/updated  ✗ {error_count} errors")


if __name__ == "__main__":
    main()
