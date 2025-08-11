import React, { useState, useCallback } from 'react';
import { View, ScrollView, RefreshControl, TouchableOpacity } from 'react-native';
import { Card, Text, ActivityIndicator, Button, List, Surface } from 'react-native-paper';
import { LinearGradient } from 'expo-linear-gradient';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store/store';
import { fetchRecommendations, fetchDetailedInsight } from '../store/slices/aiSlice';

export const InsightsScreen: React.FC<{ navigation: any }> = ({ navigation }) => {
  const { recommendations, isLoading } = useSelector((state: RootState) => state.ai);
  const dispatch = useDispatch();
  const [refreshing, setRefreshing] = useState(false);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await dispatch(fetchRecommendations() as any);
    setRefreshing(false);
  }, [dispatch]);

  const handleInsightPress = (recommendation: any) => {
    dispatch(fetchDetailedInsight(recommendation) as any);
    navigation.navigate('DetailedInsight');
  };

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#fff' }}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      <Text variant="headlineMedium" style={{ margin: 16 }}>Insights</Text>
      <LinearGradient
        colors={['rgba(0,121,107,0.18)', 'rgba(255,255,255,0.95)', 'rgba(0,121,107,0.18)']}
        style={{ margin: 16, borderRadius: 20, padding: 3 }}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
      >
        <Card style={{ 
          borderRadius: 18, 
          elevation: 10, 
          backgroundColor: '#fff', 
          shadowColor: '#00796B', 
          shadowOpacity: 0.25, 
          shadowRadius: 24, 
          shadowOffset: { width: 0, height: 10 } 
        }}>
          <Card.Content>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
              <Text variant="titleMedium">AI Recommendations</Text>
              <Button mode="outlined" onPress={onRefresh} loading={isLoading || refreshing} style={{ marginLeft: 8 }}>
                Refresh
              </Button>
            </View>
            {isLoading ? (
              <ActivityIndicator style={{ marginTop: 16 }} />
            ) : recommendations.length === 0 ? (
              <Text style={{ marginTop: 8 }}>No recommendations available.</Text>
            ) : (
              recommendations.map((rec: any, idx: number) => (
                <TouchableOpacity key={idx} onPress={() => handleInsightPress(rec)}>
                  <Surface style={{ marginVertical: 8, borderRadius: 16, elevation: 6, backgroundColor: '#fff', shadowColor: '#00796B', shadowOpacity: 0.15, shadowRadius: 14, shadowOffset: { width: 0, height: 6 } }}>
                    <Card.Content style={{ flexDirection: 'row', alignItems: 'flex-start', padding: 16 }}>
                      {/* Proper icon for each recommendation */}
                      <View style={{ marginRight: 16, alignItems: 'center', justifyContent: 'center' }}>
                        <List.Icon
                          icon={getRecommendationIcon(rec.category)}
                          color="#00796B"
                          style={{ margin: 0 }}
                        />
                      </View>
                      <View style={{ flex: 1 }}>
                        <Text variant="titleMedium" style={{ marginBottom: 4, fontWeight: 'bold' }}>{rec.title}</Text>
                        {rec.description ? (
                          <Text variant="bodyLarge" style={{ marginBottom: 4 }}>{rec.description}</Text>
                        ) : null}
                        {rec.action ? (
                          <Text variant="bodyMedium" style={{ marginBottom: 2 }}>Action: {rec.action}</Text>
                        ) : null}
                        {rec.timing ? (
                          <Text variant="bodyMedium" style={{ marginBottom: 2 }}>Timing: {rec.timing}</Text>
                        ) : null}
                        <Text variant="bodySmall" style={{ marginTop: 4, color: '#888' }}>
                          Category: {rec.category} | Priority: {rec.priority}
                        </Text>
                        <Text variant="bodySmall" style={{ color: '#888' }}>
                          Confidence: {rec.confidence ? (rec.confidence * 100).toFixed(0) + '%' : 'N/A'}
                        </Text>
                      </View>
                    </Card.Content>
                  </Surface>
                </TouchableOpacity>
              ))
            )}
          </Card.Content>
        </Card>
      </LinearGradient>
      <Button mode="contained" style={{ margin: 16 }} onPress={() => navigation.goBack()}>
        Back to Dashboard
      </Button>
    </ScrollView>
  );
};

// Helper function to determine icon based on recommendation category
const getRecommendationIcon = (category: string) => {
  const lowerCategory = (category || '').toLowerCase();
  
  if (lowerCategory.includes('insulin')) return 'needle';
  if (lowerCategory.includes('food') || lowerCategory.includes('nutrition')) return 'food-apple';
  if (lowerCategory.includes('exercise') || lowerCategory.includes('activity')) return 'run';
  if (lowerCategory.includes('medication')) return 'pill';
  if (lowerCategory.includes('sleep')) return 'sleep';
  if (lowerCategory.includes('monitoring')) return 'chart-line';
  if (lowerCategory.includes('timing')) return 'clock-outline';
  
  return 'lightbulb-outline';
};
