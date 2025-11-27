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
      transactions.value = response.data;
    } catch (error) {
      console.error('Error fetching transactions:', error);
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
      // Optimistic update
      transactions.value = transactions.value.filter(t => t.id !== id);
    } catch (error) {
      console.error('Error deleting transaction:', error);
      // Re-fetch to ensure sync
      await fetchTransactions();
    }
  };

  const updateTransaction = async (updatedData) => {
    try {
      const response = await axios.put(`/api/transactions/${updatedData.id}`, updatedData);
      // Optimistic update
      const index = transactions.value.findIndex(t => t.id === updatedData.id);
      if (index !== -1) {
        transactions.value[index] = response.data;
      }
    } catch (error) {
      console.error('Error updating transaction:', error);
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