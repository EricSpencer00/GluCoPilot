import { configureStore } from '@reduxjs/toolkit';
import { persistStore, persistReducer } from 'redux-persist';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { combineReducers } from 'redux';

import authReducer from './slices/authSlice';
import glucoseReducer from './slices/glucoseSlice';
import aiReducer from './slices/aiSlice';
import dexcomReducer from './slices/dexcomSlice';
import { setReduxDispatch } from '../services/reduxDispatch';

// Configure persisted reducers
const authPersistConfig = {
  key: 'auth',
  storage: AsyncStorage,
  whitelist: ['user', 'token']
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
