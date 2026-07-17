import { ref } from 'vue';
import axios from 'axios';

// Global state (singleton), same pattern as useTransactions
const accounts = ref([]);

export function useAccounts() {
  const fetchAccounts = async () => {
    try {
      const response = await axios.get('/api/accounts');
      accounts.value = Array.isArray(response.data) ? response.data : [];
    } catch (error) {
      console.error('Error fetching accounts:', error);
      accounts.value = [];
    }
  };

  const saveAccount = async (account) => {
    if (account.id) {
      await axios.put(`/api/accounts/${account.id}`, account);
    } else {
      await axios.post('/api/accounts', account);
    }
    await fetchAccounts();
  };

  const deleteAccount = async (id) => {
    await axios.delete(`/api/accounts/${id}`);
    await fetchAccounts();
  };

  return {
    accounts,
    fetchAccounts,
    saveAccount,
    deleteAccount
  };
}
