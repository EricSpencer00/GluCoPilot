
import React, { useState, useEffect } from 'react';
import { View, Text, Button, FlatList, TouchableOpacity, Modal, StyleSheet } from 'react-native';
import InsulinLogForm from '../components/InsulinLogForm';
import FoodLogForm from '../components/FoodLogForm';

const API_BASE = '/api'; // Adjust if needed

export default function LogsScreen() {
  const [tab, setTab] = useState<'insulin' | 'food'>('insulin');
  const [logs, setLogs] = useState([]);
  const [showForm, setShowForm] = useState(false);

  useEffect(() => {
    fetchLogs();
  }, [tab]);

  const fetchLogs = async () => {
    try {
      const res = await fetch(`${API_BASE}/${tab}/user`);
      setLogs(await res.json());
    } catch (e) {
      setLogs([]);
    }
  };

  const handleDelete = async (id: number) => {
    try {
      await fetch(`${API_BASE}/${tab}/${id}`, { method: 'DELETE' });
      fetchLogs();
    } catch (e) {}
  };

  return (
    <View style={styles.container}>
      <View style={styles.tabRow}>
        <TouchableOpacity style={[styles.tab, tab === 'insulin' && styles.activeTab]} onPress={() => setTab('insulin')}>
          <Text style={styles.tabText}>Insulin</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.tab, tab === 'food' && styles.activeTab]} onPress={() => setTab('food')}>
          <Text style={styles.tabText}>Food</Text>
        </TouchableOpacity>
      </View>
      <FlatList
        data={logs}
        keyExtractor={item => item.id.toString()}
        renderItem={({ item }) => (
          <View style={styles.logItem}>
            <Text style={styles.logText}>
              {tab === 'insulin'
                ? `${item.units} units${item.insulin_type ? ' (' + item.insulin_type + ')' : ''} @ ${new Date(item.timestamp).toLocaleString()}`
                : `${item.name || 'Food'}: ${item.carbs}g carbs @ ${new Date(item.timestamp).toLocaleString()}`}
            </Text>
            <TouchableOpacity style={styles.deleteBtn} onPress={() => handleDelete(item.id)}>
              <Text style={styles.deleteText}>Delete</Text>
            </TouchableOpacity>
          </View>
        )}
        ListEmptyComponent={<Text style={styles.emptyText}>No logs yet.</Text>}
      />
      <Button title={`Add ${tab === 'insulin' ? 'Insulin' : 'Food'} Log`} onPress={() => setShowForm(true)} />
      <Modal visible={showForm} animationType="slide" onRequestClose={() => setShowForm(false)}>
        {tab === 'insulin'
          ? <InsulinLogForm onSuccess={() => { setShowForm(false); fetchLogs(); }} onCancel={() => setShowForm(false)} />
          : <FoodLogForm onSuccess={() => { setShowForm(false); fetchLogs(); }} onCancel={() => setShowForm(false)} />}
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16, backgroundColor: '#fff' },
  tabRow: { flexDirection: 'row', marginBottom: 16 },
  tab: { flex: 1, padding: 12, alignItems: 'center', borderBottomWidth: 2, borderBottomColor: '#eee' },
  activeTab: { borderBottomColor: '#007AFF' },
  tabText: { fontSize: 16, fontWeight: 'bold' },
  logItem: { padding: 12, borderBottomWidth: 1, borderBottomColor: '#eee', flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  logText: { fontSize: 15, flex: 1 },
  deleteBtn: { marginLeft: 12, padding: 6, backgroundColor: '#ffdddd', borderRadius: 6 },
  deleteText: { color: '#c00', fontWeight: 'bold' },
  emptyText: { textAlign: 'center', color: '#888', marginTop: 32 },
});
