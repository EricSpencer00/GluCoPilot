# GluCoPilot - AI-Powered Diabetes Management

A comprehensive, offline-first diabetes management application that combines real-time CGM data, activity tracking, food logging, and AI-powered insights to help Type 1 diabetics optimize their glucose control.

## 🎯 OpenAI Hackathon September 2025

**Playground**: https://gpt-oss.com  
**DevPost**: https://openai.devpost.com

## ✨ Core Features

### 📊 Data Ingestion
- **Real-time CGM Data**: Pulls glucose readings from Dexcom via `pydexcom`
- **Apple Watch Integration**: Heart rate, activity rings, and workout data via HealthKit
- **Smart Food Logging**: Manual entry or barcode scanning with complete nutrition profiles
- **Insulin Tracking**: Comprehensive logging of dosage, timing, and insulin types

### 🧠 AI-Powered Analysis
- **Pattern Recognition**: Identifies post-meal spikes, exercise-induced lows, and delayed bolus effects
- **Personalized Insights**: LLM-generated improvement suggestions based on individual patterns
- **Community Wisdom**: Curated advice from r/T1D relevant to detected issues
- **Predictive Recommendations**: Actionable suggestions for timing and dosing optimization

### 📱 User Experience
- **Interactive Dashboard**: Real-time glucose trends with time-in-range metrics
- **Visual Analytics**: Comprehensive charts overlaying glucose, meals, insulin, and activity
- **Offline-First**: Full functionality without internet connection
- **Local Privacy**: All data stored and processed locally

## 🏗 Architecture

```
GluCoPilot/
├── backend/           # Python FastAPI server
├── frontend/          # React Native mobile app
├── ai/               # Local AI models and processing
├── database/         # SQLite schema and migrations
├── docs/             # Documentation
└── scripts/          # Utility and setup scripts
```

### Backend (Python + FastAPI)
- **Data Collection**: Dexcom API, HealthKit bridge, manual inputs
- **Pattern Analysis**: Statistical analysis and trend detection
- **AI Integration**: Local LLM inference with Hugging Face fallback
- **Reddit Integration**: Automated r/T1D content curation

### Frontend (React Native)
- **Cross-Platform**: iOS and Android support
- **Real-Time Updates**: Live glucose monitoring and notifications
- **Intuitive UI**: Quick meal/insulin entry with barcode scanning
- **Offline Capable**: Full functionality without internet

### AI/ML Pipeline
- **Local Models**: Privacy-focused on-device inference
- **Pattern Detection**: Advanced glucose trend analysis
- **Recommendation Engine**: Personalized advice generation
- **Community Insights**: Relevant tip extraction and summarization

## 🚀 Quick Start

### Prerequisites
- Python 3.9+
- Node.js 18+
- React Native development environment
- Dexcom Share account
- Apple Watch (for activity data)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/EricSpencer00/GluCoPilot.git
   cd GluCoPilot
   ```

2. **Set up the backend**
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Set up the frontend**
   ```bash
   cd frontend
   npm install
   ```

4. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your Dexcom credentials
   ```

5. **Initialize database**
   ```bash
   cd backend
   python -m alembic upgrade head
   ```

6. **Start the application**
   ```bash
   # Terminal 1: Start backend
   cd backend
   uvicorn main:app --reload

   # Terminal 2: Start frontend
   cd frontend
   npm start
   ```

## 📊 Data Sources

| Source | Data Type | Frequency | Format |
|--------|-----------|-----------|---------|
| Dexcom CGM | Glucose readings (mg/dL) | 5-minute intervals | JSON |
| Apple Watch | Heart rate, steps, workouts | Real-time sync | JSON |
| Food Log | Nutrition data (carbs, protein, fat) | User entry | JSON |
| Insulin Log | Type, units, timestamp | User entry | JSON |
| Reddit r/T1D | Community tips and advice | Daily batch | JSON |

## 🔄 User Flow

1. **Authentication**: Secure local login
2. **Data Sync**: Automatic Dexcom and Apple Watch data retrieval
3. **Analysis**: Real-time pattern detection and AI processing
4. **Insights**: Personalized recommendations display
5. **Logging**: Quick meal and insulin entry
6. **Monitoring**: Continuous glucose trend visualization

## 🛡 Privacy & Security

- **Local Storage**: All data remains on your device
- **Encrypted Database**: SQLite with encryption at rest
- **No Cloud Dependencies**: Full offline functionality
- **Open Source**: Complete transparency and auditability

## 🎯 Hackathon Goals

- ✅ **Offline-First**: Complete functionality without internet
- ✅ **Real-Time Data**: Sub-5-second Dexcom/Apple Watch sync
- ✅ **Fast AI**: <10-second recommendation generation
- ✅ **Local Privacy**: Zero cloud data storage
- ✅ **Production Ready**: Robust error handling and fallbacks

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](./docs/CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

For questions or support, please [open an issue](https://github.com/EricSpencer00/GluCoPilot/issues) or contact the development team.

---

**Built with ❤️ for the Type 1 Diabetes community**