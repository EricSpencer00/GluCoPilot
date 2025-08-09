import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Button, Text } from 'react-native-paper';
import { useNavigation, CompositeNavigationProp } from '@react-navigation/native';
import { useSelector } from 'react-redux';
import { RootState } from '../store/store';
import { StackNavigationProp } from '@react-navigation/stack';
import { AuthStackParamList, ProfileStackParamList } from '../navigation/types';

type ProfileScreenNavigationProp = CompositeNavigationProp<
  StackNavigationProp<AuthStackParamList, 'Login'>,
  StackNavigationProp<ProfileStackParamList, 'ProfileMain'>
>;

const ProfileScreen: React.FC = () => {
  const navigation = useNavigation<ProfileScreenNavigationProp>();
  const user = useSelector((state: RootState) => state.auth.user);

  const handleDexcomIntegration = () => {
    navigation.navigate('DexcomLogin');
  };

  const handleLogout = () => {
    console.log('User logged out');
    navigation.reset({
      index: 0,
      routes: [{ name: 'Login' }],
    });
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
      <Button mode="outlined" onPress={handleLogout} style={styles.button}>
        Logout
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
