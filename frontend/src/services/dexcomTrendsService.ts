import api from './api';

export async function fetchDexcomTrends(days: number = 30, startDate?: Date | null, endDate?: Date | null) {
  const params: any = { days };
  if (startDate) params.startDate = startDate.toISOString().split('T')[0];
  if (endDate) params.endDate = endDate.toISOString().split('T')[0];
  const response = await api.get('/trends/dexcom', {
    params,
    withCredentials: true,
  });
  return response.data;
}
