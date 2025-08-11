import React, { useEffect } from 'react';
import { View, ScrollView, StyleSheet } from 'react-native';
import { Card, Text, Button, ActivityIndicator, Divider, List, Chip, Surface, IconButton } from 'react-native-paper';
import { LinearGradient } from 'expo-linear-gradient';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store/store';
import { clearDetailedInsight } from '../store/slices/aiSlice';

const DetailedInsightScreen = ({ navigation }: { navigation: any }) => {
  const { detailedInsight, isLoadingDetailedInsight } = useSelector((state: RootState) => state.ai);
  const dispatch = useDispatch();

  useEffect(() => {
    return () => {
      dispatch(clearDetailedInsight());
    };
  }, [dispatch]);

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

  if (isLoadingDetailedInsight) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#00796B" />
        <Text style={styles.loadingText}>Generating detailed analysis...</Text>
      </View>
    );
  }

  if (!detailedInsight) {
    return (
      <View style={styles.errorContainer}>
        <Text>No detailed insight available. Please go back and try again.</Text>
        <Button mode="contained" style={styles.backButton} onPress={() => navigation.goBack()}>
          Go Back
        </Button>
      </View>
    );
  }

  const { original_recommendation, detail } = detailedInsight;
  const chipStyle = getPriorityChipStyle(original_recommendation.priority);

  return (
    <ScrollView style={styles.container}>
      <LinearGradient
        colors={['rgba(0,121,107,0.18)', 'rgba(255,255,255,0.95)', 'rgba(0,121,107,0.18)']}
        style={styles.gradientContainer}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
      >
        <Card style={styles.card}>
          <Card.Content>
            <View style={styles.headerContainer}>
              <IconButton
                icon="arrow-left"
                size={24}
                onPress={() => navigation.goBack()}
                style={styles.backIcon}
              />
              <Text variant="headlineSmall" style={styles.title}>Detailed Insight</Text>
            </View>

            <Surface style={styles.recommendationSurface}>
              <View style={styles.iconContainer}>
                <List.Icon
                  icon={getRecommendationIcon(original_recommendation.category)}
                  color={chipStyle.backgroundColor}
                  style={styles.categoryIcon}
                />
              </View>
              <View style={styles.contentContainer}>
                <View style={styles.headerRow}>
                  <Text variant="titleMedium" style={styles.recommendationTitle}>
                    {original_recommendation.title}
                  </Text>
                  <Chip
                    mode="flat"
                    style={[
                      styles.priorityChip,
                      { backgroundColor: chipStyle.backgroundColor, borderColor: chipStyle.borderColor }
                    ]}
                    textStyle={{ color: chipStyle.textColor, fontSize: 12, fontWeight: 'bold' }}
                  >
                    {original_recommendation.priority}
                  </Chip>
                </View>
                <Text variant="bodyMedium" style={styles.recommendationDescription}>
                  {original_recommendation.description}
                </Text>
                {original_recommendation.action ? (
                  <Text variant="bodyMedium" style={styles.actionText}>
                    <Text style={styles.labelText}>Action: </Text>{original_recommendation.action}
                  </Text>
                ) : null}
                {original_recommendation.timing ? (
                  <Text variant="bodyMedium" style={styles.timingText}>
                    <Text style={styles.labelText}>Timing: </Text>{original_recommendation.timing}
                  </Text>
                ) : null}
                <Text variant="bodySmall" style={styles.categoryText}>
                  Category: {original_recommendation.category}
                </Text>
              </View>
            </Surface>

            <Divider style={styles.divider} />

            <Text variant="titleMedium" style={styles.detailTitle}>
              In-Depth Analysis
            </Text>
            <Text variant="bodyLarge" style={styles.detailText}>
              {detail}
            </Text>
          </Card.Content>
        </Card>
      </LinearGradient>

      <Button 
        mode="contained" 
        style={styles.backButton} 
        onPress={() => navigation.goBack()}
      >
        Back to Insights
      </Button>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#00796B',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  gradientContainer: {
    margin: 16,
    borderRadius: 20,
    padding: 3,
  },
  card: {
    borderRadius: 18,
    elevation: 10,
    backgroundColor: '#fff',
    shadowColor: '#00796B',
    shadowOpacity: 0.25,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 10 },
  },
  headerContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  backIcon: {
    marginRight: 8,
  },
  title: {
    color: '#00796B',
    fontWeight: 'bold',
  },
  recommendationSurface: {
    marginVertical: 8,
    borderRadius: 16,
    elevation: 6,
    backgroundColor: '#fff',
    shadowColor: '#00796B',
    shadowOpacity: 0.15,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 6 },
    padding: 16,
    flexDirection: 'row',
  },
  iconContainer: {
    marginRight: 16,
    alignItems: 'center',
    justifyContent: 'flex-start',
  },
  categoryIcon: {
    margin: 0,
  },
  contentContainer: {
    flex: 1,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  recommendationTitle: {
    flex: 1,
    fontWeight: 'bold',
    color: '#212121',
    marginRight: 8,
  },
  priorityChip: {
    height: 26,
    alignSelf: 'flex-start',
    borderRadius: 12,
  },
  recommendationDescription: {
    marginBottom: 8,
    color: '#424242',
  },
  actionText: {
    marginBottom: 4,
    color: '#424242',
  },
  timingText: {
    marginBottom: 4,
    color: '#424242',
  },
  categoryText: {
    marginTop: 4,
    color: '#757575',
  },
  labelText: {
    fontWeight: 'bold',
    color: '#424242',
  },
  divider: {
    marginVertical: 16,
    height: 1,
    backgroundColor: '#E0E0E0',
  },
  detailTitle: {
    color: '#00796B',
    fontWeight: 'bold',
    marginBottom: 12,
  },
  detailText: {
    lineHeight: 24,
    color: '#212121',
  },
  backButton: {
    margin: 16,
    marginTop: 8,
    backgroundColor: '#00796B',
  },
});

export default DetailedInsightScreen;
