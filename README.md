<!-- Official badge -->
![CI](https://github.com/EricSpencer00/GluCoPilot/actions/workflows/i-like-seeing-green.yml/badge.svg)

# Info

- Uses openai/gpt-oss-20b for a backend
- Calls the native model via API, no fine-tuning whatsoever besides some prompt engineering

# GluCoPilot - AI-Powered Diabetes Management

GluCoPilot is a comprehensive, privacy-focused diabetes management platform. It combines real-time CGM data, activity tracking, food logging, and AI-powered insights to help people with diabetes optimize glucose control. The project now supports both a modern native iOS app (SwiftUI) and a React Native app, powered by a FastAPI backend.


## 🚀 Quick Start

These instructions assume macOS with Python 3.11+ installed for the backend and Xcode for the iOS app.

### 1. Backend (FastAPI)

```bash
cd backend
# create a virtualenv (python3.11 recommended)
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
# copy example env and edit backend/.env as needed
cp .env.example .env
# run migrations (if using database)
alembic upgrade head
# run the API (development)
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Notes:
- The backend loads environment variables from `backend/.env` by default. See `backend/.env.example` for available settings.
- Default `DATABASE_URL` is `sqlite:///./glucopilot.db`. To use Postgres, set `DATABASE_URL` accordingly and enable `USE_DATABASE=true` in the env.

### 2. iOS App (SwiftUI, iOS 18+)

```bash
cd GluCoPilot
# open the Xcode project or workspace
open GluCoPilot.xcodeproj
# or open the workspace if you use SPM or CocoaPods
```

Notes:
- This repo contains a modern SwiftUI iOS app in `GluCoPilot/` (target: iOS 18+, Swift 6).
- In Xcode: set your development team, update the bundle identifier, and enable the Apple Sign In and HealthKit capabilities in the target's Signing & Capabilities tab.
- Update the app's API base URL in `GluCoPilot/Managers/APIManager.swift` (or equivalent) to point to your running backend (e.g., `http://localhost:8000`).

### 3. (Optional) React Native / legacy frontend

```bash
cd frontend
npm install
# run the React Native app (legacy) or follow the README inside frontend/
npx react-native run-ios
```

The `new-frontend/` name used earlier in older docs is now `GluCoPilot/` (SwiftUI). The `frontend/` folder is the previous React Native codebase (legacy).
---

## ✨ Core Features


### 🔐 Authentication & Privacy
- Apple Sign In (native iOS)
- Secure keychain storage
- All data local & encrypted (no cloud dependencies)

### 📊 Data Integration
- Real-time CGM data from Dexcom
- Apple HealthKit (iOS): steps, heart rate, sleep, exercise
- MyFitnessPal (via HealthKit)
- Manual/scan food entry, insulin, mood, sleep, medication, illness, menstrual cycle

### 🧠 AI-Powered Analysis
- Multi-stream pattern recognition (glucose, food, insulin, activity, sleep, mood, etc.)
- Personalized LLM-generated insights and recommendations
- Predictive, actionable suggestions
- Outlier and correlation analysis

### 📱 User Experience
- Modern SwiftUI iOS app (iOS 18+)
- Optional React Native app (legacy)
- Interactive dashboard, real-time trends, multi-data visualizations
- Simple onboarding: Apple Sign In + HealthKit permissions


## 🏗 Architecture

```
GluCoPilot/
├── backend/         # FastAPI Python backend
├── new-frontend/    # SwiftUI iOS app (iOS 18+)
├── frontend/        # React Native app (legacy)
├── ai/              # Local AI/insights engine
├── docs/            # Documentation
└── scripts/         # Utility/setup scripts
```


## 🛠 Manual Setup (Advanced)

1. Clone repo: `git clone https://github.com/EricSpencer00/GluCoPilot.git && cd GluCoPilot`
2. Backend: `cd backend && python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`
3. SwiftUI iOS: `cd new-frontend && open Package.swift` (build/run in Xcode)
4. React Native: `cd frontend && npm install && npx react-native run-ios`
5. Configure env: `cp backend/.env.example backend/.env` (edit as needed)
6. DB: `cd backend && python -m alembic upgrade head`
7. Start backend: `uvicorn main:app --reload --host 0.0.0.0 --port 8000`


## 📊 Data Sources

| Source         | Data Type         | Frequency | Format |
|----------------|------------------|-----------|--------|
| Dexcom CGM     | Glucose readings | 5-min     | JSON   |
| Apple HealthKit| Heart, steps, sleep, nutrition | Real-time | JSON |
| MyFitnessPal   | Nutrition        | User/Sync | JSON   |
| Manual Entry   | Food, insulin, activity, sleep, mood, med, illness, menstrual | User/Sync | JSON |
| Reddit r/T1D   | Community tips   | Daily     | JSON   |


## 🔒 Privacy & Security

- All data stored and processed locally on device
- SQLite encrypted at rest
- No cloud dependencies
- Open source and auditable

Note on AI and data processing:

- The app may use Hugging Face open-source AI models (OSS 20B and OSS 120B) to generate insights. Any health data sent for AI processing is anonymized and processed transiently; the developer does not persist raw health data in external databases by default. See `docs/PRIVACY_POLICY.md` for details.


## 🤝 Contributing

See [Contributing Guide](./docs/CONTRIBUTING.md) for details.


## 📄 License

MIT License - see [LICENSE](LICENSE)


## 🙋‍♂️ Support

Open an issue or contact the dev team.

---


**Built with ❤️ for the Type 1 Diabetes community**
