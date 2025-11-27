// src/composables/useTransactions.js

import { ref } from 'vue';
import axios from 'axios';

// This function will be our single source of truth for transaction logic
export function useTransactions() {
  
  // Reactive state
  const transactions = ref([]);
  const categories = ref([]);

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
  
  // Return the state and methods so components can use them
  return {
    transactions,
    categories,
    fetchTransactions,
    fetchCategories,
  };
}