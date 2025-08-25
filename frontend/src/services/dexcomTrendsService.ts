import api from './api';
import { secureStorage, DEXCOM_USERNAME_KEY, DEXCOM_PASSWORD_KEY, DEXCOM_OUS_KEY } from './secureStorage';

export async function fetchDexcomTrends(days: number = 30, startDate?: Date | null, endDate?: Date | null) {
  const params: any = { days };
  if (startDate) params.startDate = startDate.toISOString().split('T')[0];
  if (endDate) params.endDate = endDate.toISOString().split('T')[0];

  // Try to include stored Dexcom credentials (stateless servers require creds per-call).
  const username = await secureStorage.getItem(DEXCOM_USERNAME_KEY);
  const password = await secureStorage.getItem(DEXCOM_PASSWORD_KEY);
  const ousRaw = await secureStorage.getItem(DEXCOM_OUS_KEY);
  const ous = ousRaw === 'true' || ousRaw === '1';

  if (username && password) {
    // Use POST to allow passing credentials in the body for stateless endpoints.
    const body: any = { username, password, ous, days };
    if (startDate) body.startDate = params.startDate;
    if (endDate) body.endDate = params.endDate;

    const response = await api.post('/trends/dexcom', body);
    return response.data;
  }

  // No device credentials: do NOT call server GET in stateless deployments (prevents DB queries).
  console.warn('No Dexcom credentials on device — skipping server trends GET to avoid DB calls');
  return null;

  // Fallback: call GET for server-backed deployments that can derive trends without per-call creds.
  // const response = await api.get('/trends/dexcom', {
  //   params,
  //   withCredentials: true,
  // });
  // return response.data;
}
