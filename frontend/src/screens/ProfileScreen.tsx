import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Button, Text } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { useSelector } from 'react-redux';
import { RootState } from '../store/store';
import { StackNavigationProp } from '@react-navigation/stack';
import { AuthStackParamList } from '../navigation/types';

const ProfileScreen: React.FC = () => {
  const navigation = useNavigation<StackNavigationProp<AuthStackParamList, 'Profile'>>();
  const user = useSelector((state: RootState) => state.auth.user);

  const handleDexcomIntegration = () => {
    navigation.navigate('DexcomLogin');
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
    <View style={styles.container}>
      <Text variant="headlineSmall" style={styles.title}>Profile</Text>
      <View>
        <Text>Email: {user.email}</Text>
        <Text>Name: {user.first_name} {user.last_name}</Text>
      </View>
      <Button mode="contained" onPress={handleDexcomIntegration} style={styles.button}>
        Integrate with Dexcom
      </Button>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 16 },
  title: { marginBottom: 16 },
  button: { marginTop: 16 },
});

export default ProfileScreen;
