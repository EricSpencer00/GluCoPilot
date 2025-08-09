import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Card, Text, Button, ActivityIndicator, Divider, List } from 'react-native-paper';

// Interfaces
interface Recommendation {
  id: string;
  content: string;
  created_at: string;
  type: string;
}

interface RecommendationCardProps {
  recommendations: Recommendation[];
  isLoading: boolean;
  onViewAll: () => void;
}

export const RecommendationCard: React.FC<RecommendationCardProps> = ({ 
  recommendations, 
  isLoading,
  onViewAll
}) => {
  const getRecommendationIcon = (type: string) => {
    switch(type) {
      case 'food':
        return 'food-apple';
      case 'insulin':
        return 'needle';
      case 'activity':
        return 'run';
      case 'medication':
        return 'pill';
      case 'sleep':
        return 'sleep';
      default:
        return 'lightbulb-outline';
    }
  };
  
  return (
    <Card style={styles.card}>
      <Card.Content>
        <View style={styles.headerRow}>
          <Text variant="titleMedium" style={styles.title}>
            AI Recommendations
          </Text>
          <Text variant="bodySmall" style={styles.count}>
            {recommendations.length} total
          </Text>
        </View>
        
        {isLoading ? (
          <ActivityIndicator size="large" style={styles.loader} />
        ) : recommendations.length > 0 ? (
          <View>
            {recommendations.map((recommendation, index) => (
              <React.Fragment key={recommendation.id}>
                <List.Item
                  title={recommendation.content}
                  left={props => (
                    <List.Icon 
                      {...props} 
                      icon={getRecommendationIcon(recommendation.type)} 
                    />
                  )}
                  style={styles.listItem}
                  titleNumberOfLines={2}
                  titleStyle={styles.recommendationText}
                />
                {index < recommendations.length - 1 && <Divider />}
              </React.Fragment>
            ))}
            <Button 
              mode="text" 
              onPress={onViewAll}
              style={styles.viewAllButton}
            >
              View All Insights
            </Button>
          </View>
        ) : (
          <View style={styles.noDataContainer}>
            <Text variant="bodyLarge">No recommendations yet</Text>
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
  listItem: {
    paddingVertical: 8,
  },
  recommendationText: {
    fontSize: 14,
  },
  viewAllButton: {
    marginTop: 8,
    alignSelf: 'flex-end',
  },
  noDataContainer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
});
