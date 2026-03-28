# Benchmark Feature

比較三種食物尺寸與營養估算方法的準確度，支援食物與非食物物件兩種模式。

---

## 目的

SmartDiet AI 的核心流程依賴 Gemini 視覺模型估算食物的 3D 尺寸以推算體積與熱量。此功能讓你拍攝真實物件、輸入人工量測的 ground truth，然後讓三種方法各自估算，最後以 MAE / MAPE 量化比較精度。

---

## 三種估算方法

| 方法 | 名稱 | 尺寸來源 | 營養資料來源 |
|------|------|----------|-------------|
| **A** | Pure Gemini + RAG | Gemini 視覺模型（僅圖片） | CFS RAG 資料庫 |
| **B** | Gemini + EXIF + RAG | Gemini 視覺模型（圖片 + 相機 EXIF 參數） | CFS RAG 資料庫 |
| **C** | ARCore + Gemini + RAG | ARCore 深度測量（on-device） | CFS RAG 資料庫 |

> 非食物物件模式下，三種方法均不使用 RAG，只估算 W×L×H，不產生營養數據。Method C 直接採用 ARCore 量測值，Gemini 僅提供推理說明。

---

## 進入方式

```
App → 右上角選單 ⋮ → Settings → Benchmark Test
```

---

## 使用流程

### 1. 建立測試項目
在 Benchmark List 畫面按右下角 **＋** 按鈕。

### 2. 拍攝照片
- 按「Pick / Capture Image」從相簿選圖或即時拍攝。
- 系統自動提取 EXIF（焦距、等效焦距、光圈、ISO）供 Method B / C 使用。

### 3. 量測 AR 尺寸（選填，Method C 必填）
- 按「Start AR Measurement」進入 ARCore 測量畫面。
- 完成後自動回填 W / L / H / Volume。

### 4. 輸入 Ground Truth
切換 **Food / Object** 模式：

| 欄位 | Food | Object |
|------|------|--------|
| 名稱 | ✓ 必填 | ✓ 必填 |
| W × L × H (cm) | ✓ 必填 | ✓ 必填 |
| 重量 (g) | 選填 | — |
| 熱量 / 蛋白質 / 碳水 / 脂肪 | 選填 | — |

按「Save Ground Truth」儲存。

### 5. 執行估算
按「▶ Run All Methods」，系統依序執行 A → B → C，每步顯示進度。完成後直接顯示比較表。

---

## 比較表（Detail Screen）

方法執行完畢後在同一畫面顯示：

```
Metric        GT     A      B      C
Width (cm)   12.0  11.2   11.8   12.1
Length (cm)   8.0   7.5    7.9    8.0
Height (cm)   5.0   4.8    5.1    5.0
[食物模式才顯示]
Calories     320   295    310    318
Protein (g)   12    10     11     12
Carbs (g)     45    40     43     44
Fat (g)        8     7      8      8
```

每個方法欄下方有可展開的「Reasoning」說明 Gemini 的推理過程。

---

## 圖表畫面（Charts Screen）

在 Benchmark List 選擇 **Charts**（需至少 2 個已完成項目），進入三個分頁：

### Dimensions 分頁
- Width / Length / Height 各一張分組長條圖（GT / A / B / C 四色）
- MAE 與 MAPE 彙整表

### Nutrition 分頁（僅食物項目）
- Calories / Protein / Carbs / Fat 各一張分組長條圖
- 若無食物項目顯示提示訊息

### Summary 分頁
- 各方法「勝出次數」卡片（勝出 = 該 metric 的 MAE 最低）
- **Dimension MAE（所有項目）** 彙整表
- **Nutrition MAE（僅食物項目）** 彙整表（有食物項目時才顯示）

---

## CSV 匯出

在 Benchmark List 按 **Export CSV**，透過系統分享視窗儲存或傳送檔案。

欄位格式：

```
id, food_name, is_food,
gt_width_cm, gt_length_cm, gt_height_cm, gt_weight_g, gt_cal, gt_protein, gt_carbs, gt_fat,
a_width_cm,  a_length_cm,  a_height_cm,  a_weight_g,  a_cal,  a_protein,  a_carbs,  a_fat,
b_width_cm,  b_length_cm,  b_height_cm,  b_weight_g,  b_cal,  b_protein,  b_carbs,  b_fat,
c_width_cm,  c_length_cm,  c_height_cm,  c_weight_g,  c_cal,  c_protein,  c_carbs,  c_fat
```

空白欄位代表該方法尚未執行或該欄位不適用（如物件的營養欄）。

---

## 非食物物件測試

測試非食物物件（例如：滑鼠、水瓶、紙盒）可獨立驗證**尺寸估算精度**，不受食物識別或 RAG 資料庫干擾。

建議用法：
1. 選擇形狀規則、尺寸容易量測的物件
2. 用尺實際量測 W × L × H，輸入為 ground truth
3. 比較 A（純視覺）、B（視覺 + EXIF）、C（ARCore）三者誤差
4. 結果可作為 ARCore 深度測量精度的獨立基準

列表頁以 📦 Object / 🍽️ Food 圖示區分。

---

## 資料儲存

測試項目以 JSON 個別檔案儲存於：

```
{AppDocumentsDir}/benchmark/{id}.json
```

長按列表項目可刪除。資料不會上傳至伺服器。

---

## 相關檔案

| 檔案 | 說明 |
|------|------|
| `lib/features/benchmark/benchmark_models.dart` | `BenchmarkItem`、`GroundTruth`、`EstimationResult`、`ArMeasurementData` |
| `lib/features/benchmark/benchmark_service.dart` | JSON 儲存、三種方法執行、CSV 匯出 |
| `lib/features/benchmark/screens/benchmark_list_screen.dart` | 項目列表 UI |
| `lib/features/benchmark/screens/benchmark_detail_screen.dart` | 拍照、AR、GT 輸入、執行與比較表 |
| `lib/features/benchmark/screens/benchmark_charts_screen.dart` | fl_chart 分組長條圖與 MAE 表 |
| `lib/features/settings/screens/settings_screen.dart` | 設定頁入口 |
| `lib/core/services/api_client.dart` | `analyzeFoodForBenchmark()`、`estimateDimensionsOnly()` |
