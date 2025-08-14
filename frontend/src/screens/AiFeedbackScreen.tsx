import React, { useState } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, KeyboardAvoidingView, Platform } from 'react-native';

const AiFeedbackScreen = ({ route }: { route?: any }) => {
  // Accept prefill from navigation params
  const prefill = route?.params?.prefill || '';
  const [feedback, setFeedback] = useState(prefill);
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = () => {
    // Here you would send feedback to your backend or analytics
    setSubmitted(true);
    setFeedback('');
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <Text style={styles.title}>AI Feedback</Text>
      <View style={styles.aiMonitorBox}>
        <Text style={styles.aiMonitorText}>
          <Text style={{ fontWeight: 'bold' }}>AI Monitor:</Text> I am here to help improve! Please let me know if my response was helpful or if you have suggestions.
        </Text>
      </View>
      {submitted ? (
        <Text style={styles.thankYou}>Thank you for your feedback!</Text>
      ) : (
        <>
          <TextInput
            style={styles.input}
            placeholder="Describe your feedback..."
            value={feedback}
            onChangeText={setFeedback}
            multiline
            numberOfLines={4}
            textAlignVertical="top"
          />
          <TouchableOpacity
            style={[styles.button, !feedback.trim() && styles.buttonDisabled]}
            onPress={handleSubmit}
            disabled={!feedback.trim()}
          >
            <Text style={styles.buttonText}>Submit Feedback</Text>
          </TouchableOpacity>
        </>
      )}
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#fff',
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    color: '#222',
  },
  aiMonitorBox: {
    backgroundColor: '#e6f0fa',
    borderRadius: 10,
    padding: 15,
    marginBottom: 25,
    width: '100%',
    borderWidth: 1,
    borderColor: '#b3d1f7',
  },
  aiMonitorText: {
    color: '#2a4d7c',
    fontSize: 16,
  },
  input: {
    width: '100%',
    minHeight: 80,
    borderColor: '#ccc',
    borderWidth: 1,
    borderRadius: 8,
    padding: 10,
    fontSize: 16,
    marginBottom: 15,
    backgroundColor: '#fafbfc',
  },
  button: {
    backgroundColor: '#2a4d7c',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    width: '100%',
  },
  buttonDisabled: {
    backgroundColor: '#b3b3b3',
  },
  buttonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  thankYou: {
    fontSize: 18,
    color: '#2a4d7c',
    marginTop: 20,
    textAlign: 'center',
  },
});

export default AiFeedbackScreen;
