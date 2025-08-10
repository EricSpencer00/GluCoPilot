import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Card, Text, Button, ActivityIndicator, Divider, List, Chip, Surface } from 'react-native-paper';

// Interfaces
interface Recommendation {
  id: number;
  recommendation_type: string;
  content: string;
  title: string;
  category: string;
  priority: string;
  confidence_score: number;
  context_data: any;
  timestamp: string;
}

interface EnhancedRecommendationCardProps {
  recommendations: Recommendation[];
  isLoading: boolean;
  onViewAll: () => void;
}

export const EnhancedRecommendationCard: React.FC<EnhancedRecommendationCardProps> = ({ 
  recommendations, 
  isLoading,
  onViewAll
}) => {
  const getRecommendationIcon = (type: string) => {
    const lowerType = type.toLowerCase();
    
    if (lowerType.includes('insulin')) return 'needle';
    if (lowerType.includes('food') || lowerType.includes('nutrition')) return 'food-apple';
    if (lowerType.includes('exercise') || lowerType.includes('activity')) return 'run';
    if (lowerType.includes('medication')) return 'pill';
    if (lowerType.includes('sleep')) return 'sleep';
    if (lowerType.includes('monitoring')) return 'chart-line';
    if (lowerType.includes('timing')) return 'clock-outline';
    
    return 'lightbulb-outline';
  };
  
  const getPriorityColor = (priority: string) => {
    switch(priority.toLowerCase()) {
      case 'high':
        return '#E53935'; // Red
      case 'medium':
        return '#FB8C00'; // Orange
      case 'low':
        return '#4CAF50'; // Green
      default:
        return '#757575'; // Gray
    }
  };
  
  const truncateTitle = (title: string, maxLength: number = 64) => {
    if (!title) return '';
    if (title.length <= maxLength) return title;
    return `${title.substring(0, maxLength)}...`;
  };
  
  return (
    <Card style={styles.card}>
      <Card.Content>
        <View style={styles.headerRow}>
          <Text variant="titleMedium" style={styles.title}>
            AI Recommendations
          </Text>
          <Text variant="bodySmall" style={styles.count}>
            {recommendations.length} insights
          </Text>
        </View>
        
        {isLoading ? (
          <ActivityIndicator size="large" style={styles.loader} />
        ) : recommendations.length > 0 ? (
          <View>
            {recommendations.map((recommendation, index) => (
              <Surface key={recommendation.id} style={styles.itemSurface}>
                <View style={styles.overflowClipView}>
                  <List.Item
                    title={truncateTitle(recommendation.title || recommendation.content)}
                    description={truncateTitle(recommendation.content, 100)}
                    left={props => (
                      <List.Icon 
                        {...props} 
                        icon={getRecommendationIcon(recommendation.category || recommendation.recommendation_type)} 
                        color={getPriorityColor(recommendation.priority)}
                      />
                    )}
                    right={props => (
                      <Chip 
                        mode="outlined" 
                        style={[styles.priorityChip, { borderColor: getPriorityColor(recommendation.priority) }]}
                        textStyle={{ color: getPriorityColor(recommendation.priority), fontSize: 10 }}
                      >
                        {recommendation.priority}
                      </Chip>
                    )}
                    style={styles.listItem}
                    titleNumberOfLines={1}
                    descriptionNumberOfLines={2}
                    titleStyle={styles.recommendationTitle}
                    descriptionStyle={styles.recommendationText}
                  />
                  {index < recommendations.length - 1 && (
                    <Divider key={`divider-${recommendation.id}`} style={styles.divider} />
                  )}
                </View>
              </Surface>
            ))}
            <Button 
              mode="contained" 
              onPress={onViewAll}
              style={styles.viewAllButton}
              labelStyle={styles.buttonLabel}
            >
              View All Insights
            </Button>
          </View>
        ) : (
          <View style={styles.noDataContainer}>
            <Text variant="bodyLarge">No recommendations yet</Text>
            <Text variant="bodySmall" style={styles.noDataSubtext}>
              Log more data to get personalized insights
            </Text>
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
    elevation: 3,
    backgroundColor: '#fff',
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  title: {
    fontWeight: 'bold',
  },
  count: {
    opacity: 0.7,
  },
  loader: {
    marginVertical: 24,
  },
  itemSurface: {
    marginVertical: 4,
    borderRadius: 8,
    elevation: 1,
    backgroundColor: '#fafafa',
    // overflow: 'hidden', // Removed to allow shadow
  },
  overflowClipView: {
    overflow: 'hidden',
    borderRadius: 8,
  },
  listItem: {
    paddingVertical: 8,
  },
  recommendationTitle: {
    fontSize: 14,
    fontWeight: '600',
  },
  recommendationText: {
    fontSize: 12,
  },
  divider: {
    height: 1,
    backgroundColor: '#f0f0f0',
  },
  priorityChip: {
    height: 24,
    alignSelf: 'center',
    marginRight: 8,
  },
  viewAllButton: {
    marginTop: 16,
    borderRadius: 8,
    paddingVertical: 6,
  },
  buttonLabel: {
    fontSize: 14,
    fontWeight: '600',
  },
  noDataContainer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  noDataSubtext: {
    color: '#888',
    marginTop: 8,
  },
});
