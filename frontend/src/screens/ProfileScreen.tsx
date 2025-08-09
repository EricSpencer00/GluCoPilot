import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, Platform } from 'react-native';
import { Button, Text, List, Surface, Switch, Divider, Snackbar } from 'react-native-paper';
import { useNavigation, CompositeNavigationProp } from '@react-navigation/native';
import { useSelector } from 'react-redux';
import { RootState } from '../store/store';
import { StackNavigationProp } from '@react-navigation/stack';
import { AuthStackParamList, ProfileStackParamList } from '../navigation/types';
import { logout } from '../store/slices/authSlice';
import { useAppDispatch } from '../hooks/useAppDispatch';
import { Ionicons } from '@expo/vector-icons';

type ProfileScreenNavigationProp = CompositeNavigationProp<
  StackNavigationProp<AuthStackParamList, 'Login'>,
  StackNavigationProp<ProfileStackParamList, 'ProfileMain'>
>;

const ProfileScreen: React.FC = () => {
  const navigation = useNavigation<ProfileScreenNavigationProp>();
  const dispatch = useAppDispatch();
  const user = useSelector((state: RootState) => state.auth.user);
  const [snackbarVisible, setSnackbarVisible] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  
  // Integration states
  const [appleHealthConnected, setAppleHealthConnected] = useState(false);
  const [myFitnessPalConnected, setMyFitnessPalConnected] = useState(false);
  const [googleFitConnected, setGoogleFitConnected] = useState(false);

  const handleDexcomIntegration = () => {
    navigation.navigate('DexcomLogin');
  };
  
  const handleAppleHealthIntegration = () => {
    // This would be replaced with actual Apple HealthKit integration code
    setAppleHealthConnected(!appleHealthConnected);
    showSnackbar(appleHealthConnected ? 
      'Apple Health disconnected' : 
      'Apple Health connected - data will sync automatically');
  };
  
  const handleMyFitnessPalIntegration = () => {
    // Navigate to MyFitnessPal login screen (would need to be implemented)
    // For now, just toggle the state
    setMyFitnessPalConnected(!myFitnessPalConnected);
    showSnackbar(myFitnessPalConnected ? 
      'MyFitnessPal disconnected' : 
      'MyFitnessPal connected - food and activity data will sync');
  };
  
  const handleGoogleFitIntegration = () => {
    // Navigate to Google Fit authorization screen (would need to be implemented)
    // For now, just toggle the state
    setGoogleFitConnected(!googleFitConnected);
    showSnackbar(googleFitConnected ? 
      'Google Fit disconnected' : 
      'Google Fit connected - activity data will sync');
  };

  const showSnackbar = (message: string) => {
    setSnackbarMessage(message);
    setSnackbarVisible(true);
  };

  const handleLogout = () => {
    console.log('User logged out');
    dispatch(logout());
  };

  if (!user) {
    return (
      <View style={styles.container}>
        <Text variant="headlineSmall" style={styles.title}>Profile</Text>
        <Text>No user data available. Please log in.</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.scrollContainer}>
      <View style={styles.container}>
        <Text variant="headlineSmall" style={styles.title}>Profile</Text>
        
        <Surface style={styles.userInfoCard}>
          <Text variant="titleMedium">{user.first_name} {user.last_name}</Text>
          <Text>{user.email}</Text>
        </Surface>
        
        <Text variant="titleMedium" style={styles.sectionTitle}>Data Integrations</Text>
        <Text variant="bodySmall" style={styles.sectionDescription}>
          Connect to external services to enhance your glucose insights
        </Text>
        
        <Surface style={styles.card}>
          <List.Item
            title="Dexcom"
            description="Connect your Dexcom CGM to automatically sync glucose readings"
            left={props => <List.Icon {...props} icon="chart-line" />}
            right={props => (
              <Button mode="outlined" onPress={handleDexcomIntegration}>
                {user.dexcom_username ? 'Reconfigure' : 'Connect'}
              </Button>
            )}
          />
          
          <Divider />
          
          {Platform.OS === 'ios' && (
            <>
              <List.Item
                title="Apple Health"
                description="Sync activity, steps, sleep, and other health data"
                left={props => <List.Icon {...props} icon="heart-pulse" />}
                right={props => (
                  <Switch
                    value={appleHealthConnected}
                    onValueChange={handleAppleHealthIntegration}
                  />
                )}
              />
              <Divider />
            </>
          )}
          
          {Platform.OS === 'android' && (
            <>
              <List.Item
                title="Google Fit"
                description="Sync activity, steps, sleep, and other health data"
                left={props => <List.Icon {...props} icon="google-fit" />}
                right={props => (
                  <Switch
                    value={googleFitConnected}
                    onValueChange={handleGoogleFitIntegration}
                  />
                )}
              />
              <Divider />
            </>
          )}
          
          <List.Item
            title="MyFitnessPal"
            description="Sync food logs, nutrition, and exercise data"
            left={props => <List.Icon {...props} icon="food-apple" />}
            right={props => (
              <Switch
                value={myFitnessPalConnected}
                onValueChange={handleMyFitnessPalIntegration}
              />
            )}
          />
        </Surface>
        
        <Text variant="titleMedium" style={styles.sectionTitle}>AI Insights</Text>
        <Surface style={styles.card}>
          <List.Item
            title="Recommendation Feedback"
            description="Review and rate AI-generated recommendations"
            left={props => <List.Icon {...props} icon="brain" />}
            right={props => (
              <Button mode="outlined" onPress={() => navigation.navigate('AiFeedback')}>
                View
              </Button>
            )}
          />
        </Surface>
        
        <Text variant="titleMedium" style={styles.sectionTitle}>Account</Text>
        <Surface style={styles.card}>
          <List.Item
            title="User Settings"
            description="Manage your account and preferences"
            left={props => <List.Icon {...props} icon="account-cog" />}
            right={props => (
              <Button mode="outlined" onPress={() => navigation.navigate('Settings')}>
                Edit
              </Button>
            )}
          />
          
          <Divider />
          
          <List.Item
            title="Logout"
            description="Sign out of your account"
            left={props => <List.Icon {...props} icon="logout" color="#f44336" />}
            right={props => (
              <Button mode="outlined" onPress={handleLogout} textColor="#f44336">
                Logout
              </Button>
            )}
          />
        </Surface>
      </View>
      
      <Snackbar
        visible={snackbarVisible}
        onDismiss={() => setSnackbarVisible(false)}
        duration={3000}
        action={{
          label: 'OK',
          onPress: () => setSnackbarVisible(false),
        }}>
        {snackbarMessage}
      </Snackbar>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  scrollContainer: {
    flex: 1,
  },
  container: {
    flex: 1,
    padding: 16,
    paddingBottom: 32,
  },
  title: {
    marginBottom: 16,
  },
  userInfoCard: {
    padding: 16,
    marginBottom: 24,
    borderRadius: 8,
    elevation: 2,
  },
  sectionTitle: {
    marginTop: 24,
    marginBottom: 8,
  },
  sectionDescription: {
    marginBottom: 16,
    opacity: 0.6,
  },
  card: {
    borderRadius: 8,
    overflow: 'hidden',
    elevation: 2,
  },
  button: {
    marginTop: 16,
  },
});

export default ProfileScreen;
