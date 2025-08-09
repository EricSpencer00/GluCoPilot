import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

const AiFeedbackScreen = () => {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>AI Feedback</Text>
      {/* Add feedback UI here */}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
});

export default AiFeedbackScreen;
