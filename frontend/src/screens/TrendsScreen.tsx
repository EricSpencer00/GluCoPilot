import React from 'react';
import { View, ScrollView } from 'react-native';
import { Card, Text, ActivityIndicator } from 'react-native-paper';
import { useSelector } from 'react-redux';
import { RootState } from '../store/store';
import { TrendChart } from '../components/charts/TrendChart';
import { TimeInRangeCard } from '../components/glucose/TimeInRangeCard';
import { styles } from '../styles/screens/TrendsScreen';

export const TrendsScreen: React.FC = () => {
  const { readings, stats, isLoading } = useSelector((state: RootState) => state.glucose);

  return (
    <ScrollView style={styles.container}>
      <Text variant="headlineMedium" style={styles.header}>Trends</Text>
      <TimeInRangeCard stats={stats} isLoading={isLoading} />
      <Card style={styles.chartCard}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>24-Hour Glucose Trend</Text>
          <TrendChart data={readings} isLoading={isLoading} height={220} />
        </Card.Content>
      </Card>
      {/* Add more trend visualizations as needed */}
    </ScrollView>
  );
};
