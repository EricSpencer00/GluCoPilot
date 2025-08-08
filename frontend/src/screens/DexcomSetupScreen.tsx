import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { TextInput, Button, Switch, Text, Headline } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import api from '../../services/api';

const DexcomSetupScreen = ({ navigation }) => {
  const dispatch = useDispatch();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [ous, setOus] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleConnect = async () => {
    if (!username || !password) {
      Alert.alert('Error', 'Please provide both username and password');
      return;
    }
    
    setLoading(true);
    
    try {
      // Connect Dexcom account
      const response = await api.post('/api/v1/auth/connect-dexcom', {
        username,
        password,
        ous
      });
      
      if (response.data.success) {
        Alert.alert('Success', 'Dexcom account connected successfully');
        
        // Trigger data sync
        await api.post('/api/v1/glucose/sync');
        
        // Navigate back
        navigation.goBack();
      }
    } catch (error) {
      console.error('Dexcom connection error:', error);
      Alert.alert(
        'Connection Failed',
        error.response?.data?.detail || 'Could not connect to Dexcom'
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Headline style={styles.headline}>Connect Dexcom Account</Headline>
      
      <Text style={styles.description}>
        Connect your Dexcom account to sync glucose readings automatically.
        Your credentials are encrypted and stored securely.
      </Text>
      
      <TextInput
        label="Dexcom Username"
        value={username}
        onChangeText={setUsername}
        style={styles.input}
        autoCapitalize="none"
      />
      
      <TextInput
        label="Dexcom Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        style={styles.input}
      />
      
      <View style={styles.switchContainer}>
        <Text>Outside US (International)</Text>
        <Switch value={ous} onValueChange={setOus} />
      </View>
      
      <Button
        mode="contained"
        onPress={handleConnect}
        loading={loading}
        disabled={loading}
        style={styles.button}
      >
        Connect Dexcom
      </Button>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: 16,
    flexGrow: 1,
  },
  headline: {
    marginBottom: 16,
    textAlign: 'center',
  },
  description: {
    marginBottom: 24,
    opacity: 0.7,
  },
  input: {
    marginBottom: 16,
  },
  switchContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 24,
  },
  button: {
    marginTop: 8,
  },
});

export default DexcomSetupScreen;
