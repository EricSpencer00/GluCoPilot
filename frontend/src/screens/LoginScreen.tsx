import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Platform, Alert } from 'react-native';
import { TextInput, Button, Text, Card, HelperText } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { login, socialLogin } from '../store/slices/authSlice';
import { RootState } from '../store/store';
import appleAuth from '@invertase/react-native-apple-authentication';

export const LoginScreen: React.FC<any> = ({ navigation }) => {
  const dispatch = useDispatch();
  const { isLoading, error } = useSelector((state: RootState) => state.auth);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  // Apple only: No Google Auth

  const onSubmit = async () => {
    if (!email || !email.includes('@')) {
      Alert.alert('Invalid Email', 'Please enter a valid email address.');
      return;
    }
    if (!password || password.length < 6) {
      Alert.alert('Invalid Password', 'Password must be at least 6 characters long.');
      return;
    }
    await dispatch(login({ email, password }) as any);
  };

  // Apple only: No Google Social Login

  const handleAppleSignIn = async () => {
    try {
      const appleAuthRequestResponse = await appleAuth.performRequest({
        requestedOperation: appleAuth.Operation.LOGIN,
        requestedScopes: [appleAuth.Scope.EMAIL, appleAuth.Scope.FULL_NAME],
      });

      const { identityToken, fullName, email } = appleAuthRequestResponse;
      const firstName = fullName?.givenName || '';
      const lastName = fullName?.familyName || '';
      const userEmail = email || '';
      await dispatch(socialLogin({ firstName, lastName, email: userEmail, provider: 'apple', idToken: identityToken || '' }) as any);
    } catch (error) {
      console.error('Apple Sign-In failed', error);
      Alert.alert('Error', 'Apple Sign-In failed.');
    }
  };

  return (
    <View style={styles.container}>
      <Card style={styles.card}>
        <Card.Content>
          <Text variant="headlineSmall" style={styles.title}>Welcome back</Text>
          <TextInput
            label="Email"
            value={email}
            onChangeText={setEmail}
            autoCapitalize="none"
            keyboardType="email-address"
            style={styles.input}
          />
          <TextInput
            label="Password"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            style={styles.input}
          />
          {error ? <HelperText type="error" visible>{String(error)}</HelperText> : null}
          <Button mode="contained" onPress={onSubmit} loading={isLoading} style={styles.button}>
            Log In
          </Button>
          <Button onPress={() => navigation.navigate('Register')}>Create an account</Button>
          <Button onPress={() => navigation.navigate('ForgotPassword')}>Forgot password?</Button>

          <View style={styles.socialContainer}>
            <Text style={styles.socialText}>Or sign in with</Text>
            {Platform.OS === 'ios' && (
              <Button mode="outlined" icon="apple" onPress={handleAppleSignIn} style={styles.socialButton}>
                Apple
              </Button>
            )}
          </View>
        </Card.Content>
      </Card>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 16 },
  card: { borderRadius: 12 },
  title: { marginBottom: 16 },
  input: { marginBottom: 12 },
  button: { marginTop: 8 },
  socialContainer: { marginTop: 24, alignItems: 'center' },
  socialText: { marginBottom: 8, color: '#888' },
  socialButton: { marginVertical: 4, width: 220 },
});
