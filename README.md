# GluCoPilot - AI-Powered Diabetes Management

A comprehensive, offline-first diabetes management application that combines real-time CGM data, activity tracking, food logging, and AI-powered insights to help Type 1 diabetics optimize their glucose control.

## 🎯 OpenAI Hackathon September 2025

**Playground**: https://gpt-oss.com  
**DevPost**: https://openai.devpost.com

## ✨ Core Features

### 📊 Data Ingestion
- **Real-time CGM Data**: Pulls glucose readings from Dexcom via `pydexcom`
- **Health Integrations**: Apple HealthKit/Google Fit for activity, sleep, and heart rate data
- **MyFitnessPal Integration**: Comprehensive food logging with detailed nutrition data
- **Smart Food Logging**: Manual entry or barcode scanning with complete nutrition profiles
- **Insulin Tracking**: Comprehensive logging of dosage, timing, and insulin types
- **Comprehensive Health Data**: Mood tracking, sleep quality, medication, illness, and menstrual cycle data

### 🧠 AI-Powered Analysis
- **Multi-Stream Pattern Recognition**: Identifies correlations across glucose, food, insulin, activity, sleep, mood, and more
- **Personalized Insights**: LLM-generated improvement suggestions based on comprehensive analysis
- **Community Wisdom**: Curated advice from r/T1D relevant to detected issues
- **Predictive Recommendations**: Actionable suggestions with specific timing and personalized interventions
- **Outlier Detection**: Identifies unusual patterns and potential health concerns across all data streams
- **Correlation Analysis**: Shows how different factors (exercise, sleep, stress) affect glucose levels

### 📱 User Experience
- **Interactive Dashboard**: Real-time glucose trends with time-in-range metrics
- **Multi-Data Visualization**: Comprehensive charts overlaying glucose, meals, insulin, activity, sleep, and mood
- **Service Integration UI**: Simple toggles to connect external services like MyFitnessPal
- **Offline-First**: Full functionality without internet connection
- **Local Privacy**: All data stored and processed locally
- **Actionable Insights**: Specific recommendations with timing and expected outcomes

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
- **Multi-Stream Pattern Detection**: Advanced correlation analysis across all health data
- **Outlier Detection**: Identifies unusual patterns and potential health concerns
- **Recommendation Engine**: Personalized advice with specific timing and actions
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
| Apple HealthKit | Heart rate, steps, workouts, sleep | Real-time sync | JSON |
| Google Fit | Activity, steps, workouts | Real-time sync | JSON |
| MyFitnessPal | Detailed nutrition data | User entry & sync | JSON |
| Food Log | Nutrition data (carbs, protein, fat) | User entry | JSON |
| Insulin Log | Type, units, timestamp | User entry | JSON |
| Activity Log | Type, duration, intensity | User entry & sync | JSON |
| Sleep Log | Duration, quality, phases | User entry & sync | JSON |
| Mood Log | Rating, description, tags | User entry | JSON |
| Medication Log | Name, dosage, timing | User entry | JSON |
| Illness Log | Type, severity, duration | User entry | JSON |
| Menstrual Cycle | Dates, symptoms, flow | User entry | JSON |
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