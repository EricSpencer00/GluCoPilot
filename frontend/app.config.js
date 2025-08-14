// Generate development build config for Expo
// This helps fix the notification limitations in Expo Go

const dotenv = require('dotenv');
dotenv.config();

module.exports = {
  // Use EAS development build
  name: "GluCoPilot (Dev)",
  slug: "glucopilot-dev",
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
