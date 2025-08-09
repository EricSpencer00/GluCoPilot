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
    if (!reading) return '#000';
    if (reading.is_low) return '#E53935';  // Red for low
    if (reading.is_high) return '#F57C00'; // Orange for high
    return '#4CAF50';  // Green for in range
  };

  const getTrendIcon = () => {
    if (!reading) return null;
    
    switch(reading.trend) {
      case 'rising_quickly':
        return '↑↑';
      case 'rising':
        return '↑';
      case 'steady':
        return '→';
      case 'falling':
        return '↓';
      case 'falling_quickly':
        return '↓↓';
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
            mode="text"
            onPress={onSync}
            disabled={isLoading}
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
                style={[styles.value, { color: getGlucoseColor() }]}
              >
                {reading.value}
              </Text>
              <Text variant="headlineSmall" style={styles.trend}>
                {getTrendIcon()}
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
    borderRadius: 12,
    elevation: 2,
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
  },
  trend: {
    marginLeft: 8,
    marginTop: 16,
  },
  timestamp: {
    marginTop: 8,
    opacity: 0.7,
  },
  noDataContainer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  syncButton: {
    marginTop: 16,
  },
});
