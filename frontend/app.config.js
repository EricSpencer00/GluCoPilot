// Generate development build config for Expo
// This helps fix the notification limitations in Expo Go

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
  // android config removed to target only iOS
  ios: {
    bundleIdentifier: "com.ericspencer00.glucopilot.dev",
    supportsTablet: true,
  },
  extra: {
    eas: {
      projectId: "f16e8675-cf9b-4b3d-a4ba-58b21d990311"
    }
  }
};
