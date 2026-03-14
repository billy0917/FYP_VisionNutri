# SmartDiet AI

A multimodal personalized nutrition ecosystem powered by AI.

## Overview

SmartDiet AI is a comprehensive nutrition tracking and advice system that combines:
- **AI Vision**: Food recognition and macro estimation using multimodal AI models
- **RAG Chatbot**: AI nutritionist powered by FastGPT knowledge base
- **Gamification**: Streaks, points, and achievements to motivate users
- **Personalization**: Goal-based recommendations (hypertrophy, weight loss, etc.)

## Project Structure

```
smart_diet_ai/
├── backend/                    # FastAPI backend
│   ├── app/
│   │   ├── core/              # Configuration, utilities
│   │   ├── services/          # Vision AI, RAG services
│   │   ├── routers/           # API endpoints (TODO)
│   │   └── main.py            # FastAPI app entry point
│   ├── requirements.txt
│   └── .env.example
│
├── lib/                        # Flutter mobile app
│   ├── core/
│   │   ├── config/            # App configuration
│   │   ├── services/          # Supabase, API client
│   │   └── theme/             # App theming
│   ├── features/
│   │   ├── auth/              # Login, register, splash
│   │   ├── dashboard/         # Main home screen
│   │   ├── camera/            # Food photo capture
│   │   └── chat/              # AI nutritionist chat
│   └── main.dart              # App entry point
│
├── supabase/                   # Database schema
│   └── schema.sql             # PostgreSQL schema
│
└── pubspec.yaml               # Flutter dependencies
```

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Python FastAPI
- **Database**: Supabase (PostgreSQL)
- **AI Vision**: OpenRouter API (GPT-4o, Gemini Pro Vision)
- **RAG**: FastGPT API

## Getting Started

### Prerequisites

- Flutter SDK (3.10+)
- Python 3.11+
- Supabase account
- OpenRouter API key
- FastGPT API key

### Backend Setup

1. Navigate to backend directory:
   ```bash
   cd backend
   ```

2. Create virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Create `.env` file from example:
   ```bash
   cp .env.example .env
   ```

5. Fill in your API keys in `.env`

6. Run the server:
   ```bash
   uvicorn app.main:app --reload
   ```

### Flutter Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Update `lib/core/config/app_config.dart` with your Supabase credentials

3. Run the app:
   ```bash
   flutter run
   ```

### Database Setup

1. Create a new Supabase project

2. Run the SQL schema:
   - Go to SQL Editor in Supabase dashboard
   - Copy contents of `supabase/schema.sql`
   - Execute the SQL

3. Create storage bucket:
   - Go to Storage in Supabase dashboard
   - Create a bucket named `food-images`
   - Set appropriate policies

## Features

### Core Features
- User authentication (Supabase Auth)
- Food image capture and upload
- AI food analysis via OpenRouter
- RAG chatbot interface
- Dashboard with daily stats
- Gamification stats display

### Planned Features
- Detailed food logging history
- Recipe recommendations
- Weekly/monthly progress reports
- Notification system
- Social features (sharing achievements)
- Export data functionality

## Database Schema

The schema includes:
- **profiles**: User profiles linked to Supabase auth
- **food_logs**: Food entries with macros and AI metadata
- **daily_stats**: Aggregated daily statistics
- **gamification_stats**: User points, streaks, levels
- **point_history**: Detailed point earning log
- **achievements**: Available achievements
- **user_achievements**: Unlocked achievements per user
- **recipes**: AI-recommendable recipes
- **chat_sessions/messages**: Chat history with AI
- **weight_logs**: Weight tracking over time

## API Endpoints (Backend)

```
POST /api/v1/vision/analyze      - Analyze food image
POST /api/v1/vision/upload       - Upload and analyze food
POST /api/v1/chat/message        - Send chat message
GET  /api/v1/recipes             - Get recipe recommendations
GET  /api/v1/stats/daily         - Get daily statistics
GET  /api/v1/stats/gamification  - Get gamification stats
```

## License

MIT License
