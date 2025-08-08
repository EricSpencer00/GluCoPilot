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

// Simple placeholder screens for tabs
import { View, Text } from 'react-native';
const TrendsScreen = () => (
  <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
    <Text>Trends</Text>
  </View>
);
const LogScreen = () => (
  <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
    <Text>Log</Text>
  </View>
);
const InsightsScreen = () => (
  <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
    <Text>Insights</Text>
  </View>
);
const ProfileScreen = () => (
  <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
    <Text>Profile</Text>
  </View>
);

// Import types
import { RootState } from '../store/store';

// Create navigators
const Stack = createStackNavigator();
const Tab = createBottomTabNavigator();

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
      <Tab.Screen name="Profile" component={ProfileScreen} />
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
