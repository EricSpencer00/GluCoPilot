import React, { useState } from 'react';
import { View, ScrollView, Platform } from 'react-native';
import { Card, Text, Button } from 'react-native-paper';
import DateTimePicker from '@react-native-community/datetimepicker';
import { styles } from '../styles/screens/TrendsScreen';
import { useDexcomTrends } from '../hooks/useDexcomTrends';
import { A1cOverTimeChart } from '../components/charts/A1cOverTimeChart';
import { LoadingScreen } from '../components/common/LoadingScreen';

export const TrendsScreen: React.FC = () => {
  const [startDate, setStartDate] = useState<Date | null>(null);
  const [endDate, setEndDate] = useState<Date | null>(null);
  const [showStartPicker, setShowStartPicker] = useState(false);
  const [showEndPicker, setShowEndPicker] = useState(false);
  const DEFAULT_DAYS = 30;

  // Fallback: if no dates selected, use last 30 days
  let days = DEFAULT_DAYS;
  if (startDate && endDate) {
    const diff = Math.max(1, Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)));
    days = diff;
  } else if (startDate) {
    const diff = Math.max(1, Math.ceil((new Date().getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)));
    days = diff;
  }
  const { trends, loading, error } = useDexcomTrends(days, startDate, endDate);

  // Handlers for date pickers
  const onChangeStart = (event: any, date?: Date) => {
    setShowStartPicker(Platform.OS === 'ios');
    if (date) {
      setStartDate(date);
      // If endDate is before startDate, reset endDate
      if (endDate && date > endDate) setEndDate(null);
    }
  };
  const onChangeEnd = (event: any, date?: Date) => {
    setShowEndPicker(Platform.OS === 'ios');
    if (date) {
      setEndDate(date);
    }
  };

  if (loading) {
    return (
      <View style={{ flex: 1, backgroundColor: '#fff', justifyContent: 'center', alignItems: 'center' }}>
        <LoadingScreen />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <Text variant="headlineMedium" style={styles.header}>Trends</Text>

      <Card style={styles.chartCard}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>Select Date Range</Text>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 }}>
            <Button mode="outlined" onPress={() => setShowStartPicker(true)}>
              {startDate ? startDate.toLocaleDateString() : 'Start Date'}
            </Button>
            <Button mode="outlined" onPress={() => setShowEndPicker(true)}>
              {endDate ? endDate.toLocaleDateString() : 'End Date'}
            </Button>
          </View>
          {showStartPicker && (
            <DateTimePicker
              value={startDate || new Date()}
              mode="date"
              display="default"
              onChange={onChangeStart}
              maximumDate={endDate || new Date()}
            />
          )}
          {showEndPicker && (
            <DateTimePicker
              value={endDate || new Date()}
              mode="date"
              display="default"
              onChange={onChangeEnd}
              minimumDate={startDate || undefined}
              maximumDate={new Date()}
            />
          )}
        </Card.Content>
      </Card>

      {error ? (
        <Text style={{ color: 'red', margin: 16 }}>{error}</Text>
      ) : trends ? (
        <>
          {/* Overall Stats */}
          <Card style={styles.chartCard}>
            <Card.Content>
              <Text variant="titleMedium" style={styles.cardTitle}>Overall ({startDate && endDate ? `${startDate.toLocaleDateString()} - ${endDate.toLocaleDateString()}` : `Last ${days} Days`})</Text>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between' }}>
                {trends && trends.overall && typeof trends.overall === 'object' && Object.entries(trends.overall).map(([key, value]) => (
                  <View key={key} style={{ margin: 8, minWidth: 120 }}>
                    <Text style={{ fontWeight: 'bold' }}>{key.replace(/_/g, ' ').toUpperCase()}</Text>
                    <Text>{String(value)}</Text>
                  </View>
                ))}
              </View>
            </Card.Content>
          </Card>

          {/* A1C Over Time Chart */}
          <Card style={styles.chartCard}>
            <Card.Content>
              <A1cOverTimeChart weeks={trends && trends.weeks ? trends.weeks : {}} />
            </Card.Content>
          </Card>

          {/* Weekly Stats Table */}
          <Card style={styles.chartCard}>
            <Card.Content>
              <Text variant="titleMedium" style={styles.cardTitle}>Weekly Stats</Text>
              <ScrollView horizontal>
                <View>
                  <View style={{ flexDirection: 'row', borderBottomWidth: 1, borderColor: '#eee' }}>
                    <Text style={{ width: 80, fontWeight: 'bold' }}>Week</Text>
                    {trends && trends.overall && Object.keys(trends.overall).map((stat) => (
                      <Text key={`header-${stat}`} style={{ width: 100, fontWeight: 'bold', textAlign: 'center' }}>{stat.replace(/_/g, ' ').toUpperCase()}</Text>
                    ))}
                  </View>
                  {trends && trends.weeks && Object.entries(trends.weeks).map(([week, stats]: any) => (
                    <View key={week} style={{ flexDirection: 'row', borderBottomWidth: 1, borderColor: '#f5f5f5' }}>
                      <Text style={{ width: 80 }}>{week.replace('week_', 'Week ')}</Text>
                      {trends.overall && Object.keys(trends.overall).map((stat) => (
                        <Text key={`${week}-${stat}`} style={{ width: 100, textAlign: 'center' }}>{stats[stat]}</Text>
                      ))}
                    </View>
                  ))}
                </View>
              </ScrollView>
            </Card.Content>
          </Card>

        </>
      ) : null}
    </ScrollView>
  );
}
