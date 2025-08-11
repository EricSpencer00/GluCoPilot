import api from './api';

export const getDetailedInsight = async (recommendation: any) => {
  try {
    const response = await api.post('/api/v1/insights/detailed-insight', recommendation);
    return response.data;
  } catch (error) {
    console.error('Error fetching detailed insight:', error);
    throw error;
  }
};
