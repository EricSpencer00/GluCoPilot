import React, { useState } from 'react';
import { View, TextInput, Button, StyleSheet, Alert, Text, TouchableOpacity, Platform } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import TimePicker from './common/TimePicker';
import Slider from '@react-native-community/slider';


interface Props {
  onSuccess: (log: any) => void;
  onCancel: () => void;
}

export default function OtherLogForm({ onSuccess, onCancel }: Props) {
  const [category, setCategory] = useState('sleep');
  const [duration, setDuration] = useState('');
  // Mood: 1-5, Activity: minutes, Sleep: hours
  const [mood, setMood] = useState('');
  const [activityMinutes, setActivityMinutes] = useState('');
  const [sleepHours, setSleepHours] = useState(8);
  const [sleepQuality, setSleepQuality] = useState('Good');
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

      {/* Dynamic input for each category */}
      {category === 'mood' && (
        <View style={{ marginBottom: 16 }}>
          <Text style={styles.label}>Mood</Text>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 }}>
            {/* Top 5 moods: Stress, Anxiety, Sadness, Anger, Happiness */}
            {[
              { emoji: '😰', label: 'Stress' },
              { emoji: '😟', label: 'Anxiety' },
              { emoji: '😢', label: 'Sadness' },
              { emoji: '😡', label: 'Anger' },
              { emoji: '😃', label: 'Happiness' },
            ].map(({ emoji, label }) => (
              <TouchableOpacity
                key={emoji}
                style={[styles.emojiBtn, mood === emoji && styles.emojiBtnActive]}
                onPress={() => setMood(emoji)}
                accessibilityLabel={label}
              >
                <Text style={{ fontSize: 28 }}>{emoji}</Text>
                <Text style={{ fontSize: 10, textAlign: 'center' }}>{label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      )}

      {category === 'activity' && (
        <View style={{ marginBottom: 16 }}>
          <Text style={styles.label}>Activity Minutes</Text>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 8 }}>
            {[10, 20, 30, 45, 60, 90, 120].map(val => (
              <TouchableOpacity
                key={val}
                style={[styles.quickBtn, activityMinutes === String(val) && styles.emojiBtnActive]}
                onPress={() => setActivityMinutes(String(val))}
              >
                <Text style={{ fontSize: 16 }}>{val} min</Text>
              </TouchableOpacity>
            ))}
            <TextInput
              style={[styles.input, { width: 80, marginLeft: 8 }]}
              placeholder="Other"
              keyboardType="numeric"
              value={activityMinutes}
              onChangeText={setActivityMinutes}
            />
          </View>
        </View>
      )}

      {category === 'sleep' && (
        <View style={{ marginBottom: 16 }}>
          <Text style={styles.label}>Sleep Duration (hours)</Text>
          <Slider
            style={{ width: '100%', height: 40 }}
            minimumValue={1}
            maximumValue={24}
            step={0.5}
            value={sleepHours}
            onValueChange={setSleepHours}
            minimumTrackTintColor="#007AFF"
            maximumTrackTintColor="#ccc"
            thumbTintColor={Platform.OS === 'ios' ? '#007AFF' : undefined}
          />
          <Text style={{ textAlign: 'center', fontSize: 18 }}>{sleepHours} hours</Text>
        </View>
      )}

      {/* Fallback for 'other' */}
      {category === 'other' && (
        <>
          <Text style={styles.label}>Value/Description</Text>
          <TextInput style={styles.input} placeholder="e.g. 7h, 30min, 5/10 mood" value={duration} onChangeText={setDuration} />
        </>
      )}

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
  emojiBtn: {
    padding: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ccc',
    marginHorizontal: 4,
    backgroundColor: '#fff',
    width: 64,
    alignItems: 'center',
  },
  emojiBtnActive: {
    borderColor: '#007AFF',
    backgroundColor: '#E3F0FF',
  },
  quickBtn: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 8,
    backgroundColor: '#eee',
    marginRight: 8,
    marginBottom: 8,
  },
});
