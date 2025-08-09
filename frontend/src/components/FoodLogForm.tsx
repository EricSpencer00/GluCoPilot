import React, { useState } from 'react';
import { View, TextInput, Button, StyleSheet } from 'react-native';

interface Props {
  onSuccess: () => void;
  onCancel: () => void;
}

export default function FoodLogForm({ onSuccess, onCancel }: Props) {
  const [name, setName] = useState('');
  const [carbs, setCarbs] = useState('');
  const [timestamp, setTimestamp] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    setLoading(true);
    await fetch('/api/food/log', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, carbs: parseFloat(carbs), timestamp: timestamp || undefined }),
    });
    setLoading(false);
    onSuccess();
  };

  return (
    <View style={styles.form}>
      <TextInput style={styles.input} placeholder="Food Name" value={name} onChangeText={setName} />
      <TextInput style={styles.input} placeholder="Carbs (g)" value={carbs} onChangeText={setCarbs} keyboardType="numeric" />
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
