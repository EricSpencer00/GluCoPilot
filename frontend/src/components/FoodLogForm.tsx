import React, { useState } from 'react';
import { View, TextInput, Button, StyleSheet, Alert } from 'react-native';
import api from '../services/api';

interface Props {
  onSuccess: () => void;
  onCancel: () => void;
}

export default function FoodLogForm({ onSuccess, onCancel }: Props) {
  const [name, setName] = useState('');
  const [carbs, setCarbs] = useState('');
  const [fat, setFat] = useState('');
  const [protein, setProtein] = useState('');
  const [timestamp, setTimestamp] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    setLoading(true);
    try {
      await api.post('/api/v1/food', {
        name: name || undefined,
        carbs: parseFloat(carbs),
        fat: fat ? parseFloat(fat) : undefined,
        protein: protein ? parseFloat(protein) : undefined,
        timestamp: timestamp || undefined,
      });
      setLoading(false);
      onSuccess();
    } catch (error: any) {
      setLoading(false);
      Alert.alert('Error', error?.response?.data?.detail || 'Failed to save food log.');
    }
  };

  return (
    <View style={styles.form}>
      <TextInput style={styles.input} placeholder="Carbs (g) *" value={carbs} onChangeText={setCarbs} keyboardType="numeric" />
      <TextInput style={styles.input} placeholder="Food Name (optional)" value={name} onChangeText={setName} />
      <TextInput style={styles.input} placeholder="Fat (g, optional)" value={fat} onChangeText={setFat} keyboardType="numeric" />
      <TextInput style={styles.input} placeholder="Protein (g, optional)" value={protein} onChangeText={setProtein} keyboardType="numeric" />
      <TextInput style={styles.input} placeholder="Timestamp (optional, ISO)" value={timestamp} onChangeText={setTimestamp} />
      <Button title={loading ? 'Saving...' : 'Save'} onPress={handleSubmit} disabled={loading || !carbs} />
      <Button title="Cancel" onPress={onCancel} color="#888" />
    </View>
  );
}

const styles = StyleSheet.create({
  form: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: '#fff' },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 6, padding: 10, marginBottom: 16, fontSize: 16 },
});
