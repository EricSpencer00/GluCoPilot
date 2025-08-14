
import React, { useState } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import { TextInput, Button, Text, Card, HelperText } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { login } from '../store/slices/authSlice';
import { RootState } from '../store/store';
import { GoogleSignin } from '@react-native-google-signin/google-signin';
import { appleAuth } from '@invertase/react-native-apple-authentication';


export const LoginScreen: React.FC<any> = ({ navigation }) => {
  const dispatch = useDispatch();
  const { isLoading, error } = useSelector((state: RootState) => state.auth);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  // Configure Google Sign-In (replace with your webClientId)
  React.useEffect(() => {
    GoogleSignin.configure({
      webClientId: 'YOUR_GOOGLE_WEB_CLIENT_ID',
    });
  }, []);

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
    // You should dispatch a socialLogin action here
    // await dispatch(socialLogin({ firstName, lastName, email, provider, idToken }) as any);
    alert(`Logged in with ${provider}: ${firstName} ${lastName} (${email})`);
  };

  const handleGoogleSignIn = async () => {
    try {
      await GoogleSignin.hasPlayServices();
      const userInfo = await GoogleSignin.signIn();
      const { givenName, familyName, email } = userInfo.user;
      const idToken = userInfo.idToken;
      await onSocialLogin({ firstName: givenName, lastName: familyName, email, provider: 'google', idToken });
    } catch (error) {
      alert('Google Sign-In failed.');
    }
  };

  const handleAppleSignIn = async () => {
    try {
      const appleAuthRequestResponse = await appleAuth.performRequest({
        requestedOperation: appleAuth.Operation.LOGIN,
        requestedScopes: [appleAuth.Scope.FULL_NAME, appleAuth.Scope.EMAIL],
      });
      const { fullName, email, identityToken } = appleAuthRequestResponse;
      await onSocialLogin({
        firstName: fullName?.givenName || '',
        lastName: fullName?.familyName || '',
        email: email || '',
        provider: 'apple',
        idToken: identityToken,
      });
    } catch (error) {
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
