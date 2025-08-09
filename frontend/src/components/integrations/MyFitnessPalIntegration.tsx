import React, { useState } from 'react';
import { View, Button, Text } from 'react-native';
import { fetchMyFitnessPalFoodLogs } from '../../services/myfitnesspalService';

export const MyFitnessPalIntegration: React.FC = () => {
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  const handleSync = async () => {
    setLoading(true);
    try {
      const today = new Date().toISOString().slice(0, 10);
      const logs = await fetchMyFitnessPalFoodLogs(today, today);
      setLogs(logs);
    } catch (e) {
      setLogs([]);
    }
    setLoading(false);
  };

  return (
    <View>
      <Button title="Sync MyFitnessPal Food Logs" onPress={handleSync} disabled={loading} />
      {logs.length > 0 && logs.map((log, idx) => (
        <Text key={idx}>{JSON.stringify(log)}</Text>
      ))}
    </View>
  );
};
