import axios from 'axios';

export async function fetchDexcomTrends(days: number = 30) {
  const response = await axios.get(`/api/trends/dexcom`, {
    params: { days },
    withCredentials: true,
  });
  return response.data;
}
