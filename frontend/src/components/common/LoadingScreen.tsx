

import React, { useEffect, useState } from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { Text } from 'react-native-paper';

import { LoadingAnimation } from './LoadingAnimation';

const { width } = Dimensions.get('window');



export const LoadingScreen: React.FC = () => {
  return (
    <View style={styles.container}>
      <LoadingAnimation />
      <Text style={styles.text}>Loading...</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  text: {
    marginTop: 16,
    fontSize: 16,
    color: '#b34d4d',
    fontWeight: '600',
    letterSpacing: 0.5,
  },
});
