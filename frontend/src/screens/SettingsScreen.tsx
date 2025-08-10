


import React, { useState } from 'react';
import DateTimePicker from '@react-native-community/datetimepicker';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { TextInput, Button, Text, Divider, Snackbar } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { ProfileStackParamList } from '../navigation/types';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store/store';
import { User } from '../types/User';
import api from '../services/api';
import { login } from '../store/slices/authSlice';

const SettingsScreen = () => {
  const navigation = useNavigation<StackNavigationProp<ProfileStackParamList, 'Settings'>>();
  const dispatch = useDispatch();
  const user: User | null = useSelector((state: RootState) => state.auth.user);
  const [form, setForm] = useState<User>({ ...(user || {}) });
  // Local state for lbs/inches
  const [weightLbs, setWeightLbs] = useState(form.weight_kg ? Math.round(form.weight_kg * 2.20462).toString() : '');
  const [heightInches, setHeightInches] = useState(form.height_cm ? Math.round(form.height_cm / 2.54).toString() : '');
  // Insulin:carb ratio split
  const [insulinUnits, setInsulinUnits] = useState('1');
  const [carbGrams, setCarbGrams] = useState(form.insulin_carb_ratio ? String(form.insulin_carb_ratio) : '15');
  // Date pickers
  const [showBirthPicker, setShowBirthPicker] = useState(false);
  const [showDiagnosisPicker, setShowDiagnosisPicker] = useState(false);
  const [saving, setSaving] = useState(false);
  const [snackbar, setSnackbar] = useState<{visible: boolean, message: string}>({visible: false, message: ''});

  const handleChange = (key: keyof User, value: any) => {
    setForm({ ...form, [key]: value });
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      // Convert lbs/inches to kg/cm
      const weight_kg = weightLbs ? Math.round((parseFloat(weightLbs) / 2.20462) * 10) / 10 : undefined;
      const height_cm = heightInches ? Math.round((parseFloat(heightInches) * 2.54) * 10) / 10 : undefined;
      // Insulin:carb ratio as grams per 1 unit
      const insulin_carb_ratio = carbGrams ? parseInt(carbGrams) : undefined;
      const updated = {
        ...form,
        weight_kg,
        height_cm,
        insulin_carb_ratio,
      };
      // Use custom API instance so base URL and token are handled automatically
      const res = await api.patch('/auth/me', updated);
      setSnackbar({visible: true, message: 'Profile updated!'});
      dispatch(login({ email: form.email, password: '' }));
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
      <TextInput label="Birthdate" value={form.birthdate ? form.birthdate.slice(0,10) : ''} style={styles.input} onFocus={() => setShowBirthPicker(true)} right={<TextInput.Icon icon="calendar" onPress={() => setShowBirthPicker(true)} />} editable={false} />
      {showBirthPicker && (
        <DateTimePicker
          value={form.birthdate ? new Date(form.birthdate) : new Date()}
          mode="date"
          display="spinner"
          onChange={(_, date) => {
            setShowBirthPicker(false);
            if (date) handleChange('birthdate', date.toISOString().slice(0,10));
          }}
        />
      )}
      <TextInput label="Height (inches)" value={heightInches} onChangeText={v => setHeightInches(v.replace(/[^0-9.]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Weight (lbs)" value={weightLbs} onChangeText={v => setWeightLbs(v.replace(/[^0-9.]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Diabetes Type (1 or 2)" value={form.diabetes_type ? String(form.diabetes_type) : ''} onChangeText={v => handleChange('diabetes_type', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Diagnosis Date" value={form.diagnosis_date ? form.diagnosis_date.slice(0,10) : ''} style={styles.input} onFocus={() => setShowDiagnosisPicker(true)} right={<TextInput.Icon icon="calendar" onPress={() => setShowDiagnosisPicker(true)} />} editable={false} />
      {showDiagnosisPicker && (
        <DateTimePicker
          value={form.diagnosis_date ? new Date(form.diagnosis_date) : new Date()}
          mode="date"
          display="spinner"
          onChange={(_, date) => {
            setShowDiagnosisPicker(false);
            if (date) handleChange('diagnosis_date', date.toISOString().slice(0,10));
          }}
        />
      )}
      <TextInput label="Target Glucose Min" value={form.target_glucose_min ? String(form.target_glucose_min) : ''} onChangeText={v => handleChange('target_glucose_min', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <TextInput label="Target Glucose Max" value={form.target_glucose_max ? String(form.target_glucose_max) : ''} onChangeText={v => handleChange('target_glucose_max', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <View style={{flexDirection:'row',alignItems:'center',marginBottom:12}}>
        <TextInput label="Insulin Units" value={insulinUnits} onChangeText={setInsulinUnits} style={[styles.input,{flex:1,marginRight:4}]} keyboardType="numeric" />
        <Text style={{marginHorizontal:4}}>:</Text>
        <TextInput label="Carb Grams" value={carbGrams} onChangeText={setCarbGrams} style={[styles.input,{flex:1,marginLeft:4}]} keyboardType="numeric" />
        <Text style={{marginLeft:8}}>Insulin:Carb Ratio (units:grams)</Text>
      </View>
      <TextInput label="Correction Factor (mg/dL per 1 unit)" value={form.insulin_sensitivity_factor ? String(form.insulin_sensitivity_factor) : ''} onChangeText={v => handleChange('insulin_sensitivity_factor', v.replace(/[^0-9]/g, ''))} style={styles.input} keyboardType="numeric" />
      <Text style={{fontSize:12,marginBottom:12,color:'#888'}}>How many mg/dL 1 unit of insulin lowers your glucose by?</Text>
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
