import React, { useState, useEffect } from 'react';
import { View, StyleSheet, ScrollView, Platform, Linking } from 'react-native';
import { Button, Text, List, Surface, Switch, Divider, Snackbar, Card, ActivityIndicator, Portal, Modal } from 'react-native-paper';
import { useNavigation, CompositeNavigationProp } from '@react-navigation/native';
import { useSelector } from 'react-redux';
import { RootState } from '../store/store';
import { User } from '../types/User';
import { StackNavigationProp } from '@react-navigation/stack';
import { AuthStackParamList, ProfileStackParamList } from '../navigation/types';
import { logout } from '../store/slices/authSlice';
import { useAppDispatch } from '../hooks/useAppDispatch';
import { Ionicons } from '@expo/vector-icons';
import * as DocumentPicker from 'expo-document-picker';
import axios from 'axios';

type ProfileScreenNavigationProp = CompositeNavigationProp<
  StackNavigationProp<AuthStackParamList, 'Login'>,
  StackNavigationProp<ProfileStackParamList, 'ProfileMain'>
>;

const ProfileScreen: React.FC = () => {
  const navigation = useNavigation<ProfileScreenNavigationProp>();
  const dispatch = useAppDispatch();
  const user: User | null = useSelector((state: RootState) => state.auth.user);
  const [snackbarVisible, setSnackbarVisible] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  
  // Integration states
  const [appleHealthConnected, setAppleHealthConnected] = useState(false);
  const [myFitnessPalConnected, setMyFitnessPalConnected] = useState(false);
  const [googleFitConnected, setGoogleFitConnected] = useState(false);
  
  // Stats loading state
  const [isLoadingStats, setIsLoadingStats] = useState(false);
  const [userStats, setUserStats] = useState({
    totalGlucoseReadings: 0,
    totalInsulinDoses: 0,
    totalFoodEntries: 0,
    totalActivityLogs: 0
  });
  
  // Apple Health upload state
  const [uploading, setUploading] = useState(false);
  
  // Fetch user data statistics
  useEffect(() => {
    if (user) {
      fetchUserStats();
    }
  }, [user]);
  
  const fetchUserStats = async () => {
    setIsLoadingStats(true);
    try {
      // In a real implementation, this would fetch from API
      // For now, we'll use mock data
      setTimeout(() => {
        setUserStats({
          totalGlucoseReadings: 287,
          totalInsulinDoses: 14,
          totalFoodEntries: 9,
          totalActivityLogs: 12
        });
        setIsLoadingStats(false);
      }, 1000);
    } catch (error) {
      console.error('Error fetching user stats:', error);
      setIsLoadingStats(false);
    }
  };

  const handleDexcomIntegration = () => {
    navigation.navigate('DexcomLogin');
  };
  
  const hasDexcomConnected = () => {
    return user && 'dexcom_username' in user && user.dexcom_username;
  };
  
  const handleAppleHealthIntegration = () => {
    if (appleHealthConnected) {
      setAppleHealthConnected(false);
      showSnackbar('Apple Health disconnected');
    } else {
      // Show instructions modal instead of just toggling
      showInstructionsModal('apple_health');
    }
  };
  
  const handleMyFitnessPalIntegration = () => {
    if (myFitnessPalConnected) {
      setMyFitnessPalConnected(false);
      showSnackbar('MyFitnessPal disconnected');
    } else {
      // Show instructions modal instead of just toggling
      showInstructionsModal('myfitnesspal');
    }
  };
  
  const [showInstructions, setShowInstructions] = useState(false);
  const [instructionType, setInstructionType] = useState<'apple_health' | 'myfitnesspal' | null>(null);
  
  const showInstructionsModal = (type: 'apple_health' | 'myfitnesspal') => {
    setInstructionType(type);
    setShowInstructions(true);
  };
  
  const openAppStore = () => {
    if (Platform.OS === 'ios') {
      Linking.openURL('https://apps.apple.com/us/app/myfitnesspal/id341232718');
    } else {
      Linking.openURL('https://play.google.com/store/apps/details?id=com.myfitnesspal.android');
    }
  };
  
  const toggleConnectionAfterInstructions = () => {
    if (instructionType === 'apple_health') {
      setAppleHealthConnected(true);
      showSnackbar('Apple Health connected - data will sync automatically');
    } else if (instructionType === 'myfitnesspal') {
      setMyFitnessPalConnected(true);
      showSnackbar('MyFitnessPal connected - food and activity data will sync');
    }
    setShowInstructions(false);
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

  // Apple Health file upload handler
  const handleAppleHealthUpload = async () => {
    try {
      setUploading(true);
      const result = await DocumentPicker.getDocumentAsync({
        type: 'application/xml',
        copyToCacheDirectory: true,
      });
      if (!result.canceled && result.assets && result.assets.length > 0) {
        const file = result.assets[0];
        const formData = new FormData();
        formData.append('file', {
          uri: file.uri,
          name: file.name || 'apple_health_export.xml',
          type: file.mimeType || 'application/xml',
        } as any);
        const response = await axios.post('/api/apple-health/import', formData, {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          withCredentials: true,
        });
        showSnackbar(response.data.message || 'Apple Health data imported!');
      }
    } catch (e) {
      showSnackbar('Failed to upload Apple Health file.');
    } finally {
      setUploading(false);
    }
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
        {/* User Info Card with all fields */}
        <Surface style={styles.userInfoCard}>
          <Text variant="titleMedium">{user.first_name} {user.last_name}</Text>
          <Text>{user.email}</Text>
          <Divider style={{marginVertical: 8}} />
          <Text variant="bodySmall">Username: {user.username}</Text>
          <Text variant="bodySmall">Active: {user.is_active ? 'Yes' : 'No'}</Text>
          <Text variant="bodySmall">Verified: {user.is_verified ? 'Yes' : 'No'}</Text>
          <Text variant="bodySmall">Created: {user.created_at ? new Date(user.created_at).toLocaleDateString() : 'N/A'}</Text>
          <Text variant="bodySmall">Last Login: {user.last_login ? new Date(user.last_login).toLocaleString() : 'N/A'}</Text>
          <Divider style={{marginVertical: 8}} />
          <Text variant="bodySmall">Gender: {user.gender || 'N/A'}</Text>
          <Text variant="bodySmall">Birthdate: {user.birthdate ? new Date(user.birthdate).toLocaleDateString() : 'N/A'}</Text>
          <Text variant="bodySmall">Height: {user.height_cm ? user.height_cm + ' cm' : 'N/A'}</Text>
          <Text variant="bodySmall">Weight: {user.weight_kg ? user.weight_kg + ' kg' : 'N/A'}</Text>
          <Divider style={{marginVertical: 8}} />
          <Text variant="bodySmall">Diabetes Type: {user.diabetes_type === 1 ? 'Type 1' : user.diabetes_type === 2 ? 'Type 2' : 'N/A'}</Text>
          <Text variant="bodySmall">Diagnosis Date: {user.diagnosis_date ? new Date(user.diagnosis_date).toLocaleDateString() : 'N/A'}</Text>
          <Text variant="bodySmall">Target Glucose: {user.target_glucose_min || 'N/A'} - {user.target_glucose_max || 'N/A'} mg/dL</Text>
          <Text variant="bodySmall">Insulin:Carb Ratio: {user.insulin_carb_ratio ? '1:' + user.insulin_carb_ratio : 'N/A'}</Text>
          <Text variant="bodySmall">Correction Factor: {user.insulin_sensitivity_factor || 'N/A'}</Text>
          <Divider style={{marginVertical: 8}} />
          <Text variant="bodySmall">Dexcom Username: {user.dexcom_username || 'N/A'}</Text>
          <Text variant="bodySmall">Dexcom OUS: {user.dexcom_ous ? 'Yes' : 'No'}</Text>
          <Text variant="bodySmall">MyFitnessPal Username: {user.myfitnesspal_username || 'N/A'}</Text>
          <Text variant="bodySmall">Apple Health: {user.apple_health_authorized ? 'Connected' : 'Not Connected'}</Text>
          <Text variant="bodySmall">Google Fit: {user.google_fit_authorized ? 'Connected' : 'Not Connected'}</Text>
          <Text variant="bodySmall">Fitbit: {user.fitbit_authorized ? 'Connected' : 'Not Connected'}</Text>
          <Divider style={{marginVertical: 8}} />
          <Text variant="bodySmall">Notification Preferences: {user.notification_preferences ? JSON.stringify(user.notification_preferences) : 'N/A'}</Text>
          <Text variant="bodySmall">Privacy Preferences: {user.privacy_preferences ? JSON.stringify(user.privacy_preferences) : 'N/A'}</Text>
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
                {hasDexcomConnected() ? 'Reconfigure' : 'Connect'}
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
        
        {Platform.OS === 'ios' && appleHealthConnected && (
          <Button
            mode="contained"
            onPress={handleAppleHealthUpload}
            loading={uploading}
            style={styles.button}
            icon="upload"
            disabled={uploading}
          >
            Upload Apple Health Export
          </Button>
        )}
        
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

      {/* Integration Instructions Modal */}
      <Portal>
        <Modal
          visible={showInstructions}
          onDismiss={() => setShowInstructions(false)}
          contentContainerStyle={styles.modalContainer}>
          <Text variant="headlineSmall" style={styles.modalTitle}>
            {instructionType === 'apple_health' ? 'Connect Apple Health' : 'Connect MyFitnessPal'}
          </Text>
          
          {instructionType === 'apple_health' && (
            <>
              <Text variant="bodyMedium" style={styles.modalText}>
                To connect Apple Health with GluCoPilot:
              </Text>
              <Text variant="bodyMedium" style={styles.instructionText}>
                1. Open the Apple Health app on your iPhone{'\n'}
                2. Tap on your profile picture in the top right{'\n'}
                3. Tap on "Privacy & Settings"{'\n'}
                4. Select "Apps"{'\n'}
                5. Find "GluCoPilot" and tap on it{'\n'}
                6. Enable all categories you want to share{'\n'}
                7. Come back to GluCoPilot and turn on the toggle
              </Text>
            </>
          )}
          
          {instructionType === 'myfitnesspal' && (
            <>
              <Text variant="bodyMedium" style={styles.modalText}>
                To connect MyFitnessPal with GluCoPilot:
              </Text>
              <Text variant="bodyMedium" style={styles.instructionText}>
                1. Download the MyFitnessPal app if you don't have it{'\n'}
                2. Create an account or log in{'\n'}
                3. Go to "More" tab {`>`} "Settings" {`>`} "Diary Sharing"{'\n'}
                4. Enable "Share My Food Diary"{'\n'}
                5. For automatic syncing with Apple Health:{'\n'}
                6. Go to "More" {`>`} "Apps & Devices"{'\n'}
                7. Connect with Apple Health{'\n'}
                8. Return to GluCoPilot and toggle on MyFitnessPal
              </Text>
              <Button 
                mode="outlined" 
                onPress={openAppStore}
                style={styles.modalButton}>
                Download MyFitnessPal
              </Button>
            </>
          )}
          
          <Button 
            mode="contained" 
            onPress={toggleConnectionAfterInstructions}
            style={styles.modalButton}>
            I've Completed These Steps
          </Button>
          <Button 
            onPress={() => setShowInstructions(false)}>
            Cancel
          </Button>
        </Modal>
      </Portal>
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
  // Stats styling
  statsLoading: {
    padding: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    marginTop: 8,
    opacity: 0.7,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    padding: 12,
  },
  statItem: {
    width: '50%',
    padding: 12,
    alignItems: 'center',
  },
  divider: {
    marginVertical: 8,
  },
  manageDataButton: {
    margin: 12,
  },
  // Modal styles
  modalContainer: {
    backgroundColor: 'white',
    padding: 20,
    margin: 20,
    borderRadius: 12,
    elevation: 5,
  },
  modalTitle: {
    marginBottom: 16,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  modalText: {
    marginBottom: 16,
    lineHeight: 22,
  },
  instructionText: {
    marginBottom: 20,
    lineHeight: 24,
    backgroundColor: '#f5f5f5',
    padding: 16,
    borderRadius: 8,
  },
  modalButton: {
    marginVertical: 12,
  },
});

export default ProfileScreen;
