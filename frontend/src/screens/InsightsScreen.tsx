import React from 'react';
import { View, ScrollView } from 'react-native';
import { Card, Text, ActivityIndicator, Button } from 'react-native-paper';
import { useSelector } from 'react-redux';
import { RootState } from '../store/store';

export const InsightsScreen: React.FC<{ navigation: any }> = ({ navigation }) => {
  const { recommendations, isLoading } = useSelector((state: RootState) => state.ai);

  return (
    <ScrollView style={{ flex: 1, backgroundColor: '#fff' }}>
      <Text variant="headlineMedium" style={{ margin: 16 }}>Insights</Text>
      <Card style={{ margin: 16 }}>
        <Card.Content>
          <Text variant="titleMedium">AI Recommendations</Text>
          {isLoading ? (
            <ActivityIndicator style={{ marginTop: 16 }} />
          ) : recommendations.length === 0 ? (
            <Text style={{ marginTop: 8 }}>No recommendations available.</Text>
          ) : (
            recommendations.map((rec: any, idx: number) => (
              <Card key={idx} style={{ marginVertical: 8 }}>
                <Card.Content>
                  <Text variant="titleMedium" style={{ marginBottom: 4 }}>{rec.title}</Text>
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
                </Card.Content>
              </Card>
            ))
          )}
        </Card.Content>
      </Card>
      <Button mode="contained" style={{ margin: 16 }} onPress={() => navigation.goBack()}>
        Back to Dashboard
      </Button>
    </ScrollView>
  );
};
