import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';

// Import screens
import { DashboardScreen } from '../screens/DashboardScreen';
import { LoadingScreen } from '../components/common/LoadingScreen';
import { LoginScreen } from '../screens/LoginScreen';
import { RegisterScreen } from '../screens/RegisterScreen';
import { ForgotPasswordScreen } from '../screens/ForgotPasswordScreen';
import DexcomLoginScreen from '../screens/DexcomLoginScreen';
import ProfileScreen from '../screens/ProfileScreen'; // Fixed import

// Simple debug screens for tabs that aren't fully implemented yet
import { View, Text, ScrollView, StyleSheet, Button } from 'react-native';
import { Card } from 'react-native-paper';
import { API_BASE_URL } from '../config';

const TrendsScreen = () => (
  <ScrollView style={styles.container}>
    <Card style={styles.card}>
      <Card.Title title="Trends Debug View" />
      <Card.Content>
        <Text style={styles.infoText}>This screen is a placeholder.</Text>
        <Text style={styles.infoText}>API URL: {API_BASE_URL}</Text>
        <Text style={styles.infoText}>Current Time: {new Date().toLocaleString()}</Text>
      </Card.Content>
    </Card>
  </ScrollView>
);

const LogScreen = () => (
  <ScrollView style={styles.container}>
    <Card style={styles.card}>
      <Card.Title title="Log Debug View" />
      <Card.Content>
        <Text style={styles.infoText}>This screen is a placeholder.</Text>
        <Text style={styles.infoText}>API URL: {API_BASE_URL}</Text>
        <Text style={styles.infoText}>Current Time: {new Date().toLocaleString()}</Text>
        
        <View style={styles.buttonContainer}>
          <Button 
            title="Log Food (Debug)" 
            onPress={() => console.log('Log Food pressed')} 
          />
          <Button 
            title="Log Insulin (Debug)" 
            onPress={() => console.log('Log Insulin pressed')} 
          />
          <Button 
            title="Log Exercise (Debug)" 
            onPress={() => console.log('Log Exercise pressed')} 
          />
        </View>
      </Card.Content>
    </Card>
  </ScrollView>
);

const InsightsScreen = () => (
  <ScrollView style={styles.container}>
    <Card style={styles.card}>
      <Card.Title title="Insights Debug View" />
      <Card.Content>
        <Text style={styles.infoText}>This screen is a placeholder.</Text>
        <Text style={styles.infoText}>API URL: {API_BASE_URL}</Text>
        <Text style={styles.infoText}>Current Time: {new Date().toLocaleString()}</Text>
      </Card.Content>
    </Card>
  </ScrollView>
);

// Import types
import { RootState } from '../store/store';

// Create navigators
const Stack = createStackNavigator();
const Tab = createBottomTabNavigator();

// Profile stack navigator
const ProfileStackNavigator = () => {
  return (
    <Stack.Navigator>
      <Stack.Screen 
        name="ProfileMain" 
        component={ProfileScreen} 
        options={{ headerShown: false }}
      />
      <Stack.Screen 
        name="DexcomLogin" 
        component={DexcomLoginScreen} 
        options={{ title: "Dexcom Integration" }}
      />
    </Stack.Navigator>
  );
};

// Main tab navigator
const MainTabNavigator = () => {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ color, size }) => {
          let iconName;

          if (route.name === 'Dashboard') {
            iconName = 'view-dashboard';
          } else if (route.name === 'Log') {
            iconName = 'plus-circle';
          } else if (route.name === 'Trends') {
            iconName = 'chart-line';
          } else if (route.name === 'Insights') {
            iconName = 'lightbulb';
          } else if (route.name === 'Profile') {
            iconName = 'account';
          }

          return (
            <MaterialCommunityIcons
              name={iconName as any}
              size={size}
              color={color}
            />
          );
        },
      })}
    >
      <Tab.Screen name="Dashboard" component={DashboardScreen} />
      <Tab.Screen name="Log" component={LogScreen} />
      <Tab.Screen name="Trends" component={TrendsScreen} />
      <Tab.Screen name="Insights" component={InsightsScreen} />
      <Tab.Screen name="Profile" component={ProfileStackNavigator} />
    </Tab.Navigator>
  );
};

// Auth stack navigator
const AuthStackNavigator = () => {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Login" component={LoginScreen} />
      <Stack.Screen name="Register" component={RegisterScreen} />
      <Stack.Screen name="ForgotPassword" component={ForgotPasswordScreen} />
      <Stack.Screen name="DexcomLogin" component={DexcomLoginScreen} />
    </Stack.Navigator>
  );
};

// Root navigator
export const AppNavigator = () => {
  const auth = useSelector((state: RootState) => state.auth);
  const user = auth.user;
  const isLoading = auth.isLoading;

  if (isLoading) {
    return <LoadingScreen />;
  }

  return <>{user ? <MainTabNavigator /> : <AuthStackNavigator />}</>;
};

// Styles
const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: '#f5f5f5',
  },
  card: {
    marginVertical: 8,
    borderRadius: 8,
  },
  infoText: {
    marginBottom: 8,
    fontSize: 16,
  },
  buttonContainer: {
    marginTop: 16,
    gap: 12,
  }
});
