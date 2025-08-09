import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Alert } from 'react-native';
import { TextInput, Button, Text, ActivityIndicator } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { loginToDexcom, clearError } from '../store/slices/dexcomSlice';
import { RootState } from '../store/store';
import { useNavigation } from '@react-navigation/native';

const DexcomLoginScreen: React.FC = () => {
  const dispatch = useDispatch();
  const navigation = useNavigation();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  
  const { isLoading, error, isConnected } = useSelector(
    (state: RootState) => state.dexcom
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
      Alert.alert('Success', 'Dexcom account connected successfully!');
      navigation.goBack();
    }
  }, [isConnected, navigation]);

  const handleLogin = () => {
    if (!username || !password) {
      Alert.alert('Missing Information', 'Please enter both username and password.');
      return;
    }

    dispatch(loginToDexcom({ username, password }) as any);
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
        disabled={isLoading}
      />
      <TextInput
        label="Dexcom Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        style={styles.input}
        disabled={isLoading}
      />
      
      {isLoading ? (
        <ActivityIndicator size="large" style={styles.loader} />
      ) : (
        <Button 
          mode="contained" 
          onPress={handleLogin} 
          style={styles.button}
        >
          Connect Account
        </Button>
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
  disclaimer: {
    marginTop: 32,
    textAlign: 'center',
    color: '#888',
    paddingHorizontal: 16
  }
});

export default DexcomLoginScreen;
