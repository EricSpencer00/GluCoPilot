import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import { TextInput, Button, Text, Card, HelperText } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { register, socialLogin } from '../store/slices/authSlice';
import { RootState } from '../store/store';
import DisclaimerModal from '../components/DisclaimerModal';

import * as WebBrowser from 'expo-web-browser';
import * as Google from 'expo-auth-session/providers/google';
import * as AppleAuthentication from 'expo-apple-authentication';
import Constants from 'expo-constants';
import * as Updates from 'expo-updates';

WebBrowser.maybeCompleteAuthSession();

export const RegisterScreen: React.FC<any> = ({ navigation }) => {
  const dispatch = useDispatch();
  const { isLoading, error } = useSelector((state: RootState) => state.auth);
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [disclaimerAccepted, setDisclaimerAccepted] = useState(false);
  const [appleAvailable, setAppleAvailable] = useState(false);

  const onAcceptDisclaimer = () => setDisclaimerAccepted(true);

  useEffect(() => {
    (async () => {
      if (Platform.OS === 'ios') {
        try {
          const available = await AppleAuthentication.isAvailableAsync();
          setAppleAvailable(available);
        } catch (e) {
          setAppleAvailable(false);
        }
      }
    })();
  }, []);

  // --- Google Auth Config (copied from LoginScreen) ---
  const extra = Constants.expoConfig?.extra ?? (Updates.manifest as any)?.extra;
  const [request, response, promptAsync] = Google.useIdTokenAuthRequest({
    clientId: process.env.EXPO_GOOGLE_WEB_CLIENT_ID || extra?.GOOGLE_WEB_CLIENT_ID,
    iosClientId: process.env.EXPO_GOOGLE_IOS_CLIENT_ID || extra?.GOOGLE_IOS_CLIENT_ID,
    androidClientId: process.env.EXPO_GOOGLE_ANDROID_CLIENT_ID || extra?.GOOGLE_ANDROID_CLIENT_ID,
  });

  useEffect(() => {
    if (response?.type === 'success') {
      const idToken = (response as any).params.id_token;
      const payload = idToken
        ? JSON.parse(Buffer.from(idToken.split('.')[1], 'base64').toString())
        : {};
      const firstName = payload.given_name || payload.givenName || '';
      const lastName = payload.family_name || payload.familyName || '';
      const emailFromToken = payload.email || '';
      dispatch(socialLogin({ firstName, lastName, email: emailFromToken, provider: 'google', idToken }) as any);
    }
  }, [response]);

  const onSubmit = async () => {
    if (!disclaimerAccepted) return;
    if (!email.includes('@')) {
      alert('Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      alert('Password must be at least 6 characters long.');
      return;
    }
    await dispatch(register({ email, password, first_name: firstName, last_name: lastName }) as any);
  };

  const onSocialLogin = async ({ firstName, lastName, email, provider, idToken }: any) => {
    try {
      await dispatch(socialLogin({ firstName, lastName, email, provider, idToken }) as any);
    } catch {
      alert('Social login failed.');
    }
  };

  const handleGoogleSignIn = async () => {
    try {
      await promptAsync();
    } catch (err) {
      console.error('Google Sign-In prompt error', err);
      alert('Google Sign-In failed.');
    }
  };

  const handleAppleSignIn = async () => {
    try {
      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
      });
      const idToken = credential.identityToken;
      const firstName = credential.fullName?.givenName || '';
      const lastName = credential.fullName?.familyName || '';
      const userEmail = credential.email || '';
      await onSocialLogin({ firstName, lastName, email: userEmail, provider: 'apple', idToken });
    } catch (error) {
      console.error('Apple Sign-In failed', error);
      alert('Apple Sign-In failed.');
    }
  };

  return (
    <View style={styles.container}>
      <DisclaimerModal visible={!disclaimerAccepted} onAccept={onAcceptDisclaimer} />
      <Card style={styles.card}>
        <Card.Content>
          <Text variant="headlineSmall" style={styles.title}>Create account</Text>
          <TextInput label="First name" value={firstName} onChangeText={setFirstName} style={styles.input} />
          <TextInput label="Last name" value={lastName} onChangeText={setLastName} style={styles.input} />
          <TextInput label="Email" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" style={styles.input} />
          <TextInput label="Password" value={password} onChangeText={setPassword} secureTextEntry style={styles.input} />
          {error ? <HelperText type="error" visible={true}>{error}</HelperText> : null}
          <Button mode="contained" onPress={onSubmit} loading={isLoading} style={styles.button} disabled={!disclaimerAccepted}>
            Register
          </Button>

          <View style={styles.socialContainer}>
            <Text style={styles.socialText}>Or sign up with</Text>
            <Button
              mode="outlined"
              icon="google"
              onPress={handleGoogleSignIn}
              style={styles.socialButton}
              disabled={!request}
            >
              Google
            </Button>
            {Platform.OS === 'ios' && appleAvailable && (
              <Button
                mode="outlined"
                icon="apple"
                onPress={handleAppleSignIn}
                style={styles.socialButton}
              >
                Apple
              </Button>
            )}
          </View>

          <Button onPress={() => navigation.goBack()}>Back to Login</Button>
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
  socialContainer: {
    marginTop: 24,
    alignItems: 'center',
  },
  socialText: {
    marginBottom: 8,
    color: '#888',
  },
  socialButton: {
    marginVertical: 4,
    width: 220,
  },
});
