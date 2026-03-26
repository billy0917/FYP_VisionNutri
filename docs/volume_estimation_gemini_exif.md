# 食物份量估算 — Gemini Vision + 真實 EXIF 方案

**日期**：2026-03-27  
**狀態**：現行方案（已上線）

---

## 核心思路

不依賴任何額外模型或後端，直接在拍照時提取 JPEG 的 EXIF 相機元數據，傳給 Gemini Vision，讓它用真實鏡頭參數輔助判斷食物的物理尺寸，再推算體積和重量。

---

## 技術架構

```
用戶拍照
  └─ image_picker 拍照/選圖
       └─ readExifFromBytes()  ← exif: ^3.3.0 套件
            │
            │  提取以下欄位（有則用，無則略）：
            │  • FocalLength          實際焦距 (mm)
            │  • FocalLengthIn35mmFilm  35mm 等效焦距
            │  • FNumber              光圈值
            │  • ISOSpeedRatings      ISO
            │  • ExifImageWidth/Length 原始解析度
            │  • Image Make/Model     相機型號
            │  • SubjectDistance      對焦距離 (米，罕見)
            │
            └─ 拼成一行：
               "focal length 6.73mm, 35mm equiv 23mm, f/1.75,
                ISO 100, 4096×3072px, vivo X100"
                    │
                    ▼
         ApiClient().analyzeFoodWithRag(
           imageBase64: ...,
           cameraInfo: "focal length 6.73mm, ...",
         )
               │
               ├── RAG Step 1: 食物識別
               ├── RAG Step 2: CFS 資料庫搜索
               └── RAG Step 3: _analyzeWithContext()
                     System prompt 包含真實鏡頭資訊：
                     "Camera metadata: focal length 6.73mm,
                      35mm equiv 23mm, f/1.75, ..."
                     + 四步份量推理指示
```

---

## 涉及代碼

| 檔案 | 改動 |
|------|------|
| `pubspec.yaml` | 新增 `exif: ^3.3.0` |
| `lib/features/camera/screens/camera_screen.dart` | `_extractCameraInfo()` 解析 EXIF，結果存入 `_cameraInfo` state，傳給 `analyzeFoodWithRag()` |
| `lib/core/services/api_client.dart` | `analyzeFoodWithRag()` 接收 `cameraInfo` 參數，記錄到 RAG debug steps，傳入 `_analyzeWithContext()` |
| `lib/core/services/api_client.dart` | `_analyzeWithContext()` 接收 `cameraInfo`，動態生成含真實鏡頭數據的 system prompt |

---

## Step 3 Prompt 設計

### 有 CFS 官方數據時

```
You are a precise nutritionist...
The photo shows "白飯".
Camera metadata: focal length 6.73mm, 35mm equiv 23mm, f/1.75, ISO 100, vivo X100.
Use the focal length and any available sensor data to judge the field of view
and real-world scale of objects in the frame.
Below is official nutrition data from the Hong Kong Centre for Food Safety (CFS)...

STEP-BY-STEP:
1. MEASURE: Estimate each food item's physical dimensions (L×W×H cm)
   using perspective cues, plate/bowl/container size, and common object knowledge.
2. VOLUME: From the dimensions, estimate the food volume in mL or cm³.
3. WEIGHT: Convert volume to weight using typical food density
   (rice ~1.1g/mL, soup ~1.0, meat ~1.05, bread ~0.35, vegetables ~0.6).
4. NUTRITION: Use the CFS per-100g data to calculate total nutrients.
```

回傳格式：
```json
{
  "food_name": "白飯",
  "calories": 280,
  "protein": 5,
  "carbs": 62,
  "fat": 1,
  "reasoning": "dims ~12×10×3cm → ~360mL → ~396g, CFS: Steamed white rice"
}
```

### 無 CFS 數據時（降級）

同樣帶量尺寸指示，但不含 CFS 數據，Gemini 自行估算。

---

## EXIF 欄位的作用

| 欄位 | 對份量估算的意義 |
|------|----------------|
| `FocalLengthIn35mmFilm` | **最關鍵**。23mm 廣角 vs 70mm 長焦的視場角差 3 倍，直接影響畫面中物體的表觀大小判斷 |
| `FocalLength` + `Make/Model` | Gemini 知道 vivo X100 主攝的傳感器大小（1/1.49"），可反算真實視場角 |
| `SubjectDistance` | **最直接**（罕見）。拍攝距離 0.3m 還是 1.0m，影響整個尺寸推算 |
| `FNumber` | 光圈大小間接反映拍攝距離（近距離用大光圈較常見） |
| `ISOSpeedRatings` | 光線環境，影響細節可見度的置信度 |
| `ExifImageWidth/Height` | 原始解析度，幫助 Gemini 理解 1024×1024 裁切後的比例關係 |

---

## 降級邏輯

| 情況 | Prompt 內容 |
|------|------------|
| EXIF 完整（相機拍攝） | `"Camera metadata: focal length ...mm, 35mm equiv ...mm, ..."` |
| EXIF 部分缺失 | 只提供有值的欄位 |
| 無 EXIF（截圖/網絡圖片） | `"Photo taken by a typical smartphone."` |

---

## UI 可見性

RAG Pipeline Details（可展開）會顯示：
```
Camera EXIF Metadata
focal length 6.73mm, 35mm equiv 23mm, f/1.75, ISO 100, 4096×3072px, vivo X100
```

讓用戶和開發者可以確認實際用了哪些鏡頭參數。

---

## 與前方案的對比

| | Depth Anything V2（已棄用） | Gemini + EXIF（現行） |
|---|---|---|
| 需要 PC backend | ✅ 需要 | ❌ 不需要 |
| 模型大小 | 100MB PyTorch | 零（Gemini API） |
| 鏡頭資訊 | 硬編碼假設值 | 實時 EXIF |
| 估算原理 | 數學計算（有絕對尺度問題） | LLM 空間推理 |
| 可樂罐測試 | 8511mL（誤差 25x） | 待測試 |

---

## 已知局限

1. **Gemini 的空間推理本身有誤差**，只能達到「合理估算」而非精確測量，預期誤差 ±20–30%
2. **SubjectDistance EXIF 欄位**在 Android 上大多數相機應用不寫入，對焦距離仍靠 LLM 視覺判斷
3. **image_picker 會重新壓縮圖片**（maxWidth 1024, quality 85），某些 EXIF 欄位（尤其是解析度）可能被修改，但焦距/光圈/機型通常保留
4. 從**圖庫選取截圖或下載圖片**完全沒有 EXIF，降級為通用描述
