export interface Recommendation {
  title: string;
  description?: string;
  action?: string;
  timing?: string;
  category?: string;
  priority?: string | number;
  confidence?: number;
}
