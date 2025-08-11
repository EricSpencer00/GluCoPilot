import React, { useState } from 'react';
import { View, StyleSheet, Dimensions, TouchableOpacity, PanResponder } from 'react-native';
import { Text, ActivityIndicator, Surface } from 'react-native-paper';
import Svg, { Circle, Line, G, Text as SvgText } from 'react-native-svg';

// Interfaces
interface GlucoseReading {
  value: number;
  timestamp: string;
}

interface DexcomStyleChartProps {
  data: GlucoseReading[];
  isLoading: boolean;
  height?: number;
  timeRange?: '3h' | '6h' | '12h' | '24h';
  onTimeRangeChange?: (range: '3h' | '6h' | '12h' | '24h') => void;
}

interface TouchPoint {
  x: number;
  y: number;
  value: number;
  timestamp: string;
}

export const DexcomStyleChart: React.FC<DexcomStyleChartProps> = ({ 
  data, 
  isLoading,
  height = 220,
  timeRange = '3h',
  onTimeRangeChange
}) => {
  const screenWidth = Dimensions.get('window').width - 32;
  const [activeTouchPoint, setActiveTouchPoint] = useState<TouchPoint | null>(null);

  // Define ranges for chart visualization
  const TARGET_RANGE_MIN = 70;
  const TARGET_RANGE_MAX = 180;
  const MIN_VALUE_DISPLAY = 40;
  const MAX_VALUE_DISPLAY = 400;

  // Get filtered data based on time range, and fill missing 5-min intervals with nulls
  const getFilledData = () => {
    const now = new Date();
    let hoursToShow = 3;
    if (timeRange === '6h') hoursToShow = 6;
    else if (timeRange === '12h') hoursToShow = 12;
    else if (timeRange === '24h') hoursToShow = 24;

    const startTime = new Date(now.getTime() - (hoursToShow * 60 * 60 * 1000));
    // Build a map of available data by rounded timestamp
    const dataMap = new Map();
    if (data && data.length > 0) {
      data.forEach(reading => {
        const d = new Date(reading.timestamp);
        // Round down to nearest 5 min
        d.setSeconds(0, 0);
        d.setMinutes(Math.floor(d.getMinutes() / 5) * 5);
        dataMap.set(d.getTime(), reading);
      });
    }
    // Generate all expected 5-min interval timestamps
    const filled = [];
    const intervalMs = 5 * 60 * 1000;
    for (let t = startTime.getTime(); t <= now.getTime(); t += intervalMs) {
      if (dataMap.has(t)) {
        filled.push(dataMap.get(t));
      } else {
        // Insert a null/placeholder for missing data
        filled.push({ value: null, timestamp: new Date(t).toISOString() });
      }
    }
    return filled;
  };

  // Format timestamps in a user-friendly way
  const formatTimestamp = (timestamp: string) => {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  // Convert glucose value to Y coordinate
  const valueToYCoordinate = (value: number): number => {
    const chartHeight = height - 60; // Subtracting padding
    const valueRange = MAX_VALUE_DISPLAY - MIN_VALUE_DISPLAY;
    
    const percentage = Math.max(0, Math.min(1, (MAX_VALUE_DISPLAY - value) / valueRange));
    return 30 + (percentage * chartHeight);
  };

  // Generate chart points and x-axis labels, with spacers for missing data
  const getChartPoints = (): { points: TouchPoint[], gridLines: number[], xLabels: { x: number, label: string }[] } => {
    const filledData = getFilledData();
    const points: TouchPoint[] = [];
    const chartWidth = screenWidth - 40; // Padding

    // Calculate points (left = oldest, right = most recent)
    filledData.forEach((reading, index) => {
      if (reading.value !== null && reading.value !== undefined) {
        const x = 20 + (index / (filledData.length - 1 || 1)) * chartWidth;
        const y = valueToYCoordinate(reading.value);
        points.push({
          x,
          y,
          value: reading.value,
          timestamp: reading.timestamp
        });
      }
    });

    // Generate grid lines at every 50 mg/dL
    const gridLines = [];
    for (let value = 50; value <= 350; value += 50) {
      gridLines.push(value);
    }

    // X-axis time labels (show 4 evenly spaced labels, always present)
    const xLabels: { x: number, label: string }[] = [];
    const labelCount = 4;
    const now = new Date();
    let hoursToShow = 3;
    if (timeRange === '6h') hoursToShow = 6;
    else if (timeRange === '12h') hoursToShow = 12;
    else if (timeRange === '24h') hoursToShow = 24;
    const startTime = new Date(now.getTime() - (hoursToShow * 60 * 60 * 1000));
    for (let i = 0; i < labelCount; i++) {
      const frac = i / (labelCount - 1);
      const x = 20 + frac * chartWidth;
      // For label, interpolate time between start and now
      const labelTime = new Date(startTime.getTime() + frac * (now.getTime() - startTime.getTime()));
      xLabels.push({ x, label: formatTimestamp(labelTime.toISOString()) });
    }

    return { points, gridLines, xLabels };
  };

  // Set up pan responder for touch interactions
  const panResponder = React.useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: (evt, gestureState) => {
        handleTouch(gestureState.x0, gestureState.y0);
      },
      onPanResponderMove: (evt, gestureState) => {
        handleTouch(gestureState.moveX, gestureState.moveY);
      },
      onPanResponderRelease: () => {
        setActiveTouchPoint(null);
      }
    })
  ).current;

  // Handle touch on chart to show reading details
  const handleTouch = (touchX: number, touchY: number) => {
    const { points } = getChartPoints();
    if (points.length === 0) return;

    // Find closest point to touch
    let closestPoint = points[0];
    let minDistance = Number.MAX_VALUE;

    points.forEach(point => {
      const distance = Math.abs(point.x - touchX);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    });

    // Only activate if touch is close enough (within 30px)
    if (minDistance < 30) {
      setActiveTouchPoint(closestPoint);
    } else {
      setActiveTouchPoint(null);
    }
  };

  // Get color for glucose reading
  const getReadingColor = (value: number) => {
    if (value < TARGET_RANGE_MIN) return '#E53935'; // Red for low
    if (value > TARGET_RANGE_MAX) return '#F57C00'; // Orange for high
    return '#4CAF50'; // Green for in range
  };

  const { points, gridLines, xLabels } = getChartPoints();

  return (
    <View style={styles.container}>
      {isLoading ? (
        <ActivityIndicator size="large" style={styles.loader} />
      ) : (
        <View>
          {/* Time range selector */}
          <View style={styles.timeRangeSelector}>
            {(['3h', '6h', '12h', '24h'] as const).map(range => (
              <TouchableOpacity
                key={range}
                style={[
                  styles.timeRangeButton,
                  timeRange === range && styles.activeTimeRange
                ]}
                onPress={() => onTimeRangeChange?.(range)}
              >
                <Text
                  style={[
                    styles.timeRangeText,
                    timeRange === range && styles.activeTimeRangeText
                  ]}
                >
                  {range}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Main chart */}
          <Surface style={[styles.chartContainer, { height }]}> 
            <View {...panResponder.panHandlers} style={{ flex: 1 }}>
              <Svg height={height} width={screenWidth}>
                {/* X-axis time labels (always present, padded) */}
                {xLabels.map((labelObj, idx) => (
                  <SvgText
                    key={`x-label-${idx}`}
                    x={labelObj.x}
                    y={height - 2}
                    fontSize="10"
                    fill="#888"
                    textAnchor={idx === 0 ? "start" : idx === xLabels.length - 1 ? "end" : "middle"}
                  >
                    {labelObj.label}
                  </SvgText>
                ))}
                {/* Grid lines */}
                {gridLines.map(value => (
                  <Line
                    key={`grid-${value}`}
                    x1="20"
                    y1={valueToYCoordinate(value)}
                    x2={screenWidth - 20}
                    y2={valueToYCoordinate(value)}
                    stroke="#E0E0E0"
                    strokeWidth="1"
                    strokeDasharray={value === TARGET_RANGE_MIN || value === TARGET_RANGE_MAX ? "" : "4,4"}
                  />
                ))}

                {/* Grid line labels */}
                {gridLines.map(value => (
                  <SvgText
                    key={`label-${value}`}
                    x="10"
                    y={valueToYCoordinate(value) + 4}
                    fontSize="10"
                    fill="#888"
                    textAnchor="start"
                  >
                    {value}
                  </SvgText>
                ))}

                {/* Target range zone */}
                <G>
                  <Line
                    x1="20"
                    y1={valueToYCoordinate(TARGET_RANGE_MIN)}
                    x2={screenWidth - 20}
                    y2={valueToYCoordinate(TARGET_RANGE_MIN)}
                    stroke="#4CAF50"
                    strokeWidth="1.5"
                  />
                  <Line
                    x1="20"
                    y1={valueToYCoordinate(TARGET_RANGE_MAX)}
                    x2={screenWidth - 20}
                    y2={valueToYCoordinate(TARGET_RANGE_MAX)}
                    stroke="#4CAF50"
                    strokeWidth="1.5"
                  />
                </G>

                {/* Data points (skip nulls) */}
                {points.map((point, index) => (
                  <Circle
                    key={`point-${index}`}
                    cx={point.x}
                    cy={point.y}
                    r="3"
                    fill={getReadingColor(point.value)}
                  />
                ))}

                {/* Active touch point */}
                {activeTouchPoint && (
                  <G>
                    <Circle
                      cx={activeTouchPoint.x}
                      cy={activeTouchPoint.y}
                      r="6"
                      fill={getReadingColor(activeTouchPoint.value)}
                      stroke="#fff"
                      strokeWidth="2"
                    />
                    <SvgText
                      x={activeTouchPoint.x}
                      y={activeTouchPoint.y - 15}
                      fontSize="12"
                      fontWeight="bold"
                      fill="#000"
                      textAnchor="middle"
                    >
                      {activeTouchPoint.value}
                    </SvgText>
                    <SvgText
                      x={activeTouchPoint.x}
                      y={height - 10}
                      fontSize="10"
                      fill="#555"
                      textAnchor="middle"
                    >
                      {formatTimestamp(activeTouchPoint.timestamp)}
                    </SvgText>
                  </G>
                )}
              </Svg>
            </View>
          </Surface>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
  },
  loader: {
    marginVertical: 24,
  },
  chartContainer: {
    marginVertical: 8,
    borderRadius: 16,
    backgroundColor: '#FFFFFF',
    elevation: 4,
    shadowColor: '#00796B',
    shadowOpacity: 0.08,
    shadowRadius: 8,
  },
  noDataContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
    backgroundColor: '#E0E0E0',
    borderRadius: 16,
  },
  timeRangeSelector: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
    backgroundColor: '#E0E0E0',
    borderRadius: 8,
    padding: 2,
  },
  timeRangeButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 6,
    borderRadius: 6,
  },
  activeTimeRange: {
    backgroundColor: '#FF8A65',
    elevation: 2,
  },
  timeRangeText: {
    fontSize: 12,
    color: '#757575',
  },
  activeTimeRangeText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
});
