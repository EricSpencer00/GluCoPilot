import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Card, Text, ActivityIndicator, Button } from 'react-native-paper';

// Interfaces
interface GlucoseReading {
  value: number;
  timestamp: string;
  trend: string;
  is_high: boolean;
  is_low: boolean;
}

interface GlucoseCardProps {
  reading: GlucoseReading | null;
  isLoading: boolean;
  onSync: () => void;
}

export const GlucoseCard: React.FC<GlucoseCardProps> = ({ 
  reading, 
  isLoading,
  onSync
}) => {
  const getGlucoseColor = () => {
    if (!reading) return '#212121';
    if (reading.is_low) return '#E53935';  // Critical Red
    if (reading.is_high) return '#FFB74D'; // Warning Orange
    return '#00796B';  // Deep Teal for in range
  };

  const getTrendIcon = () => {
    console.log(`Reading trend: ${reading.trend}`);
    if (!reading) return null;
    // Use Unicode diagonal arrows for rising/falling, fallback to text if not supported
    switch(reading.trend) {
      case 'rising_quickly':
        return '⬈⬈'; // double northeast
      case 'rising':
        return '⬈'; // northeast arrow U+2B08
      case 'stable':
        return '→'; // right arrow
      case 'falling':
        return '⬊'; // southeast arrow U+2B0A
      case 'falling_quickly':
        return '⬊⬊'; // double southeast
      default:
        return null;
    }
  };

  const formatTime = (timestamp: string) => {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };
  
  return (
    <Card style={styles.card}>
      <Card.Content style={styles.content}>
        <View style={styles.headerRow}>
          <Text variant="titleMedium" style={styles.title}>Current Glucose</Text>
          <Button
            mode="contained"
            onPress={onSync}
            disabled={isLoading}
            style={styles.syncButton}
            labelStyle={styles.syncButtonLabel}
          >
            Sync
          </Button>
        </View>
        
        {isLoading ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" style={styles.loader} />
            <Text>Loading data...</Text>
          </View>
        ) : reading ? (
          <View style={styles.readingContainer}>
            <View style={styles.valueContainer}>
              <Text 
                variant="displayLarge" 
                style={[styles.value, { color: getGlucoseColor(), flexDirection: 'row', alignItems: 'center' }]}
              >
                {reading.value}
                {getTrendIcon() && (
                  <Text style={[styles.trend, { marginLeft: 10, marginTop: 0, fontSize: 36 }]}>
                    {getTrendIcon()}
                  </Text>
                )}
              </Text>
            </View>
            <Text variant="bodyMedium" style={styles.timestamp}>
              as of {formatTime(reading.timestamp)}
            </Text>
          </View>
        ) : (
          <View style={styles.noDataContainer}>
            <Text variant="bodyLarge">No data available</Text>
            <Button
              mode="contained"
              onPress={onSync}
              style={styles.syncButton}
              labelStyle={styles.syncButtonLabel}
            >
              Sync Now
            </Button>
          </View>
        )}
      </Card.Content>
    </Card>
  );
};

const styles = StyleSheet.create({
  card: {
    marginVertical: 8,
    borderRadius: 16,
    elevation: 4,
    backgroundColor: '#FFFFFF',
    shadowColor: '#00796B',
    shadowOpacity: 0.08,
    shadowRadius: 8,
  },
  content: {
    padding: 8,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  title: {
    fontWeight: 'bold',
    color: '#00796B',
    fontSize: 18,
  },
  loadingContainer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  loader: {
    marginVertical: 12,
  },
  readingContainer: {
    alignItems: 'center',
    paddingVertical: 12,
  },
  valueContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  value: {
    fontWeight: 'bold',
    fontSize: 36,
    color: '#00796B',
  },
  trend: {
    marginLeft: 8,
    marginTop: 16,
    color: '#FF8A65',
    fontSize: 28,
  },
  timestamp: {
    marginTop: 8,
    color: '#757575',
    fontSize: 14,
  },
  noDataContainer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  syncButton: {
    marginTop: 16,
    borderRadius: 8,
    backgroundColor: '#FF8A65',
    elevation: 2,
  },
  syncButtonLabel: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontSize: 15,
  },
});
