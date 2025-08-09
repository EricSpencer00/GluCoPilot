

import React from 'react';
import { View, Text, StyleSheet, Button } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { ProfileStackParamList } from '../navigation/types';

const SettingsScreen = () => {
  const navigation = useNavigation<StackNavigationProp<ProfileStackParamList, 'Settings'>>();
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Settings</Text>
      <Button title="AI Feedback" onPress={() => navigation.navigate('AiFeedback')} />
      {/* Add your settings options here */}
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

export default SettingsScreen;
