GluCoPilot Privacy Policy

This document summarizes how GluCoPilot handles user data, AI processing, and privacy-related choices. It is a companion to the in-app privacy statement and the full legal privacy policy.

1. Data Collection

- Primary sources: Apple HealthKit, Dexcom (optional), manual user entries, and device sensors.
- Types of data: glucose readings, insulin dosing, activity, sleep, nutrition, mood, medications, and other health-related events.

2. AI Processing

- GluCoPilot uses Hugging Face open-source AI models (OSS 20B and OSS 120B) for generating insights and trend descriptions.
- Before any data is sent to an AI model, personally identifying information is removed or pseudonymized. Only anonymized, de-identified data is processed by the AI.
- AI processing is stateless: the input data is used for the immediate request and is not stored persistently by the AI service in any database controlled by the app developer.

3. Data Storage & Sharing

- By default, health data remains on the user's device (HealthKit or encrypted SQLite managed by the app).
- The developer does not store raw health data on external servers without explicit user consent.
- Users can export their data (JSON/CSV) or request deletion; follow the in-app Settings > Privacy options or contact support.

4. Accuracy & Medical Disclaimer

- AI-generated content is for informational purposes only and may be inaccurate. It should not be used as a substitute for professional medical advice.
- For treatment or medication decisions, consult a qualified healthcare professional.

5. Consent & Controls

- The app requests permissions just-in-time with clear explanations of why each permission is needed.
- Analytics and telemetry are off by default and require explicit opt-in.
- Users can view connected services, revoke permissions, export data, and request deletion from Settings > Privacy.

6. Security

- Data at rest is encrypted.
- Tokens and credentials are stored securely (iOS Keychain recommended).
- Network requests use TLS and standard best practices; users should verify endpoint security for any cloud features.

7. Contact

If you have questions about privacy or wish to request data export/deletion, contact support@yourdomain.example.
