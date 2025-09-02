<!-- Official badge -->
![CI](https://github.com/EricSpencer00/GluCoPilot/actions/workflows/i-like-seeing-green.yml/badge.svg)


# GluCoPilot - AI-Powered Diabetes Management

GluCoPilot is a comprehensive, privacy-focused diabetes management platform. It combines real-time CGM data, activity tracking, food logging, and AI-powered insights to help people with diabetes optimize glucose control. The project now supports both a modern native iOS app (SwiftUI) and a React Native app, powered by a FastAPI backend.


## 🚀 Quick Start

### 1. Backend (FastAPI)

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # Edit as needed
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 2. iOS App (SwiftUI, iOS 18+)

```bash
cd new-frontend
open Package.swift  # Or open in Xcode
# Build and run on device/simulator (iOS 18+ required)
```

### 3. React Native App (Optional, legacy)

```bash
cd frontend
npm install
npx react-native run-ios  # or run-android
```

### 4. AI/Insights Engine (Optional)

```bash
cd ai
# Run or develop local AI/insights modules as needed
```

---

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


## 🤝 Contributing

See [Contributing Guide](./docs/CONTRIBUTING.md) for details.


## 📄 License

MIT License - see [LICENSE](LICENSE)


## 🙋‍♂️ Support

Open an issue or contact the dev team.

---


**Built with ❤️ for the Type 1 Diabetes community**
