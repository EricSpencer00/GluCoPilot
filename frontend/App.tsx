import React, { useEffect, useState } from 'react';
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
import AsyncStorage from '@react-native-async-storage/async-storage';
import { setToken } from './src/store/slices/authSlice';
import { setReduxDispatch } from './src/services/reduxDispatch';


export default function App() {
  const [isRefreshing, setIsRefreshing] = useState(true);

  useEffect(() => {
    // Initialize notification manager and Redux dispatch
    NotificationManager.initialize();
    setReduxDispatch(store.dispatch);

    // Proactive token refresh on app launch
    const refreshTokenOnLaunch = async () => {
      try {
        // Import modules
        const api = (await import('./src/services/api')).default;
        
        // First, check if we have a stored token and set it in Redux state immediately
        const storedToken = await AsyncStorage.getItem('auth_token');
        if (storedToken) {
          store.dispatch(setToken(storedToken));
          console.log('Restored stored token to Redux state');
        }
        
        // Then attempt to refresh the token with the stored refresh token
        const storedRefreshToken = await AsyncStorage.getItem('refresh_token');
        if (storedRefreshToken) {
          try {
            console.log('Attempting to refresh token on app launch');
            const refreshResponse = await api.post('/api/v1/auth/refresh', { 
              refresh_token: storedRefreshToken 
            });
            const { access_token: newToken, refresh_token: newRefreshToken } = refreshResponse.data;
            
            if (newToken) {
              console.log('Token refreshed successfully on app launch');
              await AsyncStorage.setItem('auth_token', newToken);
              store.dispatch(setToken(newToken));
              
              if (newRefreshToken) {
                await AsyncStorage.setItem('refresh_token', newRefreshToken);
              }
            }
          } catch (err) {
            console.error('Failed to refresh token on app launch:', err);
            // If refresh fails, clear tokens but don't remove yet
            // We'll let the auth interceptor handle this if a request fails
          }
        } else {
          console.log('No refresh token found on app launch');
        }
      } catch (e) {
        console.error('Error in refreshTokenOnLaunch:', e);
      } finally {
        setIsRefreshing(false);
      }
    };
    refreshTokenOnLaunch();
  }, []);

  if (isRefreshing) {
    return <LoadingScreen />;
  }

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
