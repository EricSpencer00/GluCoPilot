import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { TextInput, Button, Text } from 'react-native-paper';
import { useDispatch } from 'react-redux';
import { loginToDexcom } from '../store/slices/dexcomSlice';

const DexcomLoginScreen: React.FC = () => {
  const dispatch = useDispatch();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  const handleLogin = () => {
    if (!username || !password) {
      alert('Please enter both username and password.');
      return;
    }

    dispatch(loginToDexcom({ username, password }));
  };

  return (
    <View style={styles.container}>
      <Text variant="headlineSmall" style={styles.title}>Dexcom Login</Text>
      <TextInput
        label="Username"
        value={username}
        onChangeText={setUsername}
        autoCapitalize="none"
        style={styles.input}
      />
      <TextInput
        label="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        style={styles.input}
      />
      <Button mode="contained" onPress={handleLogin} style={styles.button}>
        Log In
      </Button>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 16 },
  title: { marginBottom: 16 },
  input: { marginBottom: 12 },
  button: { marginTop: 16 },
});

export default DexcomLoginScreen;
