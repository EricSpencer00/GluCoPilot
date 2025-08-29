import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Platform, Alert } from 'react-native';
import { Button, Text, Card, HelperText } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { socialLogin } from '../store/slices/authSlice';
import { RootState } from '../store/store';
import { store } from '../store/store';
import DisclaimerModal from '../components/DisclaimerModal';
import appleAuth from '@invertase/react-native-apple-authentication';


export const RegisterScreen: React.FC<any> = ({ navigation }) => {
  const dispatch = useDispatch();
  const { isLoading, error } = useSelector((state: RootState) => state.auth);
  const [disclaimerAccepted, setDisclaimerAccepted] = useState(false);
  const [appleAvailable, setAppleAvailable] = useState(false);

  const onAcceptDisclaimer = () => setDisclaimerAccepted(true);

  useEffect(() => {
    const checkAppleSignInAvailability = async () => {
      try {
        if (Platform.OS === 'ios') {
          const available = await appleAuth.isSupported;
          setAppleAvailable(available);
        }
      } catch (error) {
        console.log('Apple Sign-In availability check failed', error);
        setAppleAvailable(false);
      }
    };
    checkAppleSignInAvailability();
  }, []);

  const onSubmit = async () => {
    if (!disclaimerAccepted) return;
    await handleAppleSignIn();
  };

  const handleAppleSignIn = async () => {
    try {
      const appleAuthRequestResponse = await appleAuth.performRequest({
        requestedOperation: appleAuth.Operation.LOGIN,
        requestedScopes: [appleAuth.Scope.EMAIL, appleAuth.Scope.FULL_NAME],
      });

      const { identityToken, fullName, email } = appleAuthRequestResponse;
      const idToken = identityToken as string;
      if (!idToken) {
        Alert.alert('Error', 'Apple did not return a valid identityToken. This usually happens on a simulator or with a test Apple account. Please use a real device and a real Apple ID.');
        return;
      }
      // Check alg in header (should be RS256)
      try {
        const header = JSON.parse(atob(idToken.split('.')[0]));
        if (header.alg !== 'RS256') {
          Alert.alert('Error', 'Apple identityToken is not signed with RS256. This is not a real Apple token. Please use a real device and a real Apple ID.');
          return;
        }
      } catch (e) {
        // Ignore header parse errors
      }
      // Always use Apple-provided info only
      const firstName = fullName?.givenName || '';
      const lastName = fullName?.familyName || '';
      const userEmail = email || '';
      await dispatch(socialLogin({ firstName, lastName, email: userEmail, provider: 'apple', idToken }) as any);
      // If socialLogin resulted in a new registration, navigate user to Dexcom connect flow
      // We check the auth state after dispatch to avoid adding coupling in the thunk
      setTimeout(async () => {
        try {
          // Use the imported store directly
          const state = store.getState();
          const isNew = state.auth?.isNewRegistration;
          if (isNew) {
            navigation.navigate('Profile', { screen: 'DexcomLogin', params: { fromRegistration: true } });
          }
        } catch (e) {
          // ignore
        }
      }, 250);
    } catch (error) {
      console.error('Apple Sign-In failed', error);
      Alert.alert('Error', 'Apple Sign-In failed.');
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
