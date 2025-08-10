

import React, { useEffect, useState } from 'react';
import { View, StyleSheet, Dimensions, Image } from 'react-native';
import { Text } from 'react-native-paper';

const { width } = Dimensions.get('window');

const loadingSmall = require('../../../assets/loading-small.gif');
const loadingMedium = require('../../../assets/loading-medium.gif');

export const LoadingScreen: React.FC = () => {
  const [showMedium, setShowMedium] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setShowMedium(true), 300);
    return () => clearTimeout(timer);
  }, []);

  return (
    <View style={styles.container}>
      <Image
        source={showMedium ? loadingMedium : loadingSmall}
        style={{ width: width * 0.7, height: width * 0.7 }}
        resizeMode="contain"
      />
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
