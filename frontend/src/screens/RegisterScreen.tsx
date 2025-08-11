import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { TextInput, Button, Text, Card, HelperText } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { register } from '../store/slices/authSlice';
import { RootState } from '../store/store';
import DisclaimerModal from '../components/DisclaimerModal';

export const RegisterScreen: React.FC<any> = ({ navigation }) => {
  const dispatch = useDispatch();
  const { isLoading, error } = useSelector((state: RootState) => state.auth);
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [disclaimerAccepted, setDisclaimerAccepted] = useState(false);

  const onAcceptDisclaimer = () => setDisclaimerAccepted(true);

  const onSubmit = async () => {
    if (!disclaimerAccepted) return;
    await dispatch(register({ email, password, first_name: firstName, last_name: lastName }) as any);
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
});
