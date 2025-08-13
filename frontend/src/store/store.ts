import { configureStore } from '@reduxjs/toolkit';
import { persistStore, persistReducer } from 'redux-persist';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { secureStorage, AUTH_TOKEN_KEY, REFRESH_TOKEN_KEY } from '../services/secureStorage';
import { combineReducers } from 'redux';

import authReducer from './slices/authSlice';
import glucoseReducer from './slices/glucoseSlice';
import aiReducer from './slices/aiSlice';
import dexcomReducer from './slices/dexcomSlice';
import { setReduxDispatch } from '../services/reduxDispatch';

// SecureStore adapter for redux-persist (auth slice only)
const SecureStoreStorage = {
  getItem: (key: string) => secureStorage.getItem(key) as Promise<string | null>,
  setItem: (key: string, value: string) => secureStorage.setItem(key, value),
  removeItem: (key: string) => secureStorage.removeItem(key),
};

// Configure persisted reducers
const authPersistConfig = {
  key: 'auth',
  storage: SecureStoreStorage,
  whitelist: ['user', 'token', 'refreshToken']
};

const dexcomPersistConfig = {
  key: 'dexcom',
  storage: AsyncStorage,
  whitelist: ['isConnected']
};

const rootReducer = combineReducers({
  auth: persistReducer(authPersistConfig, authReducer),
  glucose: glucoseReducer,
  ai: aiReducer,
  dexcom: persistReducer(dexcomPersistConfig, dexcomReducer),
});

export const store = configureStore({
  reducer: rootReducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: false,
    }),
});

export const persistor = persistStore(store);
setReduxDispatch(store.dispatch);

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
