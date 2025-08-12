import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Alert } from 'react-native';
import { TextInput, Button, Text, ActivityIndicator } from 'react-native-paper';
import { loginToDexcom, clearError } from '../store/slices/dexcomSlice';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { useAppDispatch } from '../hooks/useAppDispatch';
import { useAppSelector } from '../hooks/useAppSelector';
import { syncDexcomData } from '../store/slices/glucoseSlice';

type DexcomLoginScreenRouteParams = {
  fromRegistration?: boolean;
};

const DexcomLoginScreen: React.FC = () => {
  const dispatch = useAppDispatch();
  const navigation = useNavigation();
  const route = useRoute<RouteProp<Record<string, DexcomLoginScreenRouteParams>, string>>();
  const fromRegistration = (route.params as DexcomLoginScreenRouteParams)?.fromRegistration;
  
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isSyncing, setIsSyncing] = useState(false);
  
  const { isLoading, error, isConnected } = useAppSelector(
    (state) => state.dexcom
  );

  useEffect(() => {
    // Clean up error when component unmounts
    return () => {
      dispatch(clearError());
    };
  }, [dispatch]);

  useEffect(() => {
    // Show error message if login fails
    if (error) {
      Alert.alert('Connection Error', error);
    }
  }, [error]);

  useEffect(() => {
    // Navigate back if connection successful
    if (isConnected) {
      if (route.params && 'fromRegistration' in route.params && route.params.fromRegistration) {
        // For new registrations, sync data automatically and then navigate to dashboard
        setIsSyncing(true);
        dispatch(syncDexcomData() as any)
          .then(() => {
            Alert.alert('Success', 'Dexcom account connected and initial data synced successfully!');
            navigation.navigate('Dashboard' as never);
          })
          .catch(() => {
            Alert.alert('Connection Success', 'Dexcom account connected successfully! Initial data sync failed, please try syncing manually.');
            navigation.navigate('Dashboard' as never);
          })
          .finally(() => {
            setIsSyncing(false);
          });
      } else {
        Alert.alert('Success', 'Dexcom account connected successfully!');
        navigation.goBack();
      }
    }
  }, [isConnected, navigation, dispatch, route.params]);

  const handleLogin = () => {
    if (!username || !password) {
      Alert.alert('Missing Information', 'Please enter both username and password.');
      return;
    }

    console.log("Dispatching loginToDexcom action");
    dispatch(loginToDexcom({ username, password }));
  };

  const handleLogout = () => {
    setUsername('');
    setPassword('');
    dispatch(clearError());
  };

  return (
    <View style={styles.container}>
      <Text variant="headlineSmall" style={styles.title}>Connect Dexcom Account</Text>
      <Text variant="bodyMedium" style={styles.description}>
        Enter your Dexcom Share credentials to sync your glucose data.
        This is the same username and password you use for the Dexcom app.
      </Text>
      
      <TextInput
        label="Dexcom Username"
        value={username}
        onChangeText={setUsername}
        autoCapitalize="none"
        style={styles.input}
        disabled={isLoading || isSyncing}
      />
      <TextInput
        label="Dexcom Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        style={styles.input}
        disabled={isLoading || isSyncing}
      />
      
      {isLoading || isSyncing ? (
        <>
          <ActivityIndicator size="large" style={styles.loader} />
          <Text style={styles.syncText}>
            {isLoading ? 'Connecting to Dexcom...' : 'Syncing glucose data...'}
          </Text>
        </>
      ) : (
        <>
          <Button 
            mode="contained" 
            onPress={handleLogin} 
            style={styles.button}
          >
            Connect Account
          </Button>
          <Button 
            mode="outlined" 
            onPress={handleLogout} 
            style={styles.button}
          >
            Logout
          </Button>
        </>
      )}
      
      <Text variant="bodySmall" style={styles.disclaimer}>
        Your credentials are securely encrypted and only used to access your Dexcom data.
        GluCoPilot does not store your password in plain text.
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { 
    flex: 1, 
    justifyContent: 'center', 
    padding: 16,
    backgroundColor: '#f8f9fa' 
  },
  title: { 
    marginBottom: 16,
    textAlign: 'center' 
  },
  description: {
    marginBottom: 24,
    textAlign: 'center',
    color: '#666'
  },
  input: { 
    marginBottom: 16,
    backgroundColor: '#fff' 
  },
  button: { 
    marginTop: 8,
    paddingVertical: 6
  },
  loader: {
    marginTop: 16
  },
  syncText: {
    marginTop: 8,
    textAlign: 'center',
    color: '#0077cc'
  },
  disclaimer: {
    marginTop: 32,
    textAlign: 'center',
    color: '#888',
    paddingHorizontal: 16
  }
});

export default DexcomLoginScreen;
