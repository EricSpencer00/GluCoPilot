
# GluCoPilot - AI-Powered Diabetes Management

A comprehensive, offline-first diabetes management app combining real-time CGM data, activity tracking, food logging, and AI-powered insights to help Type 1 diabetics optimize glucose control.

## 🚀 Quick Start (Recommended)

**For seamless development and debugging, always use the provided script:**

```bash
./scripts/start_glucopilot.sh
```

This script:
- Sets up and checks your Python/Node environments
- Handles backend and frontend dependencies
- Configures your local IP for mobile debugging
- Starts both backend (FastAPI) and frontend (Expo) servers
- Ensures a clean, reproducible dev environment

If you encounter issues, re-run the script to rule out environment/config problems before investigating code bugs.

---

## ✨ Core Features

### 📊 Data Ingestion
- Real-time CGM data from Dexcom
- Apple HealthKit/Google Fit for activity, sleep, heart rate
- MyFitnessPal integration for food logging
- Manual/scan food entry, insulin tracking, mood, sleep, medication, illness, menstrual cycle

### 🧠 AI-Powered Analysis
- Multi-stream pattern recognition (glucose, food, insulin, activity, sleep, mood, etc.)
- Personalized LLM-generated insights and recommendations
- Community wisdom from r/T1D
- Predictive, actionable suggestions
- Outlier and correlation analysis

### 📱 User Experience
- Interactive dashboard with real-time trends
- Multi-data visualizations
- Simple service integration UI
- Offline-first, privacy-focused (all data local)
- Actionable, time-specific insights

## 🏗 Architecture

```
GluCoPilot/
├── backend/           # Python FastAPI server
├── frontend/          # React Native mobile app
├── ai/                # Local AI models and processing
├── database/          # SQLite schema and migrations
├── docs/              # Documentation
└── scripts/           # Utility and setup scripts
```

## 🛠 Manual Setup (Advanced/CI Only)

If you must set up manually (not recommended for dev):

1. Clone repo: `git clone https://github.com/EricSpencer00/GluCoPilot.git && cd GluCoPilot`
2. Backend: `cd backend && python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`
3. Frontend: `cd frontend && npm install`
4. Configure env: `cp backend/.env.example backend/.env` (edit as needed)
5. DB: `cd backend && python -m alembic upgrade head`
6. Start backend: `uvicorn main:app --reload --host 0.0.0.0 --port 8000`
7. Start frontend: `cd frontend && npx expo start --clear`

## 📊 Data Sources

| Source | Data Type | Frequency | Format |
|--------|-----------|-----------|--------|
| Dexcom CGM | Glucose readings | 5-min | JSON |
| Apple HealthKit | Heart, steps, sleep | Real-time | JSON |
| Google Fit | Activity, steps | Real-time | JSON |
| MyFitnessPal | Nutrition | User/Sync | JSON |
| Food/Insulin/Activity/Sleep/Mood/Med/Illness/Menstrual | User/Sync | JSON |
| Reddit r/T1D | Community tips | Daily | JSON |

## � Privacy & Security

- All data stored and processed locally
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