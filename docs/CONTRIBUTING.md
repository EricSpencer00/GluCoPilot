
# Contributing to GluCoPilot

Thank you for your interest in GluCoPilot! We welcome contributions of all kinds. Please read this guide before submitting code, issues, or documentation.

## 🚦 Development Workflow


**All development and debugging should be done via:**

```bash
./scripts/start_glucopilot.sh
```

This script sets up both backend and frontend, checks/fixes dependencies, and—crucially—automatically configures the correct `API_BASE_URL` in `frontend/app.json` for your local network. This is required for Expo Go or device/simulator to connect to your backend.

**You do NOT need to manually edit your IP address.** The script will detect your local IP and update the config. If you switch networks or your IP changes, just re-run the script.

**Expo Note:**
- For physical devices, both your computer and device must be on the same WiFi network.
- If you have issues connecting, check your firewall and ensure the backend is reachable from your device using the printed IP.
- If you use a simulator/emulator, the script will still set the correct IP, but you may use `localhost` or `127.0.0.1` if supported by your setup.

**Do not manually start backend/frontend for development unless you are debugging the script itself.**

---

## 🏗 Project Structure

```
GluCoPilot/
├── backend/           # Python FastAPI backend
│   ├── api/           # API routes
│   ├── core/          # Core config
│   ├── models/        # DB models
│   ├── services/      # Business logic
│   ├── schemas/       # Pydantic schemas
│   └── utils/         # Utilities
├── frontend/          # React Native app
│   └── src/
│       ├── components/  # UI components
│       ├── screens/     # Screens
│       ├── navigation/  # Navigation
│       ├── store/       # Redux store
│       └── services/    # API services
├── ai/                # AI/ML models and processing
├── database/           # DB schemas/migrations
├── docs/               # Documentation
└── scripts/            # Setup and utility scripts
```

## 🧑‍� Coding Standards

- **Python:** PEP8, type hints, Black, isort
- **TypeScript:** Airbnb ESLint, Prettier, 100-char lines
- **Commits:** Conventional format (e.g. `feat:`, `fix:`, `docs:`)

## 🧪 Testing

- **Backend:** pytest, SQLite in-memory, >80% coverage
- **Frontend:** Jest, Testing Library, Detox (E2E)
- **AI:** Mock/test data for model logic

All new features must include tests. Critical paths require integration tests.


## 🔑 API Keys & Secrets

You will need to set up several API keys/tokens for local development. Copy `backend/.env.example` to `backend/.env` and fill in the following:

- **Dexcom:**
  - `DEXCOM_USERNAME` and `DEXCOM_PASSWORD` are your Dexcom Share credentials.
- **HuggingFace:**
  - Get a free token at https://huggingface.co/settings/tokens and set `HUGGINGFACE_TOKEN` and `HF_TOKEN`.
- **Reddit:**
  - Create an app at https://www.reddit.com/prefs/apps, set `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`, and `REDDIT_USER_AGENT`.
- **Expo/EAS:**
  - Register your app at https://expo.dev, set `EXPO_APP_ID`.
- **REACT_APP_API_BASE_URL:**
  - Usually `http://localhost:8000` for local dev. The startup script will update this for device debugging.

**Never commit your real secrets or credentials!**

---

## 🔒 Security & Privacy

- All health data is local only
- SQLite encrypted at rest
- No cloud storage
- Never commit secrets or credentials

## 🐛 Issue Reporting

**Bugs:**
- Device/OS, app version
- Steps to reproduce
- Expected vs actual
- Logs/screenshots if possible

**Features:**
- Problem description
- Proposed solution
- User impact

## 📋 Pull Requests

1. Fork and branch: `git checkout -b feature/your-feature`
2. Make changes with tests/docs
3. Commit with conventional messages
4. Push and open PR
5. Address review feedback

**PRs must:**
- Pass all tests/coverage
- Follow style guidelines
- Update docs as needed
- Have no merge conflicts

## 🏥 Healthcare Compliance

- Not for medical diagnosis
- Users should consult healthcare providers
- Follow FDA guidelines for health apps
- Minimize and secure data

## 🆘 Getting Help

- GitHub Issues: bugs/features
- Discussions: questions/ideas
- [API Docs](http://localhost:8000/docs)
- [React Native](https://reactnative.dev/docs/getting-started)
- [FastAPI](https://fastapi.tiangolo.com/)

## 📜 License

MIT License - see [LICENSE](../LICENSE)

---

**Always prioritize user privacy, data security, and medical accuracy.**

Thank you for contributing to GluCoPilot! 💙
