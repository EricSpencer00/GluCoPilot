import React, { useState } from 'react';
import { View, ScrollView } from 'react-native';
import { Card, Text, ActivityIndicator, Divider, Button, Chip } from 'react-native-paper';
import { useSelector } from 'react-redux';
import { RootState } from '../store/store';
import { DexcomStyleChart } from '../components/charts/DexcomStyleChart';
import { TimeInRangeCard } from '../components/glucose/TimeInRangeCard';
import { enhancedTrendsStyles as styles } from '../styles/screens/EnhancedTrendsScreen';

export const EnhancedTrendsScreen: React.FC = () => {
  const { readings, stats, isLoading } = useSelector((state: RootState) => state.glucose);
  const [timeRange, setTimeRange] = useState<'1h' | '3h' | '6h' | '24h'>('24h');
  
  // Data for daily pattern analysis
  const getDailyPatterns = () => {
    if (!readings || readings.length === 0) return [];
    
    // Group readings by hour of day
    const hourlyData: { [hour: number]: number[] } = {};
    
    readings.forEach(reading => {
      const hour = new Date(reading.timestamp).getHours();
      if (!hourlyData[hour]) {
        hourlyData[hour] = [];
      }
      hourlyData[hour].push(reading.value);
    });
    
    // Calculate average for each hour
    const patterns = [];
    for (let hour = 0; hour < 24; hour++) {
      const values = hourlyData[hour] || [];
      const avg = values.length > 0 
        ? values.reduce((sum, val) => sum + val, 0) / values.length
        : null;
        
      patterns.push({
        hour,
        average: avg ? Math.round(avg) : null,
        count: values.length,
        timeLabel: `${hour === 0 ? 12 : hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'pm' : 'am'}`
      });
    }
    
    return patterns;
  };
  
  const dailyPatterns = getDailyPatterns();
  
  const getPatternColor = (value: number | null) => {
    if (value === null) return '#ccc';
    if (value < 70) return '#E53935';  // Red for low
    if (value > 180) return '#F57C00'; // Orange for high
    return '#4CAF50';                  // Green for in range
  };

  return (
    <ScrollView style={styles.container}>
      <Text variant="headlineMedium" style={styles.header}>Glucose Trends</Text>
      
      {/* Time in Range Card */}
      <TimeInRangeCard stats={stats} isLoading={isLoading} />
      
      {/* Enhanced Dexcom-style Chart */}
      <Card style={styles.chartCard}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>Glucose History</Text>
          <DexcomStyleChart 
            data={readings} 
            isLoading={isLoading} 
            height={250}
            timeRange={timeRange}
            onTimeRangeChange={setTimeRange}
          />
        </Card.Content>
      </Card>
      
      {/* Daily Pattern Analysis */}
      <Card style={styles.chartCard}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>Daily Patterns</Text>
          
          {isLoading ? (
            <ActivityIndicator size="large" style={styles.loader} />
          ) : dailyPatterns.length > 0 ? (
            <View style={styles.patternsContainer}>
              <View style={styles.timeLabelsRow}>
                {[0, 6, 12, 18].map(hour => (
                  <Text key={`label-${hour}`} style={styles.timeLabel}>
                    {hour === 0 ? '12am' : hour === 12 ? '12pm' : hour > 12 ? `${hour-12}pm` : `${hour}am`}
                  </Text>
                ))}
              </View>
              
              <View style={styles.patternBars}>
                {dailyPatterns.map((pattern, index) => (
                  <View key={`hour-${pattern.hour}`} style={styles.patternBar}>
                    <View 
                      style={[
                        styles.patternBarInner, 
                        { 
                          height: pattern.average ? Math.min(100, pattern.average/3) : 0,
                          backgroundColor: getPatternColor(pattern.average)
                        }
                      ]}
                    />
                    {index % 6 === 0 && (
                      <Text style={styles.patternBarLabel}>
                        {pattern.timeLabel}
                      </Text>
                    )}
                  </View>
                ))}
              </View>
              
              <View style={styles.patternLegend}>
                <View style={styles.legendItem}>
                  <View style={[styles.legendColor, { backgroundColor: '#E53935' }]} />
                  <Text style={styles.legendText}>Low</Text>
                </View>
                <View style={styles.legendItem}>
                  <View style={[styles.legendColor, { backgroundColor: '#4CAF50' }]} />
                  <Text style={styles.legendText}>In Range</Text>
                </View>
                <View style={styles.legendItem}>
                  <View style={[styles.legendColor, { backgroundColor: '#F57C00' }]} />
                  <Text style={styles.legendText}>High</Text>
                </View>
              </View>
            </View>
          ) : (
            <View style={styles.noDataContainer}>
              <Text>Not enough data for pattern analysis</Text>
            </View>
          )}
        </Card.Content>
      </Card>

      {/* Statistics Summary */}
      <Card style={styles.chartCard}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>Statistics</Text>
          {isLoading ? (
            <ActivityIndicator size="large" style={styles.loader} />
          ) : stats ? (
            <View style={styles.statsGrid}>
              <View style={styles.statItem}>
                <Text style={styles.statValue}>{stats.time_in_range?.toFixed(1)}%</Text>
                <Text style={styles.statLabel}>Time in Range</Text>
              </View>
              
              <View style={styles.statItem}>
                <Text style={styles.statValue}>{stats.avg_glucose}</Text>
                <Text style={styles.statLabel}>Average Glucose</Text>
              </View>
              
              <View style={styles.statItem}>
                <Text style={styles.statValue}>{stats.time_below_range?.toFixed(1)}%</Text>
                <Text style={styles.statLabel}>Time Below</Text>
              </View>
              
              <View style={styles.statItem}>
                <Text style={styles.statValue}>{stats.time_above_range?.toFixed(1)}%</Text>
                <Text style={styles.statLabel}>Time Above</Text>
              </View>
            </View>
          ) : (
            <View style={styles.noDataContainer}>
              <Text>No statistics available</Text>
            </View>
          )}
        </Card.Content>
      </Card>
    </ScrollView>
  );
};

