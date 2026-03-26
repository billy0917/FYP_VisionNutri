"""
RAG vs Baseline Nutrition Estimation Benchmark
================================================
Compares two methods for food nutrition estimation:

  Method A (Baseline): Gemini flash-lite directly estimates nutrition per 100g
  Method B (RAG):      Chinese text search → CFS match → Gemini with CFS context

Ground truth comes from the CFS (Centre for Food Safety) database itself.
We randomly sample foods, hide their nutrition, ask each method to estimate,
then calculate error metrics (MAE, MAPE, RMSE) for calories/protein/carbs/fat.

Usage:
    cd evaluation
    pip install openai supabase tabulate
    python rag_benchmark.py
"""

import json
import os
import re
import sys
import time
import random
import csv
from datetime import datetime
from math import sqrt

from openai import OpenAI
from supabase import create_client

# ── Configuration ─────────────────────────────────────────────────────────────
VISION_API_KEY   = "sk-MHOUpYHg1MDV6LG1RjXdxmDoZ7t4ujGwsxzbBociNEw3xsob"
VISION_API_BASE  = "https://api.apiplus.org/v1"
VISION_MODEL     = "gemini-3.1-flash-lite-preview"

EMBED_API_KEY    = "sk-XSgyv0BxhhHwSGWmgTkJg7wj2fOMcXDgAN0MVW4z8yJEtpE0"
EMBED_API_BASE   = "https://api.apiplus.org/v1"
EMBED_MODEL      = "text-embedding-3-small"
EMBED_DIMENSIONS = 768

SUPABASE_URL     = "https://vaxmpwjuubmjavwppwnm.supabase.co"
SUPABASE_KEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZheG1wd2p1dWJtamF2d3Bwd25tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTc3OTE1MCwiZXhwIjoyMDgxMzU1MTUwfQ.HN3NfMbP6qJzAZPQsYJinvCNUL9DvYaoFDEAs2uSXtc"

DATASET_PATH     = os.path.join(os.path.dirname(__file__), "..", "dataset", "cfs_food_nutrition.json")

# Number of foods to test per category
SAMPLE_PER_CATEGORY = 5

# Categories to include (common real foods, exclude beverages/baby foods/etc.)
TARGET_CATEGORIES = [
    "Ready-to-eat foods",
    "Cereals and cereal products",
    "Meat and meat products",
    "Fish and fish products",
    "Poultry and poultry products",
    "Eggs and egg products",
    "Vegetables and vegetable products",
    "Legumes and legume products",
    "Fruits and fruit products",
    "Snacks",
]

SLEEP_BETWEEN_CALLS = 1.0  # seconds, avoid rate limits
# ──────────────────────────────────────────────────────────────────────────────


def safe_float(val):
    try:
        return float(val) if val not in (None, "NA", "ND", "") else None
    except (ValueError, TypeError):
        return None


def load_test_foods():
    """Load CFS dataset, filter valid foods, and sample from each category."""
    with open(DATASET_PATH, encoding="utf-8") as f:
        all_foods = json.load(f)

    # Only keep foods with all four macros available
    valid = []
    for food in all_foods:
        energy = safe_float(food.get("energy_kcal"))
        protein = safe_float(food.get("protein_g"))
        carbs = safe_float(food.get("carbohydrate_g"))
        fat = safe_float(food.get("fat_g"))
        cat = food.get("category_name_eng", "")
        chi = food.get("food_name_chi", "")
        eng = food.get("food_name_eng", "")

        if (energy is not None and protein is not None
                and carbs is not None and fat is not None
                and cat in TARGET_CATEGORIES
                and chi and chi != "NA"
                and eng and eng != "NA"):
            valid.append(food)

    # Group by category and sample
    by_cat = {}
    for food in valid:
        cat = food["category_name_eng"]
        by_cat.setdefault(cat, []).append(food)

    sampled = []
    for cat in TARGET_CATEGORIES:
        pool = by_cat.get(cat, [])
        n = min(SAMPLE_PER_CATEGORY, len(pool))
        sampled.extend(random.sample(pool, n))

    print(f"Selected {len(sampled)} test foods from {len(TARGET_CATEGORIES)} categories")
    return sampled


def parse_json_response(text):
    """Extract JSON from model response, handling markdown fences."""
    text = text.strip()
    if "```" in text:
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end != -1:
            text = text[start:end + 1]

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # Regex fallback
        result = {}
        for key in ["calories", "protein", "carbs", "fat"]:
            m = re.search(rf'"{key}"\s*:\s*(\d+(?:\.\d+)?)', text)
            if m:
                result[key] = float(m.group(1))
        return result if result else None


def method_a_baseline(client, food_name_chi, food_name_eng):
    """
    Method A: Direct AI estimation (no RAG).
    Ask the model to estimate nutrition per 100g using only its training data.
    """
    prompt = (
        f'You are an expert nutritionist. '
        f'Estimate the nutrition per 100g for this food: "{food_name_eng}" (Chinese: {food_name_chi}). '
        f'Respond ONLY with valid JSON, no markdown, no extra text:\n'
        f'{{"calories": integer, "protein": integer, "carbs": integer, "fat": integer}}'
    )

    try:
        resp = client.chat.completions.create(
            model=VISION_MODEL,
            max_tokens=200,
            temperature=0.3,
            messages=[{"role": "user", "content": prompt}],
        )
        content = resp.choices[0].message.content
        result = parse_json_response(content)
        if result:
            return {
                "calories": result.get("calories", 0),
                "protein": result.get("protein", 0),
                "carbs": result.get("carbs", 0),
                "fat": result.get("fat", 0),
                "raw": content,
            }
    except Exception as e:
        print(f"    [Baseline ERROR] {e}")
    return None


def method_b_rag(vision_client, embed_client, supabase, food_name_chi, food_name_eng):
    """
    Method B: RAG-enhanced estimation.
    Step 1: Text search CFS database by Chinese name
    Step 2: If no text match, vector search by English name
    Step 3: Feed CFS context to model for estimation
    """
    # ── Step 1: Text search by Chinese name ──
    cfs_matches = []
    search_method = "none"
    try:
        text_hits = (
            supabase.table("cfs_foods")
            .select("food_id, food_name_chi, food_name_eng, energy_kcal, protein_g, carbohydrate_g, fat_g")
            .ilike("food_name_chi", f"%{food_name_chi}%")
            .limit(3)
            .execute()
        )
        if text_hits.data:
            cfs_matches = text_hits.data
            search_method = "text"
    except Exception:
        pass

    # ── Step 2: Vector search fallback ──
    if not cfs_matches:
        try:
            embed_resp = embed_client.embeddings.create(
                model=EMBED_MODEL,
                input=food_name_eng,
                dimensions=EMBED_DIMENSIONS,
            )
            embedding = embed_resp.data[0].embedding
            rpc_resp = supabase.rpc("match_cfs_food", {
                "query_embedding": embedding,
                "match_count": 3,
                "match_threshold": 0.45,
            }).execute()
            if rpc_resp.data:
                cfs_matches = rpc_resp.data
                search_method = "vector"
        except Exception:
            pass

    # ── Step 3: Generate with CFS context ──
    if cfs_matches:
        cfs_context_lines = []
        for m in cfs_matches:
            name = f"{m.get('food_name_eng', '')} ({m.get('food_name_chi', '')})"
            fat_val = safe_float(m.get("fat_g"))
            fat_str = f"{fat_val}g" if fat_val is not None else "not recorded"
            per100 = (
                f"Per 100g: {m.get('energy_kcal')}kcal, "
                f"protein {m.get('protein_g')}g, carbs {m.get('carbohydrate_g')}g, fat {fat_str}"
            )
            cfs_context_lines.append(f"{name}\n{per100}")
        cfs_context = "\n\n".join(cfs_context_lines)

        system_prompt = (
            f'You are a precise nutritionist. '
            f'Below is official nutrition data from the Hong Kong Centre for Food Safety (CFS) — '
            f'all values are PER 100g. Using this data, estimate the nutrition for '
            f'"{food_name_eng}" ({food_name_chi}) per 100g. '
            f'If a nutrient is "not recorded", estimate it from your knowledge. '
            f'Respond ONLY with valid JSON:\n'
            f'{{"calories": integer, "protein": integer, "carbs": integer, "fat": integer}}'
        )
        user_text = f"CFS official data (per 100g):\n{cfs_context}"
    else:
        # No CFS match — fallback to pure estimation (same as baseline)
        system_prompt = (
            f'You are an expert nutritionist. '
            f'Estimate the nutrition per 100g for: "{food_name_eng}" ({food_name_chi}). '
            f'Respond ONLY with valid JSON:\n'
            f'{{"calories": integer, "protein": integer, "carbs": integer, "fat": integer}}'
        )
        user_text = "Estimate nutrition per 100g."

    try:
        resp = vision_client.chat.completions.create(
            model=VISION_MODEL,
            max_tokens=200,
            temperature=0.3,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_text},
            ],
        )
        content = resp.choices[0].message.content
        result = parse_json_response(content)
        if result:
            return {
                "calories": result.get("calories", 0),
                "protein": result.get("protein", 0),
                "carbs": result.get("carbs", 0),
                "fat": result.get("fat", 0),
                "raw": content,
                "search_method": search_method,
                "cfs_match_count": len(cfs_matches),
            }
    except Exception as e:
        print(f"    [RAG ERROR] {e}")
    return None


def compute_metrics(errors):
    """Compute MAE, MAPE, RMSE from list of (predicted, actual) tuples."""
    if not errors:
        return {"mae": 0, "mape": 0, "rmse": 0}

    abs_errors = [abs(p - a) for p, a in errors]
    pct_errors = [abs(p - a) / a * 100 for p, a in errors if a > 0]
    sq_errors = [(p - a) ** 2 for p, a in errors]

    mae = sum(abs_errors) / len(abs_errors)
    mape = sum(pct_errors) / len(pct_errors) if pct_errors else 0
    rmse = sqrt(sum(sq_errors) / len(sq_errors))
    return {"mae": round(mae, 2), "mape": round(mape, 2), "rmse": round(rmse, 2)}


def main():
    print("=" * 70)
    print("RAG vs Baseline Nutrition Estimation Benchmark")
    print("=" * 70)

    # ── Init clients ──
    vision_client = OpenAI(api_key=VISION_API_KEY, base_url=VISION_API_BASE)
    embed_client = OpenAI(api_key=EMBED_API_KEY, base_url=EMBED_API_BASE)
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

    # ── Load test foods ──
    random.seed(42)  # reproducible sampling
    test_foods = load_test_foods()

    # ── Run benchmark ──
    results = []
    nutrients = ["calories", "protein", "carbs", "fat"]
    baseline_errors = {n: [] for n in nutrients}
    rag_errors = {n: [] for n in nutrients}

    total = len(test_foods)
    for i, food in enumerate(test_foods):
        chi = food["food_name_chi"]
        eng = food["food_name_eng"]
        cat = food["category_name_eng"]
        gt = {
            "calories": safe_float(food["energy_kcal"]),
            "protein": safe_float(food["protein_g"]),
            "carbs": safe_float(food["carbohydrate_g"]),
            "fat": safe_float(food["fat_g"]),
        }

        print(f"\n[{i+1}/{total}] {chi} | {eng} ({cat})")
        print(f"  Ground truth: cal={gt['calories']}, pro={gt['protein']}, carb={gt['carbs']}, fat={gt['fat']}")

        # ── Method A: Baseline ──
        print("  Running Baseline...", end=" ", flush=True)
        baseline = method_a_baseline(vision_client, chi, eng)
        time.sleep(SLEEP_BETWEEN_CALLS)

        if baseline:
            print(f"cal={baseline['calories']}, pro={baseline['protein']}, carb={baseline['carbs']}, fat={baseline['fat']}")
        else:
            print("FAILED")

        # ── Method B: RAG ──
        print("  Running RAG...", end=" ", flush=True)
        rag = method_b_rag(vision_client, embed_client, supabase, chi, eng)
        time.sleep(SLEEP_BETWEEN_CALLS)

        if rag:
            print(f"cal={rag['calories']}, pro={rag['protein']}, carb={rag['carbs']}, fat={rag['fat']} "
                  f"[search={rag.get('search_method','?')}, matches={rag.get('cfs_match_count',0)}]")
        else:
            print("FAILED")

        # ── Record results ──
        row = {
            "food_name_chi": chi,
            "food_name_eng": eng,
            "category": cat,
        }
        for n in nutrients:
            row[f"gt_{n}"] = gt[n]
            row[f"baseline_{n}"] = baseline[n] if baseline else None
            row[f"rag_{n}"] = rag[n] if rag else None

            if baseline and gt[n] is not None:
                baseline_errors[n].append((baseline[n], gt[n]))
            if rag and gt[n] is not None:
                rag_errors[n].append((rag[n], gt[n]))

        row["rag_search_method"] = rag.get("search_method", "none") if rag else "failed"
        row["rag_cfs_matches"] = rag.get("cfs_match_count", 0) if rag else 0
        results.append(row)

    # ── Compute metrics ──
    print("\n" + "=" * 70)
    print("RESULTS SUMMARY")
    print("=" * 70)

    header = f"{'Nutrient':<12} {'Method':<10} {'MAE':>8} {'MAPE%':>8} {'RMSE':>8}"
    print(header)
    print("-" * len(header))

    summary_rows = []
    for n in nutrients:
        bm = compute_metrics(baseline_errors[n])
        rm = compute_metrics(rag_errors[n])
        improvement_mae = ((bm["mae"] - rm["mae"]) / bm["mae"] * 100) if bm["mae"] > 0 else 0
        improvement_mape = ((bm["mape"] - rm["mape"]) / bm["mape"] * 100) if bm["mape"] > 0 else 0

        print(f"{n:<12} {'Baseline':<10} {bm['mae']:>8.2f} {bm['mape']:>7.1f}% {bm['rmse']:>8.2f}")
        print(f"{'':<12} {'RAG':<10} {rm['mae']:>8.2f} {rm['mape']:>7.1f}% {rm['rmse']:>8.2f}")
        print(f"{'':<12} {'Δ':>10} {improvement_mae:>+7.1f}% {improvement_mape:>+7.1f}%")
        print()

        summary_rows.append({
            "nutrient": n,
            "baseline_mae": bm["mae"], "baseline_mape": bm["mape"], "baseline_rmse": bm["rmse"],
            "rag_mae": rm["mae"], "rag_mape": rm["mape"], "rag_rmse": rm["rmse"],
            "improvement_mae_pct": round(improvement_mae, 1),
            "improvement_mape_pct": round(improvement_mape, 1),
        })

    # RAG search hit rate
    rag_text_hits = sum(1 for r in results if r.get("rag_search_method") == "text")
    rag_vector_hits = sum(1 for r in results if r.get("rag_search_method") == "vector")
    rag_no_hits = sum(1 for r in results if r.get("rag_search_method") in ("none", "failed"))
    print(f"RAG Search Statistics:")
    print(f"  Text match:   {rag_text_hits}/{total} ({rag_text_hits/total*100:.0f}%)")
    print(f"  Vector match: {rag_vector_hits}/{total} ({rag_vector_hits/total*100:.0f}%)")
    print(f"  No match:     {rag_no_hits}/{total} ({rag_no_hits/total*100:.0f}%)")

    # ── Save detailed CSV ──
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path = os.path.join(os.path.dirname(__file__), f"benchmark_results_{timestamp}.csv")
    with open(csv_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=results[0].keys())
        writer.writeheader()
        writer.writerows(results)
    print(f"\nDetailed results saved to: {csv_path}")

    # ── Save summary CSV ──
    summary_path = os.path.join(os.path.dirname(__file__), f"benchmark_summary_{timestamp}.csv")
    with open(summary_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=summary_rows[0].keys())
        writer.writeheader()
        writer.writerows(summary_rows)
    print(f"Summary saved to: {summary_path}")

    print(f"\nBenchmark complete. Tested {total} foods.")


if __name__ == "__main__":
    main()
