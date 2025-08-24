
import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import { Button, Text, Card, HelperText } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { socialLogin } from '../store/slices/authSlice';
import { RootState } from '../store/store';
import DisclaimerModal from '../components/DisclaimerModal';
import * as AppleAuthentication from 'expo-apple-authentication';


export const RegisterScreen: React.FC<any> = () => {
  const dispatch = useDispatch();
  const { isLoading, error } = useSelector((state: RootState) => state.auth);
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

  const onSubmit = async () => {
    if (!disclaimerAccepted) return;
    await handleAppleSignIn();
  };

  const handleAppleSignIn = async () => {
    try {
      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
      });
      const idToken = credential.identityToken as string;
      // Always use Apple-provided info only
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
          <Text variant="headlineSmall" style={styles.title}>Sign in or Register with Apple</Text>
          {error ? <HelperText type="error" visible={true}>{error}</HelperText> : null}
          {appleAvailable ? (
            <Button mode="contained" onPress={onSubmit} loading={isLoading} style={styles.button} disabled={!disclaimerAccepted}>
              Continue with Apple
            </Button>
          ) : (
            <Text style={{marginTop: 16, color: '#888'}}>Apple Sign-In is not available on this device.</Text>
          )}
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
