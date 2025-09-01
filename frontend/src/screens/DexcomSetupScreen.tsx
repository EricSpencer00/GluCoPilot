import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { TextInput, Button, Switch, Text, Headline } from 'react-native-paper';
import { useDispatch } from 'react-redux';
import api from '../services/api';
import { secureStorage, DEXCOM_USERNAME_KEY, DEXCOM_PASSWORD_KEY, DEXCOM_OUS_KEY } from '../services/secureStorage';

interface DexcomSetupScreenProps {
  navigation: any;
}

const DexcomSetupScreen: React.FC<DexcomSetupScreenProps> = ({ navigation }) => {
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
      // Call stateless sync endpoint using provided credentials
      const response = await api.post('/api/v1/glucose/stateless/sync', {
        username,
        password,
        ous,
      });

      if (response.data.readings) {
        Alert.alert('Success', 'Dexcom account connected and initial sync completed');

        // Persist credentials securely on device for future stateless calls
        await secureStorage.setItem(DEXCOM_USERNAME_KEY, username);
        await secureStorage.setItem(DEXCOM_PASSWORD_KEY, password);
        await secureStorage.setItem(DEXCOM_OUS_KEY, String(ous));

        // Read-back verification to ensure credentials were persisted
        try {
          const vUser = await secureStorage.getItem(DEXCOM_USERNAME_KEY);
          const vPass = await secureStorage.getItem(DEXCOM_PASSWORD_KEY);
          const vOus = await secureStorage.getItem(DEXCOM_OUS_KEY);
          console.log('Post-persist stored dexcom check:', { hasUser: !!vUser, hasPass: !!vPass, ous: vOus });
          if (!vUser || !vPass) {
            Alert.alert('Warning', 'Dexcom connected but credentials could not be saved on this device. Please try again or check app storage permissions.');
          }
        } catch (e) {
          console.error('Error verifying stored Dexcom credentials:', e);
        }

        // Navigate back
        navigation.goBack();
      } else {
        throw new Error('Unexpected response from server');
      }
    } catch (error: any) {
      console.error('Dexcom connection error:', error);
      Alert.alert(
        'Connection Failed',
        error.response?.data?.detail || error.message || 'Could not connect to Dexcom'
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
        {loading ? 'Connecting...' : 'Connect Dexcom'}
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
