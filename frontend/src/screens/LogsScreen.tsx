import React from 'react';
import { View, ScrollView } from 'react-native';
import { Card, Text, List } from 'react-native-paper';
import { useSelector } from 'react-redux';
import { RootState } from '../store/store';

export const LogsScreen: React.FC = () => {
  const { readings } = useSelector((state: RootState) => state.glucose);
  // You can add food and insulin logs here as well if available in Redux

  return (
    <ScrollView style={{ flex: 1, backgroundColor: '#fff' }}>
      <Text variant="headlineMedium" style={{ margin: 16 }}>Logs</Text>
      <Card style={{ margin: 16 }}>
        <Card.Content>
          <Text variant="titleMedium">Glucose Readings</Text>
          {readings.length === 0 ? (
            <Text style={{ marginTop: 8 }}>No readings available.</Text>
          ) : (
            readings.map((reading: any, idx: number) => (
              <List.Item
                key={reading.id || idx}
                title={`BG: ${reading.value} mg/dL`}
                description={`Time: ${new Date(reading.timestamp).toLocaleString()}`}
                left={props => <List.Icon {...props} icon="water" />}
              />
            ))
          )}
        </Card.Content>
      </Card>
      {/* Add food and insulin logs here if available */}
    </ScrollView>
  );
};
