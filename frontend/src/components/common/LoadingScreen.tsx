

import React from 'react';
import { View, StyleSheet } from 'react-native';
import { ActivityIndicator, Text } from 'react-native-paper';

export const LoadingScreen: React.FC = () => {
  return (
    <View style={styles.container}>
      <ActivityIndicator size="large" color="#fff" />
      <Text style={styles.text}>Loading...</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#00796B', // Deep Teal for GlucoPilot brand
  },
  text: {
    marginTop: 16,
    fontSize: 16,
    color: '#FFFFFF', // White text for contrast
    fontWeight: '600',
    letterSpacing: 0.5,
  },
});
