import { StyleSheet } from 'react-native';
import { useTheme } from 'react-native-paper';

export const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollView: {
    flex: 1,
    padding: 16,
  },
  header: {
    marginBottom: 16,
  },
  greeting: {
    fontWeight: 'bold',
    marginBottom: 4,
  },
  lastSync: {
    opacity: 0.7,
  },
  chartCard: {
    marginVertical: 8,
    borderRadius: 12,
    elevation: 2,
  },
  cardTitle: {
    marginBottom: 12,
    fontWeight: 'bold',
  },
});
