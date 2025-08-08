import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';

// Import screens
import { DashboardScreen } from '../screens/DashboardScreen';
import { LoadingScreen } from '../components/common/LoadingScreen';

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
      <Tab.Screen name="Log" component={DashboardScreen} />
      <Tab.Screen name="Trends" component={DashboardScreen} />
      <Tab.Screen name="Insights" component={DashboardScreen} />
      <Tab.Screen name="Profile" component={DashboardScreen} />
    </Tab.Navigator>
  );
};

// Auth stack navigator
const AuthStackNavigator = () => {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Login" component={DashboardScreen} />
      <Stack.Screen name="Register" component={DashboardScreen} />
      <Stack.Screen name="ForgotPassword" component={DashboardScreen} />
    </Stack.Navigator>
  );
};

// Root navigator
export const AppNavigator = () => {
  // This line correctly accesses the auth state from Redux
  const auth = useSelector((state: RootState) => state.auth);
  const user = auth.user;
  const isLoading = auth.isLoading;

  if (isLoading) {
    return <LoadingScreen />;
  }

  return (
    <>
      {user ? (
        <MainTabNavigator />
      ) : (
        <AuthStackNavigator />
      )}
    </>
  );
};
