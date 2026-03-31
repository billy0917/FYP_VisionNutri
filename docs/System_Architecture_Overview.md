# System Architecture Overview — SmartDiet AI

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Client)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │  Camera  │  │  Chat    │  │Dashboard │  │  Profile   │  │
│  │ + ARCore │  │ Screen   │  │+ History │  │+ Settings  │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────┬──────┘  │
│       │              │              │               │         │
│  ┌────▼──────────────▼──────────────▼───────────────▼──────┐ │
│  │          Core Services (ApiClient, SupabaseService,      │ │
│  │           VolumeService, ChatService)                    │ │
│  └──────────┬───────────────────────┬──────────────────────┘ │
│             │                       │                         │
│  ┌──────────▼──────┐   ┌────────────▼────────────┐           │
│  │  MobileSAM ONNX │   │  ARCore Plugin (patched) │           │
│  │  (on-device)    │   │  (Android only)          │           │
│  └─────────────────┘   └─────────────────────────┘           │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTPS
          ┌─────────────┴──────────────┐
          │                            │
┌─────────▼──────────┐   ┌────────────▼─────────────────────┐
│  Python Backend     │   │  External Cloud APIs             │
│  (FastAPI)          │   │                                  │
│                     │   │  • Gemini 3.1 Flash Lite Preview │
│  Depth Anything V2  │   │    (Vision LLM, via relay)       │
│  (volume estimate)  │   │  • text-embedding-3-small        │
│                     │   │    (768-dim embeddings)          │
└─────────────────────┘   └──────────────────────────────────┘
                                        │
                           ┌────────────▼────────────┐
                           │  Supabase (PostgreSQL)   │
                           │  + pgvector extension    │
                           │                          │
                           │  Auth · food_logs        │
                           │  profiles · daily_stats  │
                           │  cfs_foods (embeddings)  │
                           │  chat_messages · ...     │
                           └─────────────────────────┘
```

---

## 2. Frontend — Flutter App

**Entry Point:** `main.dart` → `SupabaseService.initialize()` → `SplashScreen`

**Navigation:** `DashboardScreen` hosts a 3-tab `NavigationBar` (Dashboard / Camera / Chat) via `IndexedStack`. Plain `Navigator.push` for sub-screens.

**State Management:** `setState` (no Provider / Riverpod / Bloc).

### Feature Modules (`lib/features/`)

| Feature | Key Screens |
|---|---|
| `auth` | `SplashScreen`, `LoginScreen`, `RegisterScreen` — PKCE Supabase auth |
| `camera` | `CameraScreen`, `ArMeasureScreen` — food capture, AR measurement, segmentation |
| `chat` | `ChatScreen` — streaming AI dietitian chat |
| `dashboard` | `DashboardScreen`, `MealHistoryScreen` — daily stats, gamification |
| `food_entry` | `ManualFoodEntryScreen` — text-based food logging |
| `profile` | `ProfileScreen` — physical stats, TDEE, dietary restrictions |
| `benchmark` | `BenchmarkListScreen/Detail/Charts` — compare volume estimation methods |

### Core Services (`lib/core/services/`)

| Service | Responsibility |
|---|---|
| `api_client.dart` | All outbound AI calls: food analysis (RAG), benchmarking, dimension estimation |
| `supabase_service.dart` | Auth, CRUD for `profiles`, `food_logs`, `daily_stats`; Storage uploads |
| `volume_service.dart` | On-device MobileSAM ONNX inference → segmentation mask + sample points |
| `chat_service.dart` | 30-day diet context builder, suggestion chips, CFS RAG search, SSE stream |

### Key Packages

`supabase_flutter` · `onnxruntime` · `arcore_flutter_plugin` (local patched) · `image_picker` · `exif` · `image` · `vector_math` · `http` · `flutter_markdown` · `fl_chart` · `share_plus` · `shared_preferences`

---

## 3. On-Device AI — MobileSAM (ONNX)

Located in `lib/core/services/volume_service.dart`, using model files:
- `assets/models/mobilesam_encoder.onnx`
- `assets/models/mobilesam_decoder.onnx`

**Pipeline:**
1. Captures AR scene screenshot via patched ARCore plugin
2. Runs MobileSAM encoder → image embedding
3. Runs MobileSAM decoder with a centre point prompt → food segmentation mask
4. Outputs: bounding box ratios, food pixel ratio, IoU confidence, mask PNG, sample point grid

**AR Integration:**  
Mask sample points are fed into `sampleHitTestPoints()` on the ARCore plugin to project 2D points into 3D world space → bounding box W × L × H in cm. Falls back to uniform grid sampling if segmentation fails.

---

## 4. Backend — Python (FastAPI)

**Entry:** `backend/app/main.py` — CORS middleware, registers routers, pre-loads `DepthService` on startup.

### API Endpoint

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/volume/estimate` | Accepts `{image_base64, focal_length_35mm}`, returns volume/dimensions in cm |

### Depth Volume Pipeline (`depth_service.py`)

1. Load `depth-anything/Depth-Anything-V2-Small-hf` (HuggingFace, 25M params, CPU inference)
2. Generate per-pixel disparity map from single food photo
3. Sample border pixels → median surface level
4. Threshold disparity → food mask
5. Compute heights above surface × real-world pixel area (from 35mm focal length + assumed 40 cm camera distance) → volume in cm³

> The RAG pipeline (Gemini LLM calls + CFS lookups) runs entirely in the Flutter client, not through this backend.

---

## 5. Database — Supabase (PostgreSQL + pgvector)

### Core Tables

| Table | Purpose |
|---|---|
| `profiles` | Physical stats, TDEE/BMR, macro targets, dietary restrictions |
| `food_logs` | Per-meal entries: macros, meal type, AI model used, confidence, reasoning |
| `daily_stats` | Aggregated daily calorie/macro totals; goal-met flags |
| `gamification_stats` | Streaks, total points, level, XP |
| `point_history` | Audit log of point-earning actions |
| `achievements` / `user_achievements` | Achievement definitions + user unlock records |
| `chat_sessions` / `chat_messages` | Full chat history (role: user / assistant) |
| `weight_logs` | Time-series weight tracking |
| `recipes` / `user_favorite_recipes` | AI-generated recipes (JSONB) + favourites |
| `cfs_foods` | Hong Kong CFS nutrition database; per-100g macros + `embedding vector(768)` |

### Vector Search

- `pgvector` extension with IVFFlat index (100 lists, cosine ops) on `cfs_foods.embedding`
- `match_cfs_food(query_embedding, match_count, match_threshold=0.6)` RPC for semantic food lookup
- Embeddings generated via `text-embedding-3-small` (768-dim)

**Auth triggers:** `handle_new_user()` auto-creates `profiles` + `gamification_stats` on signup.

---

## 6. AI / ML Components Summary

| Component | Where | Model | Purpose |
|---|---|---|---|
| MobileSAM | On-device (Flutter/ONNX) | `mobilesam_encoder/decoder.onnx` | Food segmentation, AR sample points |
| Vision LLM | Cloud (Gemini relay) | Gemini 3.1 Flash Lite Preview | Food ID, nutrition estimation, chat |
| Text Embedding | Cloud (Gemini relay) | `text-embedding-3-small` (768-dim) | Semantic CFS food search |
| Depth Estimation | Python Backend | Depth Anything V2 Small (HuggingFace) | Monocular depth → volume in cm³ |
| ARCore | On-device (Android) | Patched `arcore_flutter_plugin` | 3D plane detection + bounding box |

---

## 7. RAG Food Analysis Data Flow

```
User presses "Analyze"
        │
        ▼
CameraScreen._analyzeImage()
        │
        ├─ Base64 encode captured image
        ├─ Build cameraInfo:
        │    • EXIF FocalLengthIn35mmFilm
        │    • ArMeasurement.toPromptContext()   (if AR scan was run)
        │    • VolumeEstimationResult.toPromptContext()  (MobileSAM mask)
        │
        ▼
ApiClient.analyzeFoodWithRag(imageBase64, cameraInfo)
        │
        ├─ Step 1: Gemini Vision
        │    → Identify Chinese + English food name pairs
        │
        ├─ Step 2: CFS Lookup (per food item)
        │    A) ilike text search on cfs_foods.food_name_chi   (primary)
        │    B) text-embedding-3-small → match_cfs_food RPC    (vector fallback)
        │
        ├─ Step 3: Gemini Vision
        │    → System prompt: nutritionist + dimension estimation
        │    → Injected context: CFS per-100g data + cameraInfo
        │    → Output: { food_name, calories, protein, carbs, fat, reasoning }
        │
        ▼
FoodAnalysisResult displayed in CameraScreen
        │
        ▼ (user confirms)
SupabaseService: INSERT food_logs + UPSERT daily_stats
```

---

## 8. Chat Data Flow

```
ChatScreen opens
    → ChatService.buildDietContext()     — profiles + 30-day food_logs
    → ChatService.generateSuggestions() — Gemini → 4 personalised chip questions

User sends message
    → ChatService.detectFoodQuery()     — Chinese/English keyword match
    → (if nutrition query) searchCfsFood()
          → text search, or vector fallback via match_cfs_food RPC
          → CFS rows appended to message as context
    → ChatService.streamChat()
          → POST to Gemini (SSE, stream: true)
          → Line-by-line token streaming → live typing effect in ChatScreen
```

---

## 9. Storage

| Bucket | Contents |
|---|---|
| `food-images` | Uploaded food photos (per meal log) |
| `avatars` | User profile pictures |
