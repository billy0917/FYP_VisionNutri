# 食物體積估算 — Depth Anything V2 方案實驗紀錄

**日期**：2026-03-26  
**結論**：已棄用，改為 Gemini Vision 直接 prompt 推理

---

## 方案概述

使用 **Depth Anything V2 Small**（NeurIPS 2024，25M 參數）做單目深度估計，從一張照片推算食物體積，再把體積數字注入 Step 3 的 LLM prompt，輔助 Gemini 計算份量。

### 技術架構

```
手機拍照
  └─ base64 → FastAPI backend (PC)
                └─ Depth Anything V2
                     ├─ 生成 per-pixel disparity map
                     ├─ 邊緣像素 median → 桌面平面
                     ├─ 中心區高於桌面像素 → 食物遮罩
                     └─ height × pixel_area → 體積 (mL)
  └─ 體積字串注入 Step 3 prompt → Gemini 計算營養
```

### 涉及代碼

| 檔案 | 功能 |
|------|------|
| `backend/app/services/depth_service.py` | 深度估計 + 體積計算核心邏輯 |
| `backend/app/api/volume.py` | FastAPI `POST /api/v1/volume/estimate` |
| `backend/app/main.py` | FastAPI 入口，啟動時預載模型 |
| `lib/core/services/volume_service.dart` | Flutter 呼叫後端 API |
| `backend/requirements.txt` | 新增 torch (CPU)、transformers、numpy |

---

## 測試結果

**測試場景**：拍攝一罐 330 mL 可口可樂罐

**實際結果**：

```
Depth-AI volume estimation:
  volume_ml:       8511 mL   ← 正確應為 330 mL
  food_area_cm2:   1400 cm²
  avg_height_cm:   6.1 cm
  max_height_cm:   9.6 cm
  bounding_box:    41.7 × 46.7 cm
  confidence:      high
```

**誤差**：比實際值大 **25.8 倍**，完全不可用。

---

## 根本問題分析

### 1. 單目深度只有相對尺度，沒有絕對尺度

Depth Anything V2 輸出的是 **disparity map**（視差圖），表示「哪裡近、哪裡遠」的**相對關係**，並非真實的公制距離（公分/公尺）。

要把視差轉換成真實距離，需要已知條件之一：
- 雙目相機的基線距離（ToF/LiDAR/stereo）
- 已知大小的參考物體（已棄用的 Approach 1）
- 精確的相機內參標定（intrinsic calibration）

Vivo X100 主攝沒有 ToF/LiDAR 感應器，因此無法提供絕對深度。

### 2. 場景尺寸假設錯誤導致級數放大誤差

代碼中用了兩個硬編碼假設：

```python
_DEFAULT_DISTANCE_CM = 40.0   # 假設拍攝距離 40cm
_SCENE_DEPTH_RANGE_CM = 25.0  # 假設場景深度範圍 25cm
```

由 35mm 等效焦距（23mm）計算水平視場角：

```
FOV_h = 2 × arctan(36 / (2 × 23)) ≈ 84°
scene_width = 2 × 40cm × tan(42°) ≈ 72cm
cm_per_pixel = 72cm / 1024px ≈ 0.07 cm/px
```

但實際拍攝時手機距離可樂罐可能只有 20cm，畫面中可樂罐已佔據大半視野，實際場景寬度不足 20cm。假設值錯了 3–4 倍，面積誤差是 9–16 倍，體積誤差更高。

### 3. 架構問題：需要 PC Backend

模型大小 ~100MB，需要 PyTorch 運行環境，無法直接在手機上部署。每次分析都需要：
1. 手機把 base64 圖片傳到 PC
2. PC 跑推理（CPU 約 2–5 秒）
3. 結果返回手機

這違背了「手機獨立完成分析」的設計原則，且 ADB port forwarding 只在測試環境有效。

---

## 棄用決定

| 評估項目 | 結果 |
|----------|------|
| 估算準確度 | ❌ 25 倍誤差，不可用 |
| 手機獨立性 | ❌ 依賴 PC backend |
| 部署複雜度 | ❌ PyTorch + 100MB 模型 |
| 推理速度 | ⚠️ CPU ~3s/張 |
| 根本可行性 | ❌ 無絕對深度，理論上無法修正 |

---

## 改用方案：Gemini Vision 直接推理

棄用深度估計後，改為直接增強 Step 3 的 LLM prompt，讓 Gemini 利用視覺理解做物理推理：

```
STEP-BY-STEP:
1. MEASURE: 用透視關係、容器/盤子大小、常識估算 L×W×H (cm)
2. VOLUME: 計算體積 (mL)
3. WEIGHT: 乘以食物密度 (rice 1.1, soup 1.0, meat 1.05, ...)
4. NUTRITION: CFS per-100g × 克重
```

優點：
- 無需任何 backend，手機直接呼叫 Gemini API
- Gemini 的空間理解能力遠優於純數學假設
- reasoning 欄位可見推理過程（`dims ~LxWxH → ~V mL → ~Wg`）

相關代碼：`lib/core/services/api_client.dart` → `_analyzeWithContext()`

---

## 保留代碼

`backend/` 目錄的相關代碼（`depth_service.py`、`volume.py`、`main.py`）已**保留但不再被 Flutter App 呼叫**，作為實驗備份。`volume_service.dart` 同樣保留但未被使用。

如需重啟此方案，必須解決絕對深度問題（例如加入 ARCore Depth API 或已知尺寸參考物）。
