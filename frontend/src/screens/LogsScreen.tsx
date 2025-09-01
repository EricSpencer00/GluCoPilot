
import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, FlatList, TouchableOpacity, Modal, StyleSheet, TextInput, RefreshControl } from 'react-native';
import InsulinLogForm from '../components/InsulinLogForm';
import FoodLogForm from '../components/FoodLogForm';
import OtherLogForm from '../components/OtherLogForm';
import { cacheLog, getCachedLogs } from '../utils/logCache';

const API_BASE = '/api/v1';

interface LogItem {
  id: string;
  type: 'food' | 'insulin' | 'other';
  timestamp: string;
  name?: string;
  carbs?: number;
  units?: number;
  insulin_type?: string;
  category?: string;
  notes?: string;
}

const LOG_TYPES = [
  { key: 'all', label: 'All' },
  { key: 'food', label: 'Food' },
  { key: 'insulin', label: 'Insulin' },
  { key: 'other', label: 'Other' },
];

const ICONS = {
  food: '🍽️',
  insulin: '💉',
  other: '➕',
};

const COLORS = {
  food: '#FFA726',
  insulin: '#42A5F5',
  other: '#AB47BC',
};

export default function LogsScreen() {
  const [filter, setFilter] = useState('all');
  const [logs, setLogs] = useState<LogItem[]>([]);
  const [showModal, setShowModal] = useState<null | 'food' | 'insulin' | 'other'>(null);
  const [search, setSearch] = useState('');
  const [refreshing, setRefreshing] = useState(false);


  useEffect(() => {
    fetchLogs();
  }, []);

  const fetchLogs = async () => {
    try {
      // Fetch all logs from backend (should be unified endpoint in future)
      const [foodRes, insulinRes] = await Promise.all([
        fetch(`${API_BASE}/food/user`).then(r => r.json()),
        fetch(`${API_BASE}/insulin/user`).then(r => r.json()),
      ]);
      // Add type for rendering
      const foodLogs = foodRes.map((l: any) => ({ ...l, type: 'food' }));
      const insulinLogs = insulinRes.map((l: any) => ({ ...l, type: 'insulin' }));
      // TODO: fetch other logs when backend ready
      const allLogs = [...foodLogs, ...insulinLogs].sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
      setLogs(allLogs);
      // Cache logs locally
      allLogs.forEach(log => cacheLog(log));
    } catch (e) {
      // If fetch fails, fallback to cache
      const cached = await getCachedLogs();
      setLogs(cached);
    }
  };

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await fetchLogs();
    setRefreshing(false);
  }, []);

  // When a log is created, cache it immediately
  const handleLogSuccess = async (log: any) => {
    await cacheLog(log);
    fetchLogs();
    setShowModal(null);
  };

  const handleDelete = async (item: any) => {
    try {
      await fetch(`${API_BASE}/${item.type}/${item.id}`, { method: 'DELETE' });
      fetchLogs();
    } catch (e) {}
  };

  const filteredLogs = logs.filter(l =>
    (filter === 'all' || l.type === filter) &&
    (!search || (l.name?.toLowerCase().includes(search.toLowerCase()) || l.insulin_type?.toLowerCase().includes(search.toLowerCase()) || l.notes?.toLowerCase().includes(search.toLowerCase()) ))
  );

  return (
    <View style={styles.container}>
      {/* Quick Add Card */}
      <View style={styles.quickAddCard}>
        <TouchableOpacity style={[styles.quickBtn, { backgroundColor: COLORS.food }]} onPress={() => setShowModal('food')}>
          <Text style={styles.quickBtnText}>{ICONS.food} Log Food</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.quickBtn, { backgroundColor: COLORS.insulin }]} onPress={() => setShowModal('insulin')}>
          <Text style={styles.quickBtnText}>{ICONS.insulin} Log Insulin</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.quickBtn, { backgroundColor: COLORS.other }]} onPress={() => setShowModal('other')}>
          <Text style={styles.quickBtnText}>{ICONS.other} Log Other</Text>
        </TouchableOpacity>
      </View>

      {/* Filter Bar */}
      <View style={styles.filterBar}>
        {LOG_TYPES.map(t => (
          <TouchableOpacity key={t.key} style={[styles.filterBtn, filter === t.key && styles.activeFilterBtn]} onPress={() => setFilter(t.key)}>
            <Text style={[styles.filterText, filter === t.key && styles.activeFilterText]}>{t.label}</Text>
          </TouchableOpacity>
        ))}
        <TextInput
          style={styles.searchInput}
          placeholder="Search"
          value={search}
          onChangeText={setSearch}
        />
      </View>

      {/* Timeline/List */}
      <FlatList
        data={filteredLogs}
        keyExtractor={item => `${item.type}-${item.id}`}
        renderItem={({ item }) => (
          <View style={[styles.logItem, { borderLeftColor: COLORS[item.type] || '#ccc' }]}> 
            <Text style={styles.logIcon}>{ICONS[item.type]}</Text>
            <View style={{ flex: 1 }}>
              <Text style={styles.logTime}>{new Date(item.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</Text>
              <Text style={styles.logSummary}>
                {item.type === 'food' && `${item.name || 'Food'}: ${item.carbs}g carbs`}
                {item.type === 'insulin' && `${item.units}U ${item.insulin_type}`}
                {item.type === 'other' && item.category}
              </Text>
              {item.notes && <Text style={styles.logNotes}>{item.notes}</Text>}
            </View>
            <TouchableOpacity style={styles.deleteBtn} onPress={() => handleDelete(item)}>
              <Text style={styles.deleteText}>Delete</Text>
            </TouchableOpacity>
          </View>
        )}
        ListEmptyComponent={<Text style={styles.emptyText}>No logs yet.</Text>}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      />

      {/* Modal Sheets for Logging */}
      <Modal visible={!!showModal} animationType="slide" onRequestClose={() => setShowModal(null)}>
        {showModal === 'insulin' && <InsulinLogForm onSuccess={log => handleLogSuccess({ ...log, type: 'insulin' })} onCancel={() => setShowModal(null)} />}
        {showModal === 'food' && <FoodLogForm onSuccess={log => handleLogSuccess({ ...log, type: 'food' })} onCancel={() => setShowModal(null)} />}
        {showModal === 'other' && <OtherLogForm onSuccess={log => handleLogSuccess({ ...log, type: 'other' })} onCancel={() => setShowModal(null)} />}
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 8, backgroundColor: '#fff' },
  quickAddCard: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 12, gap: 8 },
  quickBtn: { flex: 1, padding: 16, borderRadius: 12, alignItems: 'center', marginHorizontal: 2 },
  quickBtnText: { color: '#fff', fontWeight: 'bold', fontSize: 16 },
  filterBar: { flexDirection: 'row', alignItems: 'center', marginBottom: 8, gap: 4 },
  filterBtn: { paddingVertical: 6, paddingHorizontal: 12, borderRadius: 8, backgroundColor: '#eee', marginRight: 4 },
  activeFilterBtn: { backgroundColor: '#007AFF' },
  filterText: { color: '#333', fontWeight: 'bold' },
  activeFilterText: { color: '#fff' },
  searchInput: { flex: 1, borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 6, marginLeft: 8 },
  logItem: { flexDirection: 'row', alignItems: 'center', padding: 12, borderBottomWidth: 1, borderBottomColor: '#eee', borderLeftWidth: 5, marginBottom: 2 },
  logIcon: { fontSize: 28, marginRight: 12 },
  logTime: { fontSize: 13, color: '#888' },
  logSummary: { fontSize: 16, fontWeight: 'bold' },
  logNotes: { fontSize: 13, color: '#666' },
  deleteBtn: { marginLeft: 12, padding: 6, backgroundColor: '#ffdddd', borderRadius: 6 },
  deleteText: { color: '#c00', fontWeight: 'bold' },
  emptyText: { textAlign: 'center', color: '#888', marginTop: 32 },
});
