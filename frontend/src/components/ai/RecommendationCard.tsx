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
    elevation: 4,
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
  listItem: {
    paddingVertical: 8,
  },
  recommendationText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212121',
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
    paddingVertical: 24,
  },
});
