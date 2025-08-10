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
            onPress={onLogFood}
            style={[styles.button, styles.foodButton]}
            contentStyle={styles.buttonContent}
          >
            Log Food
          </Button>
          
          <Button 
            mode="contained"
            onPress={onLogInsulin}
            style={[styles.button, styles.insulinButton]}
            contentStyle={styles.buttonContent}
          >
            Log Insulin
          </Button>
          
          <Button 
            mode="contained"
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
    borderRadius: 16,
    elevation: 4,
    backgroundColor: '#FFFFFF',
    shadowColor: '#00796B',
    shadowOpacity: 0.08,
    shadowRadius: 8,
  },
  title: {
    fontWeight: 'bold',
    marginBottom: 16,
    color: '#00796B', // Deep Teal
    fontSize: 18,
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
    borderRadius: 8,
    elevation: 2,
  },
  buttonContent: {
    height: 48,
  },
  foodButton: {
    backgroundColor: '#FF8A65', // Vibrant Coral
  },
  insulinButton: {
    backgroundColor: '#64B5F6', // Calm Blue
  },
  trendsButton: {
    backgroundColor: '#81C784', // Subtle Green
  },
});
