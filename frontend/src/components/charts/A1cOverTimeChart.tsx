import React from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { Text } from 'react-native-paper';
import { LineChart } from 'react-native-chart-kit';

interface A1cOverTimeChartProps {
  weeks?: { [week: string]: { estimated_a1c: number } };
  height?: number;
}

export const A1cOverTimeChart: React.FC<A1cOverTimeChartProps> = ({ weeks = {}, height = 200 }) => {
  const screenWidth = Dimensions.get('window').width - 32;
  const weekLabels = Object.keys(weeks);
  const a1cValues = weekLabels.map(week => weeks[week]?.estimated_a1c ?? null);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>A1C Over Time (Weekly)</Text>
      <LineChart
        data={{
          labels: weekLabels,
          datasets: [
            {
              data: a1cValues,
              color: (opacity = 1) => `rgba(76, 175, 80, ${opacity})`,
              strokeWidth: 2,
            },
          ],
        }}
        width={screenWidth}
        height={height}
        chartConfig={{
          backgroundColor: '#fff',
          backgroundGradientFrom: '#fff',
          backgroundGradientTo: '#fff',
          decimalPlaces: 2,
          color: (opacity = 1) => `rgba(76, 175, 80, ${opacity})`,
          labelColor: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
          style: { borderRadius: 16 },
          propsForDots: {
            r: '4',
            strokeWidth: '1',
            stroke: '#4CAF50',
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
        yAxisInterval={1}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: 12,
  },
  title: {
    fontWeight: 'bold',
    fontSize: 16,
    marginBottom: 8,
  },
  chart: {
    borderRadius: 16,
  },
});
