// src/composables/useTransactions.js

import { ref } from 'vue';
import axios from 'axios';

// Global state (singleton)
const transactions = ref([]);
const categories = ref([]);

// This function will be our single source of truth for transaction logic
export function useTransactions() {

  // Methods
  const fetchTransactions = async () => {
    try {
      const response = await axios.get('/api/transactions');
      transactions.value = Array.isArray(response.data) ? response.data : [];
    } catch (error) {
      console.error('Error fetching transactions:', error);
      transactions.value = [];
    }
  };

  const fetchCategories = async () => {
    try {
      const response = await axios.get('/api/categories');
      categories.value = response.data;
    } catch (error) {
      console.error('Error fetching categories:', error);
    }
  };

  // We can add delete and update logic here in the future

  const deleteTransaction = async (id) => {
    try {
      await axios.delete(`/api/transactions/${id}`);
      // Optimistic update — the backend also removes the other leg of a transfer pair
      transactions.value = transactions.value.filter(t => t.id !== id && t.transfer_related_id !== id);
    } catch (error) {
      console.error('Error deleting transaction:', error);
      // Re-fetch to ensure sync
      await fetchTransactions();
    }
  };

  const updateTransaction = async (updatedData) => {
    // No optimistic patch here: editing a transfer replaces BOTH legs with new
    // ids on the backend, so a single-row patch would leave stale data. Errors
    // propagate to the caller for user feedback.
    try {
      await axios.put(`/api/transactions/${updatedData.id}`, updatedData);
    } finally {
      await fetchTransactions();
    }
  };

  // Return the state and methods so components can use them
  return {
    transactions,
    categories,
    fetchTransactions,
    fetchCategories,
    deleteTransaction,
    updateTransaction
  };
}