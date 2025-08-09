
import React from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { Text } from 'react-native-paper';
import LottieView from 'lottie-react-native';


const { width } = Dimensions.get('window');

export const LoadingScreen: React.FC = () => {
  return (
    <View style={styles.container}>
      <LottieView
        source={require('../../../assets/animations/glucose_wave.json')}
        autoPlay
        loop
        style={{ width: width * 0.7, height: width * 0.7 }}
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
