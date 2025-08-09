import axios from 'axios';

export async function fetchAppleHealthActivity(startDate: string, endDate: string) {
  const response = await axios.get(`/api/apple-health/activity`, {
    params: { start_date: startDate, end_date: endDate },
    withCredentials: true,
  });
  return response.data;
}
