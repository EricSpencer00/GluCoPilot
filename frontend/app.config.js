// Generate development build config for Expo
// This helps fix the notification limitations in Expo Go

// Load environment variables only during local development to avoid injecting logs
// into stdout when Expo's autolinking expects JSON (e.g. during EAS builds).
if (!process.env.EAS_BUILD && !process.env.CI && process.env.NODE_ENV !== 'production') {
  try {
    // Temporarily suppress stdout/stderr while loading dotenv so it doesn't
    // pollute the JSON output expected by Expo autolinking / pod install.
    const _suppressIO = (fn) => {
      const stdoutWrite = process.stdout.write;
      const stderrWrite = process.stderr.write;
      try {
        process.stdout.write = () => {};
        process.stderr.write = () => {};
        return fn();
      } finally {
        process.stdout.write = stdoutWrite;
        process.stderr.write = stderrWrite;
      }
    };

    _suppressIO(() => require('dotenv').config());
  } catch (err) {
    // ignore errors loading .env in environments where it's not present
  }
}

module.exports = {
  // Use EAS development build
  name: "GluCoPilot (Dev)",
  slug: "glucopilot",
  owner: "ericspencer00",
  version: "1.0.0",
  orientation: "portrait",
  developmentClient: {
    silentLaunch: false,
  },
  updates: {
    fallbackToCacheTimeout: 0,
    url: "https://u.expo.dev/f16e8675-cf9b-4b3d-a4ba-58b21d990311"
  },
  runtimeVersion: {
    policy: "sdkVersion"
  },
  assetBundlePatterns: [
    "**/*"
  ],
  android: {
    package: "com.ericspencer00.glucopilot.dev",
  },
  ios: {
    bundleIdentifier: "com.ericspencer00.glucopilot.dev",
    supportsTablet: true,
    newArchEnabled: false, // Disable React Native New Architecture
    infoPlist: {
      ITSAppUsesNonExemptEncryption: false
    }
  },
  extra: {
    eas: {
      projectId: "f16e8675-cf9b-4b3d-a4ba-58b21d990311"
    },
    GOOGLE_WEB_CLIENT_ID: process.env.GOOGLE_WEB_CLIENT_ID,
    GOOGLE_IOS_CLIENT_ID: process.env.EXPO_GOOGLE_IOS_CLIENT_ID || process.env.GOOGLE_IOS_CLIENT,
    GOOGLE_ANDROID_CLIENT_ID: process.env.EXPO_GOOGLE_ANDROID_CLIENT_ID || process.env.GOOGLE_ANDROID_CLIENT_ID,
  }
};
