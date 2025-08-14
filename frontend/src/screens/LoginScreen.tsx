import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import { TextInput, Button, Text, Card, HelperText } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { login, socialLogin } from '../store/slices/authSlice';
import { RootState } from '../store/store';
import * as WebBrowser from 'expo-web-browser';
import * as Google from 'expo-auth-session/providers/google';
import * as AppleAuthentication from 'expo-apple-authentication';
import Constants from 'expo-constants';


WebBrowser.maybeCompleteAuthSession();

export const LoginScreen: React.FC<any> = ({ navigation }) => {
  const dispatch = useDispatch();
  const { isLoading, error } = useSelector((state: RootState) => state.auth);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const useProxy = true; // use Expo proxy in dev

  const [request, response, promptAsync] = Google.useIdTokenAuthRequest(
    {
      clientId: process.env.EXPO_GOOGLE_WEB_CLIENT_ID || (Constants.manifest?.extra?.GOOGLE_WEB_CLIENT_ID as string),
      iosClientId: process.env.EXPO_GOOGLE_IOS_CLIENT_ID || (Constants.manifest?.extra?.GOOGLE_IOS_CLIENT_ID as string),
      androidClientId: process.env.EXPO_GOOGLE_ANDROID_CLIENT_ID || (Constants.manifest?.extra?.GOOGLE_ANDROID_CLIENT_ID as string),
    },
    { useProxy }
  );

  useEffect(() => {
    if (response?.type === 'success') {
      const idToken = (response as any).params.id_token;
      // decode JWT to get names
      const payload = idToken ? JSON.parse(Buffer.from(idToken.split('.')[1], 'base64').toString()) : {};
      const firstName = payload.given_name || payload.givenName || '';
      const lastName = payload.family_name || payload.familyName || '';
      const emailFromToken = payload.email || '';
      dispatch(socialLogin({ firstName, lastName, email: emailFromToken, provider: 'google', idToken }) as any);
    }
  }, [response]);

  const onSubmit = async () => {
    if (!email.includes('@')) {
      alert('Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      alert('Password must be at least 6 characters long.');
      return;
    }
    await dispatch(login({ email, password }) as any);
  };

  // Social login handler (to be implemented in your redux/auth logic)
  const onSocialLogin = async ({ firstName, lastName, email, provider, idToken }: any) => {
    try {
      await dispatch(socialLogin({ firstName, lastName, email, provider, idToken }) as any);
    } catch (err) {
      alert('Social login failed.');
    }
  };

  const handleGoogleSignIn = async () => {
    try {
      await promptAsync({ useProxy });
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
          {error ? <HelperText type="error" visible={true}>{typeof error === 'string' ? error : JSON.stringify(error)}</HelperText> : null}
          <Button mode="contained" onPress={onSubmit} loading={isLoading} style={styles.button}>
            Log In
          </Button>
          <Button onPress={() => navigation.navigate('Register')}>
            Create an account
          </Button>
          <Button onPress={() => navigation.navigate('ForgotPassword')}>
            Forgot password?
          </Button>

          {/* Social Sign-In Buttons */}
          <View style={styles.socialContainer}>
            <Text style={styles.socialText}>Or sign in with</Text>
            <Button
              mode="outlined"
              icon="google"
              onPress={handleGoogleSignIn}
              style={styles.socialButton}
            >
              Google
            </Button>
            {Platform.OS === 'ios' && (
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
