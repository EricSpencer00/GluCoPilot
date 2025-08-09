
import React, { useState } from 'react';
import { View, ScrollView, Platform } from 'react-native';
import { Card, Text, ActivityIndicator, Button } from 'react-native-paper';
import DateTimePicker from '@react-native-community/datetimepicker';
import { styles } from '../styles/screens/TrendsScreen';
import { useDexcomTrends } from '../hooks/useDexcomTrends';
import { A1cOverTimeChart } from '../components/charts/A1cOverTimeChart';

export const TrendsScreen: React.FC = () => {
  const [days, setDays] = useState(30);
  const [showPicker, setShowPicker] = useState(false);
  const [selectedDate, setSelectedDate] = useState<Date>(new Date());
  const { trends, loading, error } = useDexcomTrends(days);

  // Handler for date picker
  const onChange = (event: any, date?: Date) => {
    setShowPicker(Platform.OS === 'ios');
    if (date) {
      setSelectedDate(date);
      // Calculate days from today to selected date
      const diff = Math.max(1, Math.ceil((new Date().getTime() - date.getTime()) / (1000 * 60 * 60 * 24)));
      setDays(diff);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <Text variant="headlineMedium" style={styles.header}>Trends</Text>

      <Card style={styles.chartCard}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>Select Start Date</Text>
          <Button mode="outlined" onPress={() => setShowPicker(true)}>
            {selectedDate.toLocaleDateString()}
          </Button>
          {showPicker && (
            <DateTimePicker
              value={selectedDate}
              mode="date"
              display="default"
              onChange={onChange}
              maximumDate={new Date()}
            />
          )}
        </Card.Content>
      </Card>

      {loading ? (
        <ActivityIndicator size="large" style={{ margin: 24 }} />
      ) : error ? (
        <Text style={{ color: 'red', margin: 16 }}>{error}</Text>
      ) : trends ? (
        <>
          {/* Overall Stats */}
          <Card style={styles.chartCard}>
            <Card.Content>
              <Text variant="titleMedium" style={styles.cardTitle}>Overall (Last {days} Days)</Text>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between' }}>
                {Object.entries(trends.overall).map(([key, value]) => (
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
              <A1cOverTimeChart weeks={trends.weeks} />
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
                    {trends.overall && Object.keys(trends.overall).map((stat, idx) => (
                      <Text key={stat} style={{ width: 100, fontWeight: 'bold', textAlign: 'center' }}>{stat.replace(/_/g, ' ').toUpperCase()}</Text>
                    ))}
                  </View>
                  {Object.entries(trends.weeks).map(([week, stats]: any) => (
                    <View key={week} style={{ flexDirection: 'row', borderBottomWidth: 1, borderColor: '#f5f5f5' }}>
                      <Text style={{ width: 80 }}>{week.replace('week_', 'Week ')}</Text>
                      {trends.overall && Object.keys(trends.overall).map((stat, idx) => (
                        <Text key={stat} style={{ width: 100, textAlign: 'center' }}>{stats[stat]}</Text>
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
};
