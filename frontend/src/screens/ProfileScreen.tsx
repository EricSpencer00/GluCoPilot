import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Button, Text } from 'react-native-paper';
import { useDispatch, useSelector } from 'react-redux';
import { RootState } from '../store/store';
import { useNavigation } from '@react-navigation/native';

const ProfileScreen: React.FC = () => {
  const dispatch = useDispatch();
  const navigation = useNavigation();
  const { user } = useSelector((state: RootState) => state.auth);

  const handleDexcomIntegration = () => {
    navigation.navigate('DexcomLogin');
  };

  return (
    <View style={styles.container}>
      <Text variant="headlineSmall" style={styles.title}>Profile</Text>
      {user && (
        <View>
          <Text>Email: {user.email}</Text>
          <Text>Name: {user.first_name} {user.last_name}</Text>
        </View>
      )}
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
