import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { Provider as PaperProvider } from 'react-native-paper';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { NavigationContainer } from '@react-navigation/native';

import { store, persistor } from './src/store/store';
import { AppNavigator } from './src/navigation/AppNavigator';
import { LoadingScreen } from './src/components/common/LoadingScreen';
import { theme } from './src/theme/theme';
import { NotificationManager } from './src/services/NotificationManager';

// Set up axios defaults
import axios from 'axios';
axios.defaults.baseURL = 'http://127.0.0.1:8000/api/v1'; // Match FastAPI route prefix

export default function App() {
  React.useEffect(() => {
    // Initialize notification manager
    NotificationManager.initialize();
    
    // Set up axios interceptors for auth token
    axios.interceptors.request.use(
      async (config) => {
        const token = store.getState().auth.token;
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );
  }, []);

  return (
    <Provider store={store}>
      <PersistGate loading={<LoadingScreen />} persistor={persistor}>
        <PaperProvider theme={theme}>
          <SafeAreaProvider>
            <NavigationContainer theme={theme}>
              <AppNavigator />
            </NavigationContainer>
            <StatusBar style="auto" />
          </SafeAreaProvider>
        </PaperProvider>
      </PersistGate>
    </Provider>
  );
}
