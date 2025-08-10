import React, { useEffect, useState } from 'react';
import { View, StyleSheet, Dimensions, Image } from 'react-native';

const { width } = Dimensions.get('window');


import loadingSmall from '../../../assets/loading-small.gif';
import loadingMedium from '../../../assets/loading-medium.gif';

export const LoadingAnimation: React.FC = () => {
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
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
});
