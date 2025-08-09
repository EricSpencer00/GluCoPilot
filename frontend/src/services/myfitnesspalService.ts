import axios from 'axios';

export async function fetchMyFitnessPalFoodLogs(startDate: string, endDate: string) {
  const response = await axios.get(`/api/myfitnesspal/food-logs`, {
    params: { start_date: startDate, end_date: endDate },
    withCredentials: true,
  });
  return response.data;
}
