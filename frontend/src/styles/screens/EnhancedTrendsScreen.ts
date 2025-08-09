import { StyleSheet } from 'react-native';

export const enhancedTrendsStyles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    margin: 16,
    fontWeight: 'bold',
  },
  chartCard: {
    margin: 16,
    borderRadius: 12,
    elevation: 2,
  },
  cardTitle: {
    marginBottom: 8,
    fontWeight: 'bold',
  },
  loader: {
    marginVertical: 24,
  },
  patternsContainer: {
    marginVertical: 12,
  },
  timeLabelsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  timeLabel: {
    fontSize: 10,
    color: '#888',
  },
  patternBars: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    height: 100,
    marginVertical: 8,
  },
  patternBar: {
    flex: 1,
    alignItems: 'center',
    height: 100,
    justifyContent: 'flex-end',
  },
  patternBarInner: {
    width: 8,
    borderRadius: 4,
    minHeight: 4,
  },
  patternBarLabel: {
    fontSize: 8,
    color: '#888',
    marginTop: 4,
    transform: [{ rotate: '-45deg' }],
  },
  patternLegend: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 16,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 8,
  },
  legendColor: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 4,
  },
  legendText: {
    fontSize: 12,
    color: '#666',
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginVertical: 8,
  },
  statItem: {
    width: '50%',
    paddingVertical: 12,
    paddingHorizontal: 8,
    alignItems: 'center',
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    color: '#666',
  },
  noDataContainer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
});
