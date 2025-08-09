import React, { useState } from 'react';
import { View, TextInput, Button, StyleSheet, Alert, Text } from 'react-native';
import Slider from '@react-native-community/slider';
import api from '../services/api';
import TimePicker from './common/TimePicker';

interface Props {
  onSuccess: () => void;
  onCancel: () => void;
}

export default function FoodLogForm({ onSuccess, onCancel }: Props) {
  const [name, setName] = useState('');
  const [carbs, setCarbs] = useState(0);
  const [fat, setFat] = useState(0);
  const [protein, setProtein] = useState(0);
  const [timestamp, setTimestamp] = useState(new Date());
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    setLoading(true);
    try {
      await api.post('/api/v1/food/log', {
        name: name || undefined,
        carbs,
        fat: fat || undefined,
        protein: protein || undefined,
        timestamp: timestamp.toISOString(),
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
      <Text style={styles.label}>Carbs (g): {carbs}</Text>
      <Slider
        style={{ width: '100%', height: 40 }}
        minimumValue={1}
        maximumValue={150}
        step={1}
        value={carbs}
        onValueChange={setCarbs}
        minimumTrackTintColor="#1fb28a"
        maximumTrackTintColor="#d3d3d3"
        thumbTintColor="#1fb28a"
      />
      <TextInput style={styles.input} placeholder="Food Name (optional)" value={name} onChangeText={setName} />
      <Text style={styles.label}>Fat (g): {fat}</Text>
      <Slider
        style={{ width: '100%', height: 40 }}
        minimumValue={0}
        maximumValue={150}
        step={1}
        value={fat}
        onValueChange={setFat}
        minimumTrackTintColor="#fbc02d"
        maximumTrackTintColor="#d3d3d3"
        thumbTintColor="#fbc02d"
      />
      <Text style={styles.label}>Protein (g): {protein}</Text>
      <Slider
        style={{ width: '100%', height: 40 }}
        minimumValue={0}
        maximumValue={150}
        step={1}
        value={protein}
        onValueChange={setProtein}
        minimumTrackTintColor="#1976d2"
        maximumTrackTintColor="#d3d3d3"
        thumbTintColor="#1976d2"
      />
      <Text style={styles.label}>Time</Text>
      <TimePicker value={timestamp} onChange={setTimestamp} mode="time" />
      <Button title={loading ? 'Saving...' : 'Save'} onPress={handleSubmit} disabled={loading || carbs < 1} />
      <Button title="Cancel" onPress={onCancel} color="#888" />
    </View>
  );
}

const styles = StyleSheet.create({
  form: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: '#fff' },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 6, padding: 10, marginBottom: 16, fontSize: 16 },
  label: { fontSize: 16, marginBottom: 8 },
});
