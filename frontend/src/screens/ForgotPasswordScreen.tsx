import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { Text, Card, Button, TextInput, HelperText, Snackbar } from 'react-native-paper';

export const ForgotPasswordScreen: React.FC<any> = ({ navigation }) => {
  const [email, setEmail] = useState('');
  const [emailError, setEmailError] = useState('');
  const [loading, setLoading] = useState(false);
  const [snackbarVisible, setSnackbarVisible] = useState(false);
  const [snackbarMsg, setSnackbarMsg] = useState('');

  const validateEmail = (value: string) => {
    // Simple email regex
    return /\S+@\S+\.\S+/.test(value);
  };

  const handleReset = () => {
    if (!email) {
      setEmailError('Email is required');
      return;
    }
    if (!validateEmail(email)) {
      setEmailError('Enter a valid email address');
      return;
    }
    setEmailError('');
    setLoading(true);
    // Simulate API call
    setTimeout(() => {
      setLoading(false);
      setSnackbarMsg('If an account exists for this email, reset instructions have been sent.');
      setSnackbarVisible(true);
    }, 1500);
  };

  return (
    <View style={styles.container}>
      <Card style={styles.card}>
        <Card.Content>
          <Text variant="headlineSmall" style={styles.title}>Forgot password</Text>
          <Text style={{ marginBottom: 16 }}>Enter your email address to receive password reset instructions.</Text>
          <TextInput
            label="Email"
            value={email}
            onChangeText={setEmail}
            autoCapitalize="none"
            keyboardType="email-address"
            error={!!emailError}
            style={{ marginBottom: 4 }}
            disabled={loading}
            autoFocus
          />
          <HelperText type="error" visible={!!emailError}>{emailError}</HelperText>
          <Button
            mode="contained"
            onPress={handleReset}
            loading={loading}
            disabled={loading}
            style={{ marginTop: 8 }}
          >
            Send Reset Instructions
          </Button>
          <Button onPress={() => navigation.goBack()} style={{ marginTop: 8 }} disabled={loading}>
            Back
          </Button>
        </Card.Content>
      </Card>
      <Snackbar
        visible={snackbarVisible}
        onDismiss={() => setSnackbarVisible(false)}
        duration={4000}
        action={{ label: 'OK', onPress: () => setSnackbarVisible(false) }}
      >
        {snackbarMsg}
      </Snackbar>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 16, backgroundColor: '#fff' },
  card: { borderRadius: 12, paddingVertical: 8 },
  title: { marginBottom: 16 },
});
