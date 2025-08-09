import { DefaultTheme as NavigationDefaultTheme } from '@react-navigation/native';
import { DefaultTheme as PaperDefaultTheme } from 'react-native-paper';

const colors = {
  primary: '#4285F4',
  accent: '#34A853',
  background: '#f5f5f5',
  surface: '#ffffff',
  text: '#212121',
  error: '#EA4335',
  warning: '#FBBC05',
  success: '#34A853',
  disabled: '#9e9e9e',
  placeholder: '#9e9e9e',
  backdrop: 'rgba(0, 0, 0, 0.5)',
  notification: '#EA4335',
  lowGlucose: '#EA4335',
  highGlucose: '#FBBC05',
  inRangeGlucose: '#34A853',
};

export const theme = {
  ...PaperDefaultTheme,
  ...NavigationDefaultTheme,
  colors: {
    ...PaperDefaultTheme.colors,
    ...NavigationDefaultTheme.colors,
    ...colors,
  },
  roundness: 12,
  animation: {
    scale: 1.0,
  },
};
