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

  const useProxy = true;
  const [request, response, promptAsync] = Google.useIdTokenAuthRequest(
    {
      clientId: process.env.EXPO_GOOGLE_WEB_CLIENT_ID || ((Constants.manifest as any)?.extra?.GOOGLE_WEB_CLIENT_ID as string),
      iosClientId: process.env.EXPO_GOOGLE_IOS_CLIENT_ID || ((Constants.manifest as any)?.extra?.GOOGLE_IOS_CLIENT_ID as string),
      androidClientId: process.env.EXPO_GOOGLE_ANDROID_CLIENT_ID || ((Constants.manifest as any)?.extra?.GOOGLE_ANDROID_CLIENT_ID as string),
    },
    { useProxy }
  );

  useEffect(() => {
    if (response?.type === 'success') {
      const idToken = (response as any).params.id_token;
      let payload: any = {};
      try {
        payload = idToken ? JSON.parse(Buffer.from(idToken.split('.')[1], 'base64').toString()) : {};
      } catch (e) {
        payload = {};
      }
      const fName = payload.given_name || payload.givenName || '';
      const lName = payload.family_name || payload.familyName || '';
      const emailFromToken = payload.email || '';
      dispatch(socialLogin({ firstName: fName, lastName: lName, email: emailFromToken, provider: 'google', idToken }) as any);
    }
  }, [response]);

  const onSubmit = async () => {
    if (!disclaimerAccepted) return;
    await dispatch(register({ email, password, first_name: firstName, last_name: lastName }) as any);
  };

  const handleGoogle = async () => {
    try {
      await promptAsync({ useProxy });
    } catch (e) {
      console.warn('Google auth failed', e);
      alert('Google sign-in failed');
    }
  };

  const handleApple = async () => {
    try {
      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
      });
      const idToken = credential.identityToken;
      const fName = credential.fullName?.givenName || '';
      const lName = credential.fullName?.familyName || '';
      const userEmail = credential.email || '';
      dispatch(socialLogin({ firstName: fName, lastName: lName, email: userEmail, provider: 'apple', idToken }) as any);
    } catch (e) {
      console.warn('Apple auth failed', e);
      alert('Apple sign-in failed');
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
              onPress={handleGoogle}
              style={styles.socialButton}
              disabled={!request}
            >
              Google
            </Button>
            {Platform.OS === 'ios' && appleAvailable && (
              <Button
                mode="outlined"
                icon="apple"
                onPress={handleApple}
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
