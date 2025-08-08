import React from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { Text, ActivityIndicator } from 'react-native-paper';
import { LineChart } from 'react-native-chart-kit';

// Interfaces
interface GlucoseReading {
  value: number;
  timestamp: string;
}

interface TrendChartProps {
  data: GlucoseReading[];
  isLoading: boolean;
  height?: number;
}

export const TrendChart: React.FC<TrendChartProps> = ({ 
  data, 
  isLoading,
  height = 220
}) => {
  const screenWidth = Dimensions.get('window').width - 50;
  
  const formatTimestamp = (timestamp: string) => {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };
  
  const getChartData = () => {
    if (!data || data.length === 0) {
      return {
        labels: ['No Data'],
        datasets: [{ data: [0] }]
      };
    }
    
    // Take only the last 24 readings if there are more (1 reading per hour)
    const chartData = data.slice(-24);
    
    return {
      labels: chartData.map(reading => formatTimestamp(reading.timestamp)),
      datasets: [
        {
          data: chartData.map(reading => reading.value),
          color: (opacity = 1) => `rgba(66, 133, 244, ${opacity})`,
          strokeWidth: 2,
        }
      ]
    };
  };
  
  return (
    <View style={styles.container}>
      {isLoading ? (
        <ActivityIndicator size="large" style={styles.loader} />
      ) : data && data.length > 0 ? (
        <LineChart
          data={getChartData()}
          width={screenWidth}
          height={height}
          chartConfig={{
            backgroundColor: '#fff',
            backgroundGradientFrom: '#fff',
            backgroundGradientTo: '#fff',
            decimalPlaces: 0,
            color: (opacity = 1) => `rgba(66, 133, 244, ${opacity})`,
            labelColor: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
            style: {
              borderRadius: 16,
            },
            propsForDots: {
              r: '4',
              strokeWidth: '1',
              stroke: '#4285F4',
            },
            propsForBackgroundLines: {
              strokeDasharray: '',
              stroke: '#e0e0e0',
            },
          }}
          bezier
          style={styles.chart}
          withDots={true}
          withShadow={false}
          withInnerLines={true}
          withOuterLines={true}
          fromZero={false}
          yAxisSuffix=""
          yAxisInterval={50}
        />
      ) : (
        <View style={[styles.noDataContainer, { height }]}>
          <Text variant="bodyLarge">No data available</Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  loader: {
    marginVertical: 24,
  },
  chart: {
    marginVertical: 8,
    borderRadius: 16,
  },
  noDataContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
    backgroundColor: '#f9f9f9',
    borderRadius: 16,
  },
});
