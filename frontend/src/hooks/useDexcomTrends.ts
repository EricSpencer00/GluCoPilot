import { useEffect, useState } from 'react';
import { fetchDexcomTrends } from '../services/dexcomTrendsService';

export function useDexcomTrends(days: number) {
  const [trends, setTrends] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    fetchDexcomTrends(days)
      .then(setTrends)
      .catch(e => setError(e.message || 'Failed to load trends'))
      .finally(() => setLoading(false));
  }, [days]);

  return { trends, loading, error };
}
