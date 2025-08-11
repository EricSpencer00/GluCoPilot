import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { InsightsScreen } from '../screens/InsightsScreen';
import DetailedInsightScreen from '../screens/DetailedInsightScreen';

const Stack = createStackNavigator();

export const InsightsStackNavigator = () => {
  return (
    <Stack.Navigator initialRouteName="InsightsMain" screenOptions={{ headerShown: false }}>
      <Stack.Screen name="InsightsMain" component={InsightsScreen} />
      <Stack.Screen name="DetailedInsight" component={DetailedInsightScreen} />
    </Stack.Navigator>
  );
};
