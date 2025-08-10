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
  
  // Priority chip background and text color
  const getPriorityChipStyle = (priority: string) => {
    switch(priority.toLowerCase()) {
      case 'high':
        return { backgroundColor: '#E53935', borderColor: '#E53935', textColor: '#FFFFFF' };
      case 'medium':
        return { backgroundColor: '#FFB74D', borderColor: '#FFB74D', textColor: '#FFFFFF' };
      case 'low':
        return { backgroundColor: '#81C784', borderColor: '#81C784', textColor: '#FFFFFF' };
      default:
        return { backgroundColor: '#FFFFFF', borderColor: '#757575', textColor: '#757575' };
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
              <Surface key={`${recommendation.id}-${index}`} style={styles.itemSurface}>
                <View style={styles.overflowClipView}>
                  <List.Item
                    title={truncateTitle(recommendation.title || recommendation.content)}
                    description={truncateTitle(recommendation.content, 100)}
                    left={props => {
                      const chipStyle = getPriorityChipStyle(recommendation.priority);
                      return (
                        <List.Icon
                          {...props}
                          icon={getRecommendationIcon(recommendation.category || recommendation.recommendation_type)}
                          color={chipStyle.backgroundColor}
                        />
                      );
                    }}
                    right={props => {
                      const chipStyle = getPriorityChipStyle(recommendation.priority);
                      return (
                        <Chip
                          mode="flat"
                          style={[
                            styles.priorityChip,
                            { backgroundColor: chipStyle.backgroundColor, borderColor: chipStyle.borderColor }
                          ]}
                          textStyle={{ color: chipStyle.textColor, fontSize: 12, fontWeight: 'bold' }}
                        >
                          {recommendation.priority}
                        </Chip>
                      );
                    }}
                    style={styles.listItem}
                    titleNumberOfLines={1}
                    descriptionNumberOfLines={2}
                    titleStyle={styles.recommendationTitle}
                    descriptionStyle={styles.recommendationText}
                  />
                  {index < recommendations.length - 1 && (
                    <Divider key={`divider-${recommendation.id}-${index}`} style={styles.divider} />
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
    elevation: 5,
    backgroundColor: '#FFFFFF',
    shadowColor: '#00796B',
    shadowOpacity: 0.08,
    shadowRadius: 8,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  title: {
    fontWeight: 'bold',
    color: '#00796B',
    fontSize: 18,
  },
  count: {
    color: '#757575',
    fontSize: 14,
  },
  loader: {
    marginVertical: 24,
  },
  itemSurface: {
    marginVertical: 4,
    borderRadius: 12,
    elevation: 2,
    backgroundColor: '#FFFFFF',
    shadowColor: '#00796B',
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  overflowClipView: {
    overflow: 'hidden',
    borderRadius: 12,
  },
  listItem: {
    paddingVertical: 10,
    paddingHorizontal: 4,
  },
  recommendationTitle: {
    fontSize: 15,
    color: '#212121',
    fontWeight: 'bold',
  },
  recommendationText: {
    fontSize: 13,
    color: '#757575',
  },
  divider: {
    height: 1,
    backgroundColor: '#E0E0E0',
  },
  priorityChip: {
    height: 26,
    alignSelf: 'center',
    marginRight: 8,
    borderRadius: 12,
  },
  viewAllButton: {
    marginTop: 16,
    borderRadius: 8,
    paddingVertical: 8,
    backgroundColor: '#FF8A65',
    elevation: 2,
  },
  buttonLabel: {
    fontSize: 15,
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  noDataContainer: {
    alignItems: 'center',
    paddingVertical: 32,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
  },
  noDataSubtext: {
    color: '#757575',
    marginTop: 8,
  },
});
