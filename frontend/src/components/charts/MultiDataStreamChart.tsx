import React from 'react';
import { View, StyleSheet, Dimensions, ScrollView } from 'react-native';
import { Text, Surface, ActivityIndicator } from 'react-native-paper';
import Svg, { Circle, Line, Path, G, Text as SvgText, Rect } from 'react-native-svg';

// Types
interface DataPoint {
  timestamp: string;
  glucose?: number;
  insulin?: number;
  carbs?: number;
  activity?: number;
  sleep?: number;
  mood?: number;
}

interface CorrelationChartProps {
  data: DataPoint[];
  height?: number;
  width?: number;
  isLoading?: boolean;
  showGlucose?: boolean;
  showInsulin?: boolean;
  showFood?: boolean;
  showActivity?: boolean;
  showSleep?: boolean;
  showMood?: boolean;
  timeRange?: '24h' | '3d' | '7d' | '14d' | '30d';
}

export const MultiDataStreamChart: React.FC<CorrelationChartProps> = ({
  data,
  height = 300,
  width = Dimensions.get('window').width - 32,
  isLoading = false,
  showGlucose = true,
  showInsulin = false,
  showFood = false,
  showActivity = false,
  showSleep = false,
  showMood = false,
  timeRange = '24h'
}) => {
  // Constants for chart layout and scaling
  const PADDING = { top: 20, right: 20, bottom: 40, left: 50 };
  const chartWidth = width - PADDING.left - PADDING.right;
  const chartHeight = height - PADDING.top - PADDING.bottom;

  // Helper function to get the max value for each data type
  const getMaxValues = () => {
    const maxValues = {
      glucose: showGlucose ? Math.max(...data.filter(d => d.glucose !== undefined).map(d => d.glucose!), 200) : 0,
      insulin: showInsulin ? Math.max(...data.filter(d => d.insulin !== undefined).map(d => d.insulin!), 10) : 0,
      carbs: showFood ? Math.max(...data.filter(d => d.carbs !== undefined).map(d => d.carbs!), 100) : 0,
      activity: showActivity ? Math.max(...data.filter(d => d.activity !== undefined).map(d => d.activity!), 60) : 0,
      sleep: showSleep ? Math.max(...data.filter(d => d.sleep !== undefined).map(d => d.sleep!), 10) : 0,
      mood: showMood ? Math.max(...data.filter(d => d.mood !== undefined).map(d => d.mood!), 10) : 0
    };
    return maxValues;
  };

  // Scales for each data type to normalize them in the same chart
  const getScaledValue = (value: number, dataType: keyof typeof scales) => {
    return chartHeight - (value / scales[dataType]) * chartHeight;
  };

  // Get the X position for a data point
  const getXPosition = (index: number) => {
    return PADDING.left + (index / (data.length - 1)) * chartWidth;
  };

  // Format timestamp
  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  // Format date
  const formatDate = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
  };

  // Get tick values for Y axis
  const getYAxisTicks = (maxValue: number, count: number = 5) => {
    const ticks = [];
    const step = maxValue / (count - 1);
    for (let i = 0; i < count; i++) {
      ticks.push(Math.round(i * step));
    }
    return ticks;
  };

  // Get X axis ticks (timestamps)
  const getXAxisTicks = () => {
    if (data.length <= 1) return [];
    
    const tickCount = Math.min(6, data.length);
    const step = Math.floor((data.length - 1) / (tickCount - 1));
    const ticks = [];
    
    for (let i = 0; i < tickCount; i++) {
      const dataIndex = i * step;
      if (dataIndex < data.length) {
        ticks.push({
          x: getXPosition(dataIndex),
          label: i === 0 || i === tickCount - 1 ? formatDate(data[dataIndex].timestamp) : formatTimestamp(data[dataIndex].timestamp)
        });
      }
    }
    
    return ticks;
  };

  // Calculate scales for each data type
  const maxValues = getMaxValues();
  const scales = {
    glucose: maxValues.glucose,
    insulin: maxValues.insulin,
    carbs: maxValues.carbs,
    activity: maxValues.activity,
    sleep: maxValues.sleep,
    mood: maxValues.mood
  };

  // Generate path strings for each data type
  const generatePath = (dataType: 'glucose' | 'insulin' | 'carbs' | 'activity' | 'sleep' | 'mood') => {
    const points = data
      .filter(d => d[dataType] !== undefined)
      .map((d, i) => {
        const filteredData = data.filter(item => item[dataType] !== undefined);
        const index = filteredData.indexOf(d);
        const x = getXPosition(index / (filteredData.length - 1) * (data.length - 1));
        const y = getScaledValue(d[dataType]!, dataType);
        return `${i === 0 ? 'M' : 'L'} ${x} ${y}`;
      })
      .join(' ');
    
    return points;
  };

  // Colors for each data stream
  const colors = {
    glucose: '#4CAF50',  // Green
    insulin: '#2196F3',  // Blue
    carbs: '#FF9800',    // Orange
    activity: '#9C27B0', // Purple
    sleep: '#607D8B',    // Blue Gray
    mood: '#F44336'      // Red
  };

  // Generate the legend
  const renderLegend = () => {
    const legendItems = [
      { key: 'glucose', label: 'Glucose', show: showGlucose },
      { key: 'insulin', label: 'Insulin', show: showInsulin },
      { key: 'carbs', label: 'Carbs', show: showFood },
      { key: 'activity', label: 'Activity', show: showActivity },
      { key: 'sleep', label: 'Sleep', show: showSleep },
      { key: 'mood', label: 'Mood', show: showMood }
    ].filter(item => item.show);

    return (
      <View style={styles.legendContainer}>
        {legendItems.map((item, index) => (
          <View key={item.key} style={styles.legendItem}>
            <View style={[styles.legendColor, { backgroundColor: colors[item.key as keyof typeof colors] }]} />
            <Text style={styles.legendText}>{item.label}</Text>
          </View>
        ))}
      </View>
    );
  };

  if (isLoading) {
    return (
      <View style={[styles.container, { height }]}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  if (!data || data.length === 0) {
    return (
      <View style={[styles.container, { height }]}>
        <Text>No data available</Text>
      </View>
    );
  }

  // Get axis ticks
  const xAxisTicks = getXAxisTicks();
  const yAxisTicks = getYAxisTicks(maxValues.glucose);

  return (
    <View>
      {renderLegend()}
      <Surface style={[styles.chartContainer, { height, width }]}>
        <Svg height={height} width={width}>
          {/* Y-axis line */}
          <Line
            x1={PADDING.left}
            y1={PADDING.top}
            x2={PADDING.left}
            y2={height - PADDING.bottom}
            stroke="#ccc"
            strokeWidth="1"
          />

          {/* X-axis line */}
          <Line
            x1={PADDING.left}
            y1={height - PADDING.bottom}
            x2={width - PADDING.right}
            y2={height - PADDING.bottom}
            stroke="#ccc"
            strokeWidth="1"
          />

          {/* Y-axis ticks and labels (for glucose) */}
          {yAxisTicks.map((tick, i) => (
            <G key={`y-tick-${i}`}>
              <Line
                x1={PADDING.left - 5}
                y1={getScaledValue(tick, 'glucose')}
                x2={PADDING.left}
                y2={getScaledValue(tick, 'glucose')}
                stroke="#ccc"
                strokeWidth="1"
              />
              <SvgText
                x={PADDING.left - 10}
                y={getScaledValue(tick, 'glucose') + 4}
                fontSize="10"
                textAnchor="end"
                fill="#666"
              >
                {tick}
              </SvgText>
            </G>
          ))}

          {/* X-axis ticks and labels */}
          {xAxisTicks.map((tick, i) => (
            <G key={`x-tick-${i}`}>
              <Line
                x1={tick.x}
                y1={height - PADDING.bottom}
                x2={tick.x}
                y2={height - PADDING.bottom + 5}
                stroke="#ccc"
                strokeWidth="1"
              />
              <SvgText
                x={tick.x}
                y={height - PADDING.bottom + 20}
                fontSize="10"
                textAnchor="middle"
                fill="#666"
              >
                {tick.label}
              </SvgText>
            </G>
          ))}

          {/* Data lines */}
          {showGlucose && (
            <Path
              d={generatePath('glucose')}
              stroke={colors.glucose}
              strokeWidth="2"
              fill="none"
            />
          )}

          {showInsulin && (
            <Path
              d={generatePath('insulin')}
              stroke={colors.insulin}
              strokeWidth="2"
              fill="none"
            />
          )}

          {showFood && (
            <Path
              d={generatePath('carbs')}
              stroke={colors.carbs}
              strokeWidth="2"
              fill="none"
            />
          )}

          {showActivity && (
            <Path
              d={generatePath('activity')}
              stroke={colors.activity}
              strokeWidth="2"
              fill="none"
            />
          )}

          {showSleep && (
            <Path
              d={generatePath('sleep')}
              stroke={colors.sleep}
              strokeWidth="2"
              fill="none"
            />
          )}

          {showMood && (
            <Path
              d={generatePath('mood')}
              stroke={colors.mood}
              strokeWidth="2"
              fill="none"
            />
          )}

          {/* Data points for glucose (as an example) */}
          {showGlucose && data
            .filter(d => d.glucose !== undefined)
            .map((point, index) => {
              const filteredData = data.filter(item => item.glucose !== undefined);
              const dataIndex = filteredData.indexOf(point);
              const x = getXPosition(dataIndex / (filteredData.length - 1) * (data.length - 1));
              const y = getScaledValue(point.glucose!, 'glucose');
              
              return (
                <Circle
                  key={`glucose-point-${index}`}
                  cx={x}
                  cy={y}
                  r="3"
                  fill={colors.glucose}
                />
              );
            })}
        </Svg>
      </Surface>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  chartContainer: {
    borderRadius: 16,
    elevation: 4,
    backgroundColor: '#FFFFFF',
    shadowColor: '#00796B',
    shadowOpacity: 0.08,
    shadowRadius: 8,
  },
  legendContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    marginBottom: 8,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 16,
    marginBottom: 4,
  },
  legendColor: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 4,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  legendText: {
    fontSize: 12,
  },
});
