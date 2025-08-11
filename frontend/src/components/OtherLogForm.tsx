import React, { useState } from 'react';
import { View, TextInput, Button, StyleSheet, Alert, Text } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import TimePicker from './common/TimePicker';


interface Props {
  onSuccess: (log: any) => void;
  onCancel: () => void;
}

export default function OtherLogForm({ onSuccess, onCancel }: Props) {
  const [category, setCategory] = useState('sleep');
  const [duration, setDuration] = useState('');
  const [note, setNote] = useState('');
  const [timestamp, setTimestamp] = useState(new Date());
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    setLoading(true);
    // TODO: Implement API call for 'other' log
    setTimeout(() => {
      setLoading(false);
      onSuccess({
        id: Date.now(),
        category,
        duration,
        notes: note,
        timestamp: timestamp.toISOString(),
      });
    }, 500);
  };

  return (
    <View style={styles.form}>
      <Text style={styles.label}>Category</Text>
      <Picker
        selectedValue={category}
        style={[styles.input, { color: '#000' }]}
        itemStyle={{ color: '#000' }}
        onValueChange={setCategory}
      >
        <Picker.Item label="Sleep" value="sleep" />
        <Picker.Item label="Activity" value="activity" />
        <Picker.Item label="Mood" value="mood" />
        <Picker.Item label="Other" value="other" />
      </Picker>
      <Text style={styles.label}>Duration/Value</Text>
      <TextInput style={styles.input} placeholder="e.g. 7h, 30min, 5/10 mood" value={duration} onChangeText={setDuration} />
      <Text style={styles.label}>Note (optional)</Text>
      <TextInput style={styles.input} placeholder="Notes" value={note} onChangeText={setNote} />
      <Text style={styles.label}>Time</Text>
      <TimePicker value={timestamp} onChange={setTimestamp} mode="time" />
      <Button title={loading ? 'Saving...' : 'Save'} onPress={handleSubmit} disabled={loading} />
      <Button title="Cancel" onPress={onCancel} color="#888" />
    </View>
  );
}

const styles = StyleSheet.create({
  form: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: '#fff' },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 6, padding: 10, marginBottom: 16, fontSize: 16 },
  label: { fontSize: 16, marginBottom: 8 },
});
