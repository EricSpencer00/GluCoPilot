import React, { useState, useEffect } from 'react';
import { View, ScrollView, RefreshControl } from 'react-native';
import { Card, Text, Button, FAB, Portal, Modal, Snackbar } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { useFocusEffect } from '@react-navigation/native';

import { RootState } from '../store/store';
import { GlucoseCard } from '../components/glucose/GlucoseCard';
import { TrendChart } from '../components/charts/TrendChart';
import { DexcomStyleChart } from '../components/charts/DexcomStyleChart';
import { TimeInRangeCard } from '../components/glucose/TimeInRangeCard';
import { RecommendationCard } from '../components/ai/RecommendationCard';
import { EnhancedRecommendationCard } from '../components/ai/EnhancedRecommendationCard';
import { QuickActionsCard } from '../components/common/QuickActionsCard';
import { fetchGlucoseData, syncDexcomData } from '../store/slices/glucoseSlice';
import { fetchRecommendations } from '../store/slices/aiSlice';
import { clearNewRegistrationFlag } from '../store/slices/authSlice';
import { styles } from '../styles/screens/DashboardScreen';

interface DashboardScreenProps {
  navigation: any;
}

export const DashboardScreen: React.FC<DashboardScreenProps> = ({ navigation }) => {
  // Handler for DexcomStyleChart time range changes
  const handleTimeRangeChange = (range: '3h' | '6h' | '12h' | '24h') => {
    setTimeRange(range);
    // Optionally, fetch more data if needed for longer ranges
    // Example: dispatch(fetchGlucoseData({ hours: ... }) as any);
  };
  const dispatch = useDispatch();
  const { 
    latestReading, 
    readings, 
    stats, 
    isLoading: glucoseLoading, 
    lastSync 
  } = useSelector((state: RootState) => state.glucose);
  
  const { 
    recommendations, 
    isLoading: aiLoading 
  } = useSelector((state: RootState) => state.ai);
  
  const { user, isNewRegistration } = useSelector((state: RootState) => state.auth);
  
  const [refreshing, setRefreshing] = useState(false);
  const [showQuickActions, setShowQuickActions] = useState(false);
  const [snackbarVisible, setSnackbarVisible] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  const [timeRange, setTimeRange] = useState<'3h' | '6h' | '12h' | '24h'>('3h');
  const [showDexcomModal, setShowDexcomModal] = useState(false);

  useFocusEffect(
    React.useCallback(() => {
      loadDashboardData();
    }, [])
  );

  // Check if this is a new registration and show Dexcom connection prompt
  useEffect(() => {
    if (isNewRegistration) {
      setShowDexcomModal(true);
    }
  }, [isNewRegistration]);

  const loadDashboardData = async () => {
    try {
      await Promise.all([
        dispatch(fetchGlucoseData({ hours: 24 }) as any),
        dispatch(fetchRecommendations() as any)
      ]);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      await loadDashboardData();
      showSnackbar('Dashboard refreshed');
    } catch (error) {
      showSnackbar('Error refreshing dashboard');
    } finally {
      setRefreshing(false);
    }
  };

  const handleSyncDexcom = async () => {
    try {
      await dispatch(syncDexcomData() as any);
      showSnackbar('Dexcom data synced successfully');
    } catch (error) {
      showSnackbar('Error syncing Dexcom data');
    }
  };

  const showSnackbar = (message: string) => {
    setSnackbarMessage(message);
    setSnackbarVisible(true);
  };

  const navigateToLog = (type: 'food' | 'insulin') => {
    setShowQuickActions(false);
    navigation.navigate('Log', { type });
  };

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  };

  const getLastSyncText = () => {
    if (!lastSync) return 'Never synced';
    const now = new Date();
    const syncTime = new Date(lastSync);
    const diffMinutes = Math.floor((now.getTime() - syncTime.getTime()) / 60000);
    
    if (diffMinutes < 1) return 'Just now';
    if (diffMinutes < 60) return `${diffMinutes}m ago`;
    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    return `${Math.floor(diffHours / 24)}d ago`;
  };

  const handleDexcomConnect = () => {
    setShowDexcomModal(false);
    dispatch(clearNewRegistrationFlag());
    navigation.navigate('Profile', { screen: 'DexcomLogin', params: { fromRegistration: true } });
  };

  const skipDexcomConnect = () => {
    setShowDexcomModal(false);
    dispatch(clearNewRegistrationFlag());
    showSnackbar('You can connect Dexcom later in your Profile');
  };

  return (
    <View style={styles.container}>
      <ScrollView
        style={styles.scrollView}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
        }
      >
        {/* Header */}
        <View style={styles.header}>
          <Text variant="headlineMedium" style={styles.greeting}>
            {getGreeting()}, {user?.first_name || 'User'}!
          </Text>
          <Text variant="bodyMedium" style={styles.lastSync}>
            Last sync: {getLastSyncText()}
          </Text>
        </View>

        {/* Current Glucose */}
        <GlucoseCard 
          reading={latestReading}
          isLoading={glucoseLoading}
          onSync={handleSyncDexcom}
        />

        {/* Time in Range */}
        <TimeInRangeCard stats={stats} isLoading={glucoseLoading} />

        {/* Trend Chart */}
        <Card style={styles.chartCard}>
          <Card.Content>
            <Text variant="titleMedium" style={styles.cardTitle}>
              Glucose Trends
            </Text>
            <DexcomStyleChart 
              data={readings} 
              isLoading={glucoseLoading}
              height={240}
              timeRange={timeRange}
              onTimeRangeChange={handleTimeRangeChange}
            />
          </Card.Content>
        </Card>

        {/* AI Recommendations */}
        {recommendations.length > 0 && (
          <EnhancedRecommendationCard 
            recommendations={recommendations}
            isLoading={aiLoading}
            onViewAll={() => navigation.navigate('Insights')}
          />
        )}

        {/* Quick Actions */}
        <QuickActionsCard 
          onLogFood={() => navigateToLog('food')}
          onLogInsulin={() => navigateToLog('insulin')}
          onViewTrends={() => navigation.navigate('Trends')}
        />
      </ScrollView>



      {/* Snackbar */}
      <Snackbar
        visible={snackbarVisible}
        onDismiss={() => setSnackbarVisible(false)}
        duration={3000}
      >
        {snackbarMessage}
      </Snackbar>

      {/* Dexcom Connection Modal */}
      <Portal>
        <Modal
          visible={showDexcomModal}
          onDismiss={skipDexcomConnect}
          contentContainerStyle={styles.modalContainer}>
          <Text variant="headlineSmall" style={styles.modalTitle}>
            Connect Your Dexcom
          </Text>
          <Text variant="bodyMedium" style={styles.modalText}>
            To get the most out of GluCoPilot, please connect your Dexcom CGM account. 
            This will allow us to automatically sync your glucose readings.
          </Text>
          <Text variant="bodyMedium" style={[styles.modalText, styles.warningText]}>
            Without Dexcom connection, most features of the app will not work properly.
          </Text>
          <Button 
            mode="contained" 
            style={styles.modalButton}
            onPress={handleDexcomConnect}>
            Connect Dexcom
          </Button>
          <Button 
            onPress={skipDexcomConnect}>
            I'll do this later
          </Button>
        </Modal>
      </Portal>
    </View>
  );
};
