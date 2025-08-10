


import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { TextInput, Button, Text, Divider, Snackbar } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { ProfileStackParamList } from '../navigation/types';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store/store';
import { User } from '../types/User';
import axios from 'axios';
import { login } from '../store/slices/authSlice';

const SettingsScreen = () => {
  const navigation = useNavigation<StackNavigationProp<ProfileStackParamList, 'Settings'>>();
  const dispatch = useDispatch();
  const user: User | null = useSelector((state: RootState) => state.auth.user);
  const [form, setForm] = useState<User>({ ...(user || {}) });
  const [saving, setSaving] = useState(false);
  const [snackbar, setSnackbar] = useState<{visible: boolean, message: string}>({visible: false, message: ''});

  const handleChange = (key: keyof User, value: any) => {
    setForm({ ...form, [key]: value });
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      // PATCH user profile
      const res = await axios.patch('/api/auth/me', form);
      setSnackbar({visible: true, message: 'Profile updated!'});
      // Refresh user in Redux (re-login to get new user data)
      dispatch(login({ email: form.email, password: '' })); // password may not be needed if token is valid
    } catch (e: any) {
      setSnackbar({visible: true, message: 'Failed to update profile.'});
    } finally {
      setSaving(false);
    }
  };

  if (!user) {
    return (
      <View style={styles.container}><Text>No user loaded.</Text></View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Edit Profile</Text>
      <Divider style={{marginBottom: 16}} />
      <TextInput label="First Name" value={form.first_name || ''} onChangeText={v => handleChange('first_name', v)} style={styles.input} />
      <TextInput label="Last Name" value={form.last_name || ''} onChangeText={v => handleChange('last_name', v)} style={styles.input} />
      <TextInput label="Email" value={form.email || ''} onChangeText={v => handleChange('email', v)} style={styles.input} keyboardType="email-address" autoCapitalize="none" />
      <TextInput label="Username" value={form.username || ''} onChangeText={v => handleChange('username', v)} style={styles.input} autoCapitalize="none" />
      <TextInput label="Gender" value={form.gender || ''} onChangeText={v => handleChange('gender', v)} style={styles.input} />
      <TextInput label="Birthdate (YYYY-MM-DD)" value={form.birthdate ? form.birthdate.slice(0,10) : ''} onChangeText={v => handleChange('birthdate', v)} style={styles.input} />
      <TextInput label="Height (cm)" value={form.height_cm ? String(form.height_cm) : ''} onChangeText={v => handleChange('height_cm', v.replace(/[^0-9.]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Weight (kg)" value={form.weight_kg ? String(form.weight_kg) : ''} onChangeText={v => handleChange('weight_kg', v.replace(/[^0-9.]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Diabetes Type (1 or 2)" value={form.diabetes_type ? String(form.diabetes_type) : ''} onChangeText={v => handleChange('diabetes_type', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Diagnosis Date (YYYY-MM-DD)" value={form.diagnosis_date ? form.diagnosis_date.slice(0,10) : ''} onChangeText={v => handleChange('diagnosis_date', v)} style={styles.input} />
      <TextInput label="Target Glucose Min" value={form.target_glucose_min ? String(form.target_glucose_min) : ''} onChangeText={v => handleChange('target_glucose_min', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Target Glucose Max" value={form.target_glucose_max ? String(form.target_glucose_max) : ''} onChangeText={v => handleChange('target_glucose_max', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Insulin:Carb Ratio" value={form.insulin_carb_ratio ? String(form.insulin_carb_ratio) : ''} onChangeText={v => handleChange('insulin_carb_ratio', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Correction Factor" value={form.insulin_sensitivity_factor ? String(form.insulin_sensitivity_factor) : ''} onChangeText={v => handleChange('insulin_sensitivity_factor', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <Button mode="contained" onPress={handleSave} loading={saving} style={styles.saveButton}>
        Save Changes
      </Button>
      <Button mode="outlined" onPress={() => navigation.goBack()} style={styles.saveButton}>
        Cancel
      </Button>
      <Snackbar visible={snackbar.visible} onDismiss={() => setSnackbar({visible: false, message: ''})} duration={3000}>
        {snackbar.message}
      </Snackbar>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    padding: 20,
    backgroundColor: '#fff',
    alignItems: 'stretch',
    justifyContent: 'flex-start',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
  input: {
    marginBottom: 12,
    backgroundColor: '#f9f9f9',
  },
  saveButton: {
    marginVertical: 10,
  },
});

export default SettingsScreen;
