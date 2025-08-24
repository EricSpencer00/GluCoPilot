import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import { TextInput, Button, Text, Card, HelperText } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { register, socialLogin } from '../store/slices/authSlice';
import { RootState } from '../store/store';
import DisclaimerModal from '../components/DisclaimerModal';

// import * as Google from 'expo-auth-session/providers/google';
import * as AppleAuthentication from 'expo-apple-authentication';
import Constants from 'expo-constants';
import * as Updates from 'expo-updates';


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

  // Apple only: No Google Auth

  const onSubmit = async () => {
    // Switch registration to Apple-only flow
    if (!disclaimerAccepted) return;
    await handleAppleSignIn();
  };

  // Apple only: No Google Social Login

  const handleAppleSignIn = async () => {
    try {
      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
      });
      const idToken = credential.identityToken as string;
      const firstName = credential.fullName?.givenName || '';
      const lastName = credential.fullName?.familyName || '';
      const userEmail = credential.email || '';
      await dispatch(socialLogin({ firstName, lastName, email: userEmail, provider: 'apple', idToken }) as any);
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
            Continue with Apple
          </Button>

          <View style={styles.socialContainer}>
            {/* Apple-only registration; keep secondary Apple button hidden to avoid duplicates */}
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
