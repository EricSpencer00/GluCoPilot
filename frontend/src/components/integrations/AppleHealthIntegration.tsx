
import React, { useState } from 'react';
import { View, Button, Text, ScrollView, StyleSheet } from 'react-native';
import { fetchAppleHealthActivity } from '../../services/appleHealthService';

export const AppleHealthIntegration: React.FC = () => {
  const [activity, setActivity] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const handleSync = async () => {
    setLoading(true);
    try {
      const today = new Date().toISOString().slice(0, 10);
      const data = await fetchAppleHealthActivity(today, today);
      setActivity(data);
    } catch (e) {
      setActivity(null);
    }
    setLoading(false);
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.info}>
        To sync MyFitnessPal data, enable sharing from MyFitnessPal to Apple Health in your device settings. Activity, calories, and workouts logged in MyFitnessPal will appear here if shared.
      </Text>
      <Button title="Sync Apple Health Activity" onPress={handleSync} disabled={loading} />
      {activity && (
        <View style={styles.activityContainer}>
          <Text style={styles.sectionTitle}>Activity Data</Text>
          {activity.steps && (
            <Text style={styles.item}>Steps: {activity.steps} <Text style={styles.source}>(Source: Apple Health/MyFitnessPal)</Text></Text>
          )}
          {activity.workouts && Array.isArray(activity.workouts) && activity.workouts.map((w: any, idx: number) => (
            <View key={idx} style={styles.workoutItem}>
              <Text style={styles.item}>Workout: {w.type} ({w.duration_min} min, {w.calories} kcal)</Text>
              <Text style={styles.source}>Source: {w.source || 'Apple Health/MyFitnessPal'}</Text>
            </View>
          ))}
          {activity.heart_rate && (
            <Text style={styles.item}>Heart Rate: {JSON.stringify(activity.heart_rate)}</Text>
          )}
          {activity.sleep && (
            <Text style={styles.item}>Sleep: {activity.sleep.duration_hr} hr, Quality: {activity.sleep.quality}</Text>
          )}
        </View>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: 16,
    backgroundColor: '#fff',
  },
  info: {
    marginBottom: 16,
    color: '#555',
    fontSize: 15,
  },
  sectionTitle: {
    fontWeight: 'bold',
    fontSize: 17,
    marginBottom: 8,
  },
  activityContainer: {
    marginTop: 16,
  },
  item: {
    fontSize: 15,
    marginBottom: 4,
  },
  source: {
    fontSize: 12,
    color: '#888',
  },
  workoutItem: {
    marginBottom: 8,
  },
});
