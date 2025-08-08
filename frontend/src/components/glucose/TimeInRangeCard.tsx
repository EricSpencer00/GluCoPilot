import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Card, Text, ActivityIndicator, ProgressBar } from 'react-native-paper';

// Interfaces
interface GlucoseStats {
  time_in_range: number;
  time_below_range: number;
  time_above_range: number;
  avg_glucose: number;
}

interface TimeInRangeCardProps {
  stats: GlucoseStats | null;
  isLoading: boolean;
}

export const TimeInRangeCard: React.FC<TimeInRangeCardProps> = ({ 
  stats, 
  isLoading
}) => {
  return (
    <Card style={styles.card}>
      <Card.Content>
        <Text variant="titleMedium" style={styles.title}>
          Time in Range
        </Text>
        
        {isLoading ? (
          <ActivityIndicator size="large" style={styles.loader} />
        ) : stats ? (
          <View style={styles.statsContainer}>
            <View style={styles.percentageRow}>
              <Text variant="displayMedium" style={styles.percentValue}>
                {Math.round(stats.time_in_range)}%
              </Text>
              <Text variant="bodyLarge" style={styles.avgGlucose}>
                Avg: {Math.round(stats.avg_glucose)}
              </Text>
            </View>
            
            <View style={styles.barContainer}>
              <View style={[styles.progressSegment, styles.lowSegment, { flex: stats.time_below_range }]} />
              <View style={[styles.progressSegment, styles.inRangeSegment, { flex: stats.time_in_range }]} />
              <View style={[styles.progressSegment, styles.highSegment, { flex: stats.time_above_range }]} />
            </View>
            
            <View style={styles.legendContainer}>
              <View style={styles.legendItem}>
                <View style={[styles.legendColor, styles.lowColor]} />
                <Text variant="bodySmall">{Math.round(stats.time_below_range)}% Low</Text>
              </View>
              <View style={styles.legendItem}>
                <View style={[styles.legendColor, styles.inRangeColor]} />
                <Text variant="bodySmall">{Math.round(stats.time_in_range)}% In Range</Text>
              </View>
              <View style={styles.legendItem}>
                <View style={[styles.legendColor, styles.highColor]} />
                <Text variant="bodySmall">{Math.round(stats.time_above_range)}% High</Text>
              </View>
            </View>
          </View>
        ) : (
          <View style={styles.noDataContainer}>
            <Text variant="bodyLarge">No data available</Text>
          </View>
        )}
      </Card.Content>
    </Card>
  );
};

const styles = StyleSheet.create({
  card: {
    marginVertical: 8,
    borderRadius: 12,
    elevation: 2,
  },
  title: {
    fontWeight: 'bold',
    marginBottom: 12,
  },
  loader: {
    marginVertical: 24,
  },
  statsContainer: {
    marginVertical: 8,
  },
  percentageRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    marginBottom: 12,
  },
  percentValue: {
    fontWeight: 'bold',
    color: '#4CAF50',
  },
  avgGlucose: {
    opacity: 0.7,
  },
  barContainer: {
    flexDirection: 'row',
    height: 12,
    borderRadius: 6,
    overflow: 'hidden',
    marginBottom: 8,
  },
  progressSegment: {
    height: '100%',
  },
  lowSegment: {
    backgroundColor: '#E53935',
  },
  inRangeSegment: {
    backgroundColor: '#4CAF50',
  },
  highSegment: {
    backgroundColor: '#F57C00',
  },
  legendContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  legendColor: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 4,
  },
  lowColor: {
    backgroundColor: '#E53935',
  },
  inRangeColor: {
    backgroundColor: '#4CAF50',
  },
  highColor: {
    backgroundColor: '#F57C00',
  },
  noDataContainer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
});
