import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Card, Text, Button } from 'react-native-paper';

interface QuickActionsCardProps {
  onLogFood: () => void;
  onLogInsulin: () => void;
  onViewTrends: () => void;
}

export const QuickActionsCard: React.FC<QuickActionsCardProps> = ({ 
  onLogFood,
  onLogInsulin,
  onViewTrends
}) => {
  return (
    <Card style={styles.card}>
      <Card.Content>
        <Text variant="titleMedium" style={styles.title}>
          Quick Actions
        </Text>
        
        <View style={styles.buttonsContainer}>
          <Button 
            mode="contained"
            icon="food-apple"
            onPress={onLogFood}
            style={[styles.button, styles.foodButton]}
            contentStyle={styles.buttonContent}
          >
            Log Food
          </Button>
          
          <Button 
            mode="contained"
            icon="needle"
            onPress={onLogInsulin}
            style={[styles.button, styles.insulinButton]}
            contentStyle={styles.buttonContent}
          >
            Log Insulin
          </Button>
          
          <Button 
            mode="contained"
            icon="chart-line"
            onPress={onViewTrends}
            style={[styles.button, styles.trendsButton]}
            contentStyle={styles.buttonContent}
          >
            View Trends
          </Button>
        </View>
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
  title: {
    fontWeight: 'bold',
    marginBottom: 16,
  },
  buttonsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    flexWrap: 'wrap',
  },
  button: {
    flex: 1,
    marginHorizontal: 4,
    marginBottom: 8,
    minWidth: '30%',
  },
  buttonContent: {
    height: 48,
  },
  foodButton: {
    backgroundColor: '#4CAF50',
  },
  insulinButton: {
    backgroundColor: '#2196F3',
  },
  trendsButton: {
    backgroundColor: '#9C27B0',
  },
});
