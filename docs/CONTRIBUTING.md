# Contributing to GluCoPilot

Thank you for your interest in contributing to GluCoPilot! This document provides guidelines and information for contributors.

## 🎯 Project Overview

GluCoPilot is an AI-powered, offline-first diabetes management application designed to help Type 1 diabetics optimize their glucose control through personalized insights and recommendations.

## 🏗 Architecture

- **Backend**: Python FastAPI with SQLite database
- **Frontend**: React Native with Expo
- **AI/ML**: Local model inference with Hugging Face fallback
- **Data Sources**: Dexcom CGM, Apple Watch, manual logging

## 🚀 Getting Started

### Prerequisites

- Python 3.9+
- Node.js 18+
- Git
- macOS (for iOS development)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/EricSpencer00/GluCoPilot.git
   cd GluCoPilot
   ```

2. **Run the setup script**
   ```bash
   ./scripts/setup.sh
   ```

3. **Configure environment**
   ```bash
   cp backend/.env.example backend/.env
   # Edit backend/.env with your configuration
   ```

## 📁 Project Structure

```
GluCoPilot/
├── backend/           # Python FastAPI backend
│   ├── api/          # API routes
│   ├── core/         # Core configuration
│   ├── models/       # Database models
│   ├── services/     # Business logic
│   ├── schemas/      # Pydantic schemas
│   └── utils/        # Utility functions
├── frontend/         # React Native app
│   └── src/
│       ├── components/  # Reusable UI components
│       ├── screens/     # Screen components
│       ├── navigation/  # Navigation configuration
│       ├── store/       # Redux store
│       └── services/    # API services
├── ai/              # AI/ML models and processing
├── database/        # Database schemas and migrations
├── docs/           # Documentation
└── scripts/        # Setup and utility scripts
```

## 🔧 Development Workflow

### Backend Development

1. **Activate Python environment**
   ```bash
   cd backend
   source venv/bin/activate
   ```

2. **Start development server**
   ```bash
   uvicorn main:app --reload
   ```

3. **Run tests**
   ```bash
   pytest
   ```

4. **Database migrations**
   ```bash
   alembic revision --autogenerate -m "Description"
   alembic upgrade head
   ```

### Frontend Development

1. **Start development server**
   ```bash
   cd frontend
   npm start
   ```

2. **Run on iOS simulator**
   ```bash
   npm run ios
   ```

3. **Run tests**
   ```bash
   npm test
   ```

### AI Model Development

1. **Navigate to AI directory**
   ```bash
   cd ai
   ```

2. **Test model inference**
   ```bash
   python test_model.py
   ```

## 🎨 Code Style

### Python (Backend)
- Follow PEP 8
- Use type hints
- Maximum line length: 100 characters
- Use Black for formatting
- Use isort for import sorting

### TypeScript/JavaScript (Frontend)
- Use TypeScript for all new code
- Follow Airbnb ESLint configuration
- Use Prettier for formatting
- Maximum line length: 100 characters

### Git Commit Messages
- Use conventional commit format
- Examples:
  - `feat: add glucose trend analysis`
  - `fix: resolve Dexcom sync issue`
  - `docs: update API documentation`
  - `refactor: improve recommendation engine`

## 🧪 Testing

### Backend Testing
- Unit tests with pytest
- Integration tests for API endpoints
- Database tests with SQLite in-memory
- AI model tests with mock data

### Frontend Testing
- Component tests with Jest and Testing Library
- Integration tests for screens
- E2E tests with Detox (iOS/Android)

### Test Coverage
- Maintain >80% code coverage
- All new features must include tests
- Critical paths require integration tests

## 🔒 Security Considerations

- **Data Privacy**: All health data remains on-device
- **Encryption**: Sensitive data encrypted at rest
- **Authentication**: Secure local authentication only
- **API Security**: Input validation and sanitization
- **Secrets**: Never commit API keys or passwords

## 📊 Performance Guidelines

### Backend
- API responses <500ms
- Database queries optimized with indexes
- Background tasks for heavy processing
- Efficient AI model loading and caching

### Frontend
- App launch <3 seconds
- Smooth 60fps animations
- Offline-first data synchronization
- Efficient state management with Redux

### AI/ML
- Model inference <10 seconds
- Local model preferred over remote
- Efficient memory usage
- Graceful fallbacks for model failures

## 🐛 Issue Reporting

### Bug Reports
Include:
- Device/OS version
- App version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots/logs if applicable

### Feature Requests
Include:
- Clear problem description
- Proposed solution
- User impact assessment
- Implementation considerations

## 📋 Pull Request Process

1. **Fork the repository**
2. **Create feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make changes with tests**
4. **Update documentation**
5. **Commit with conventional messages**
6. **Push branch and create PR**
7. **Address review feedback**

### PR Requirements
- [ ] Code follows style guidelines
- [ ] Tests pass and coverage maintained
- [ ] Documentation updated
- [ ] No merge conflicts
- [ ] Squashed commits (if requested)

## 🔍 Code Review Guidelines

### As a Reviewer
- Be constructive and respectful
- Focus on code quality and security
- Suggest improvements, don't just point out problems
- Approve when ready, request changes when needed

### As an Author
- Respond to feedback promptly
- Explain complex decisions
- Update tests and docs
- Keep PRs focused and reasonably sized

## 🏥 Healthcare Compliance

### Important Notes
- This is a personal health management tool
- Not intended for medical diagnosis
- Users should consult healthcare providers
- Follow FDA guidelines for health apps
- Maintain data accuracy and reliability

### Data Handling
- Minimize data collection
- Secure data transmission
- Clear data retention policies
- User control over data export/deletion

## 🆘 Getting Help

### Communication Channels
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Code Reviews**: Technical discussions on PRs

### Resources
- [API Documentation](http://localhost:8000/docs)
- [React Native Docs](https://reactnative.dev/docs/getting-started)
- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [Dexcom API](https://github.com/gagebenne/pydexcom)

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## 🙏 Acknowledgments

- Type 1 Diabetes community for inspiration and feedback
- Open source contributors and maintainers
- Healthcare professionals providing guidance
- OpenAI Hackathon for the opportunity

---

**Remember**: This project handles sensitive health data. Always prioritize user privacy, data security, and medical accuracy in your contributions.

Thank you for contributing to GluCoPilot! 🩺💙
