import React, { useState } from 'react';
import { View, TextInput, Button, StyleSheet, Alert, Text, Switch } from 'react-native';
import Slider from '@react-native-community/slider';
import api from '../services/api';
import TimePicker from './common/TimePicker';

interface Props {
  onSuccess: () => void;
  onCancel: () => void;
}

export default function InsulinLogForm({ onSuccess, onCancel }: Props) {
  const [units, setUnits] = useState(0);
  const [isFast, setIsFast] = useState(true);
  const [timestamp, setTimestamp] = useState(new Date());
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    setLoading(true);
    try {
      await api.post('/api/v1/insulin', {
        units,
        insulin_type: isFast ? 'fast' : 'slow',
        timestamp: timestamp.toISOString(),
      });
      setLoading(false);
      onSuccess();
    } catch (error: any) {
      setLoading(false);
      Alert.alert('Error', error?.response?.data?.detail || 'Failed to save insulin log.');
    }
  };

  return (
    <View style={styles.form}>
      <Text style={styles.label}>Units: {units}</Text>
      <Slider
        style={{ width: '100%', height: 40 }}
        minimumValue={0}
        maximumValue={25}
        step={0.5}
        value={units}
        onValueChange={setUnits}
        minimumTrackTintColor="#1fb28a"
        maximumTrackTintColor="#d3d3d3"
        thumbTintColor="#1fb28a"
      />
      <View style={styles.switchRow}>
        <Text style={styles.label}>Fast-acting</Text>
        <Switch value={isFast} onValueChange={setIsFast} />
        <Text style={styles.label}>Slow-acting</Text>
      </View>
      <Text style={styles.label}>Time</Text>
      <TimePicker value={timestamp} onChange={setTimestamp} mode="time" />
      <Button title={loading ? 'Saving...' : 'Save'} onPress={handleSubmit} disabled={loading || units === 0} />
      <Button title="Cancel" onPress={onCancel} color="#888" />
    </View>
  );
}

const styles = StyleSheet.create({
  form: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: '#fff' },
  label: { fontSize: 16, marginBottom: 8 },
  switchRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 16, gap: 8 },
});
