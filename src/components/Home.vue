<template>
  <div class="container">
    <!-- Total Balance Section -->
    <div class="total-balance-card">
      <h2 class="total-balance-title">Total Balance</h2>
      <p class="total-balance-amount">RM {{ totalBalance.toFixed(2) }}</p>
    </div>

    <div class="upload-section">
      <h2>Upload Transaction Records</h2>
      <input type="file" @change="handleFileUpload" ref="fileInput" id="file-upload" class="file-input-hidden">
      <label for="file-upload" class="file-upload-label">
        <span class="icon">📁</span> Choose Image
      </label>
      <span class="file-name">{{ selectedFile ? selectedFile.name : 'No file selected' }}</span>

      <button @click="uploadImage" :disabled="!selectedFile || isLoading" class="upload-button">
        {{ isLoading ? 'Processing...' : 'Upload and Scan' }}
      </button>
      <p v-if="message" class="message">{{ message }}</p>
    </div>

    <div class="manual-entry-section">
      <h2>Manual Entry</h2>
      <form @submit.prevent="addManualTransaction">
        <div class="form-row">
            <div class="form-group half-width">
                <label for="manual-date">Date</label>
                <input type="date" id="manual-date" v-model="manualForm.date" required>
            </div>
            
            <div class="form-group half-width">
                <label for="manual-time">Time</label>
                <input type="time" id="manual-time" v-model="manualForm.time" step="1" required>
            </div>
        </div>

        <div class="form-row">
            <div class="form-group half-width">
                <label for="manual-amount">Amount (RM)</label>
                <input type="number" id="manual-amount" v-model.number="manualForm.amount" step="0.01" required>
            </div>
            
            <div class="form-group half-width">
                <label for="manual-description">Description</label>
                <input type="text" id="manual-description" v-model="manualForm.description" required>
            </div>
        </div>
        
        <div class="form-group mb-4">
            <label class="block font-semibold mb-2">Transaction Type</label>
            <div class="type-selector">
                <div 
                    class="type-option expense" 
                    :class="{ active: manualForm.type === 'expense' }"
                    @click="manualForm.type = 'expense'"
                >
                    Expense
                </div>
                <div 
                    class="type-option income" 
                    :class="{ active: manualForm.type === 'income' }"
                    @click="manualForm.type = 'income'"
                >
                    Income
                </div>
                <div 
                    class="type-option transfer" 
                    :class="{ active: manualForm.type === 'transfer' }"
                    @click="manualForm.type = 'transfer'"
                >
                    Transfer
                </div>
            </div>
        </div>

        <div class="form-row">
            <div class="form-group half-width">
               <!-- Dynamic Label based on type -->
                <label for="manual-account">
                    {{ manualForm.type === 'transfer' ? 'From Account' : 'Account' }} 
                </label>
                <select id="manual-account" v-model="manualForm.account_id">
                    <option :value="null">Unassigned</option>
                    <option v-for="acc in accounts" :key="acc.id" :value="acc.id">{{ acc.name }}</option>
                </select>
            </div>
            
            <!-- Category is hidden for transfers -->
            <div class="form-group half-width" v-if="manualForm.type !== 'transfer'">
                <label for="manual-category">Category</label>
                <select id="manual-category" v-model="manualForm.category">
                    <option v-for="cat in availableCategories" :key="cat" :value="cat">{{ cat }}</option>
                </select>
            </div>

            <!-- To Account for Transfers -->
            <div class="form-group half-width" v-if="manualForm.type === 'transfer'">
                <label for="to-account">To Account</label>
                <select id="to-account" v-model="manualForm.to_account_id">
                    <option :value="null">Select Account</option>
                    <option 
                        v-for="acc in accounts" 
                        :key="acc.id" 
                        :value="acc.id"
                        :disabled="acc.id === manualForm.account_id"
                    >
                        {{ acc.name }}
                    </option>
                </select>
            </div>
        </div>

        <button type="submit" :disabled="isLoading" class="submit-manual-button">
          {{ isLoading ? 'Saving...' : 'Add Transaction' }}
        </button>
      </form>
    </div>

    <div class="transactions-list">
      <h2>Recent Transactions</h2>
      <div class="view-all-link">
        <router-link to="/all">View All Transactions &rarr;</router-link>
      </div>
      <div v-if="transactions.length === 0" class="no-transactions">
        No transactions found.
      </div>
      <ul v-else>
        <li v-for="transaction in latestTransactions" :key="transaction.id">
          <div class="transaction-info">
            <div class="details">
                <div class="date-time-row">
                    <span class="date">{{ transaction.date }}</span>
                    <span class="time-pill">{{ transaction.time }}</span>
                </div>
                <span class="description">{{ transaction.description }}</span>
            </div>
            <div class="category-and-amount">
                <!-- Display the category if it exists -->
                <span v-if="transaction.category" class="category-pill" :class="{ 'income': transaction.type === 'income' }">{{ transaction.category }}</span>
                <span class="amount">{{ transaction.amount }}</span>
            </div>
          </div>
          <div class="action-buttons">
            <button @click="openEditModal(transaction)" class="icon-btn edit" title="Edit">✎</button>
            <button @click="deleteTransaction(transaction.id)" class="icon-btn delete" title="Delete">🗑</button>
          </div>
        </li>
      </ul>
    </div>
  </div>

  <ConfirmationModal
    v-if="isConfirmationModalVisible"
    :scannedData="scannedData"
    :categories="categories"
    :accounts="accounts"
    @close="handleCancelConfirmation"
    @save="handleSaveConfirmation"
  />

  <EditModal 
    v-if="isModalVisible" 
    :transaction="transactionToEdit"
    :categories="categories"
    :accounts="accounts"
    @close="isModalVisible = false"
    @save="handleSaveTransaction"
  />
</template>

<script>
import { ref, computed, onMounted, watch } from 'vue';
import { useTransactions } from '../composables/useTransactions';
import { useIntent } from '../composables/useIntent';
import EditModal from '../components/EditModal.vue';
import ConfirmationModal from '../components/ConfirmationModal.vue';
import axios from 'axios';
import { logger } from '../utils/logger';
import { registerPlugin } from '@capacitor/core';
const SendIntent = registerPlugin('SendIntent');


export default {
  name: 'HomePage',
  components: {
    EditModal,
    ConfirmationModal,
  },
  setup() {
    // --- COMPOSABLE ---
    const { transactions, fetchTransactions } = useTransactions();
    const { sharedIntentData, intentConsumed, clearIntentData, consumeIntent } = useIntent();

    // --- STATE ---
    const selectedFile = ref(null);
    const isLoading = ref(false);
    const isProcessingIntent = ref(false);
    const message = ref('');
    const categories = ref([]);
    const manualForm = ref({
      date: new Date().toISOString().substr(0, 10),
      time: new Date().toTimeString().substr(0, 8),
      description: '',
      amount: '',
      category: 'Uncategorized',
      account_id: null,
      to_account_id: null,
      type: 'expense'
    });
    
    // Account related state
    const accounts = ref([]);
    const totalBalance = ref(0);
    
    // Load accounts
    const fetchAccounts = async () => {
        try {
            const res = await axios.get('/api/accounts');
            // Defensive check to prevent reduce errors if API fails or returns non-array
            accounts.value = Array.isArray(res.data) ? res.data : [];
            totalBalance.value = accounts.value.reduce((sum, acc) => sum + (acc.balance || 0), 0);
        } catch (err) {
            console.error("Failed to load accounts", err);
            accounts.value = [];
            totalBalance.value = 0;
        }
    };
    const scannedData = ref(null);
    const isConfirmationModalVisible = ref(false);
    const isModalVisible = ref(false);
    const transactionToEdit = ref(null);
    const fileInput = ref(null); // To reference the file input element

    // --- COMPUTED ---
    const availableCategories = computed(() => {
        if (!categories.value) return [];
        // If categories is still an array (legacy), return it
        if (Array.isArray(categories.value)) return categories.value;
        
        // Return based on type
        const type = manualForm.value.type;
        if (type === 'income') return categories.value.income || [];
        if (type === 'transfer') return []; // Should be hidden anyway
        return categories.value.expense || [];
    });

    const latestTransactions = computed(() => {
      // The transactions array is now reactive from the composable
      return transactions.value.slice(0, 5);
    });

    // --- METHODS ---
    const handleFileUpload = (event) => {
      selectedFile.value = event.target.files[0];
      message.value = '';
    };

    const uploadImage = async () => {
      if (!selectedFile.value) return;
      isLoading.value = true;
      message.value = 'Scanning...';
      const formData = new FormData();
      formData.append('file', selectedFile.value);
      try {
        const response = await axios.post('/api/upload', formData);
        const dateParts = response.data.date.split('/');
        const formattedDate = `${dateParts[2]}-${dateParts[1]}-${dateParts[0]}`;
        const numericAmount = parseFloat(response.data.amount.replace('RM', '').trim());
        scannedData.value = {
          date: formattedDate,
          time: response.data.time || '00:00:00',
          amount: numericAmount,
          category: 'Uncategorized'
        };
        isConfirmationModalVisible.value = true;
        message.value = '';
      } catch (error) {
        message.value = error.response?.data?.error || 'Error scanning file.';
        selectedFile.value = null;
        if (fileInput.value) fileInput.value.value = null;
      } finally {
        isLoading.value = false;
      }
    };

    const handleSaveConfirmation = async (transactionPayload) => {
      isLoading.value = true;
      message.value = 'Saving transaction...';
      try {
        if (transactionPayload.type === 'transfer') {
            if (!transactionPayload.account_id || !transactionPayload.to_account_id) {
                alert("Please select both From and To accounts.");
                isLoading.value = false;
                return;
            }
            const transferPayload = {
                date: transactionPayload.date,
                time: transactionPayload.time,
                description: transactionPayload.description || 'Transfer',
                amount: transactionPayload.amount,
                from_account_id: transactionPayload.account_id,
                to_account_id: transactionPayload.to_account_id
            };
            await axios.post('/api/transactions/transfer', transferPayload);
        } else {
            await axios.post('/api/transactions/manual', transactionPayload);
        }
        message.value = 'Transaction saved successfully!';
        await fetchTransactions(); // Refresh shared data
        await fetchAccounts(); // Refresh accounts to update balance
      } catch (error) {
        message.value = 'Failed to save transaction.';
      } finally {
        isLoading.value = false;
        isConfirmationModalVisible.value = false;
        selectedFile.value = null;
        scannedData.value = null; // Clear scanned data
        consumeIntent(); // Mark intent as fully consumed to prevent re-trigger on remount
        if (fileInput.value) fileInput.value.value = null;
      }
    };

    const handleCancelConfirmation = () => {
      isConfirmationModalVisible.value = false;
      selectedFile.value = null;
      scannedData.value = null;
      message.value = '';
      consumeIntent(); // Mark intent as fully consumed to prevent re-trigger on remount
      if (fileInput.value) fileInput.value.value = null;
    };
    
    const addManualTransaction = async () => {
      isLoading.value = true;
      try {
        const payload = { ...manualForm.value };
        // Ensure date is dd/mm/yyyy
        const parts = payload.date.split('-');
        payload.date = `${parts[2]}/${parts[1]}/${parts[0]}`;
        
        if (payload.type === 'transfer') {
            if (!payload.account_id || !payload.to_account_id) {
                alert("Please select both From and To accounts."); // Simple validation
                isLoading.value = false;
                return;
            }
            // Map fields for transfer endpoint
            const transferPayload = {
                date: payload.date,
                time: payload.time,
                description: payload.description || 'Transfer',
                amount: payload.amount,
                from_account_id: payload.account_id,
                to_account_id: payload.to_account_id
            };
            await axios.post('/api/transactions/transfer', transferPayload);
        } else {
            await axios.post('/api/transactions/manual', payload);
        }
        
        // Refresh transactions and accounts
        await fetchTransactions();
        await fetchAccounts();
        
        // Reset form
        manualForm.value = {
          date: new Date().toISOString().substr(0, 10),
          time: new Date().toTimeString().substr(0, 8),
          description: '',
          amount: '',
          category: 'Uncategorized',
          account_id: null,
          to_account_id: null,
          type: 'expense'
        };
        message.value = 'Transaction added successfully!';
        setTimeout(() => message.value = '', 3000);
      } catch (err) {
        console.error(err);
        message.value = 'Error adding transaction.';
      } finally {
        isLoading.value = false;
      }
    };
    
    const deleteTransaction = async (id) => {
        if (!confirm('Are you sure you want to delete this transaction?')) return;
        try {
            await axios.delete(`/api/transactions/${id}`);
            await fetchTransactions(); // Refresh shared data
            await fetchAccounts(); // Refresh accounts to update balance
        } catch (error) {
            message.value = 'Failed to delete transaction.';
        }
    };
    
    const openEditModal = (transaction) => {
        transactionToEdit.value = transaction;
        isModalVisible.value = true;
    };
    
    const handleSaveTransaction = async (updatedTransaction) => {
        try {
            await axios.put(`/api/transactions/${updatedTransaction.id}`, updatedTransaction);
            isModalVisible.value = false;
            await fetchTransactions(); // Refresh shared data
            await fetchAccounts(); // Refresh accounts to update balance
        } catch (error) {
            alert('Failed to update transaction.');
        }
    };

    // --- WATCHERS ---
    watch(sharedIntentData, async (newData) => {
      // Handle both the 'url' property and the 'extras.STREAM' property from the intent
      const sharedUrl = newData?.url || newData?.extras?.['android.intent.extra.STREAM'];
      
      if (!sharedUrl) {
          if (newData) logger.warn('Intent data present but no valid URL found', 'Home.vue');
          return;
      }

      // Guard: if this intent was already handled (saved or cancelled), skip re-processing.
      // This prevents re-triggering when the component remounts after navigation.
      if (intentConsumed.value) {
          logger.info('Intent already consumed. Skipping re-trigger on remount.', 'Home.vue');
          clearIntentData(); // Clean up stale data
          return;
      }

      // Prevents multiple concurrent triggers
      if (isProcessingIntent.value) {
          logger.info('Intent processing already in progress. Skipping duplicate trigger.', 'Home.vue');
          return;
      }

      logger.info('Intent data watcher triggered. Data: ' + JSON.stringify(newData), 'Home.vue');

      try {
        isProcessingIntent.value = true;
        isLoading.value = true;
        message.value = 'Loading shared image...';
        
        // Clear intent data early so we don't re-trigger from clearing it later
        clearIntentData();
        
        // Use native bridge for content:// URIs as fetch() will fail due to security
        let blob;
        if (sharedUrl.startsWith('content://')) {
          logger.info('Detected content:// URI. Using native readContentUri.', 'Home.vue');
          const result = await SendIntent.readContentUri({ uri: sharedUrl });
          if (result && result.data) {
              const byteCharacters = atob(result.data);
              const byteNumbers = new Array(byteCharacters.length);
              for (let i = 0; i < byteCharacters.length; i++) {
                  byteNumbers[i] = byteCharacters.charCodeAt(i);
              }
              const byteArray = new Uint8Array(byteNumbers);
              blob = new Blob([byteArray], { type: result.mimeType || 'image/jpeg' });
              logger.info('Blob created from Base64. Size: ' + blob.size, 'Home.vue');
          } else {
              throw new Error('Native readContentUri returned no data');
          }
        } else {
          // Standard fetch for file:// or other URIs (if permissions allow)
          logger.info('Attempting to fetch blob from URL: ' + sharedUrl, 'Home.vue');
          const response = await fetch(sharedUrl);
          if (!response.ok) {
             throw new Error(`Fetch failed with status ${response.status}`);
          }
          blob = await response.blob();
          logger.info('Blob fetched successfully via fetch(). Size: ' + blob.size, 'Home.vue');
        }
        
        // Create a file object from the blob
        selectedFile.value = new File([blob], "shared_receipt.jpg", { type: blob.type || 'image/jpeg' });
        
        // Automatically trigger upload and scan
        logger.info('Triggering uploadImage after intent processing', 'Home.vue');
        await uploadImage();
      } catch (error) {
        logger.error('Error handling shared image: ' + error.message, 'Home.vue');
        message.value = 'Failed to load shared image: ' + error.message;
        isLoading.value = false;
      } finally {
        isProcessingIntent.value = false;
      }
    }, { immediate: true });

    // --- LIFECYCLE HOOK ---
    onMounted(() => {
      fetchTransactions();
      fetchAccounts();
        
      // Load categories
      axios.get('/api/categories')
           .then(res => categories.value = res.data)
           .catch(err => console.error(err));
    });

    // --- RETURN ---
    return {
      selectedFile,
      transactions,
      isLoading,
      message,
      scannedData,
      isConfirmationModalVisible,
      isModalVisible,
      transactionToEdit,
      fileInput,
      latestTransactions,
      manualForm,
      categories,
      accounts,
      totalBalance,
      handleFileUpload,
      uploadImage,
      handleSaveConfirmation,
      handleCancelConfirmation,
      addManualTransaction,
      deleteTransaction,
      openEditModal,
      handleSaveTransaction,
      fetchAccounts,
      availableCategories
    };
  }
}
</script>

<style scoped>
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
}

.upload-section {
  background: var(--card-background);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: var(--glass-border);
  padding: 2.5rem;
  border-radius: 16px;
  box-shadow: var(--glass-shadow);
  text-align: center;
  margin-bottom: 2rem;
  transition: transform 0.3s ease;
}

.upload-section:hover {
  transform: translateY(-2px);
}

.upload-section h2 {
  margin-top: 0;
  color: var(--text-color);
  margin-bottom: 1.5rem;
  font-weight: 800;
  font-size: 1.5rem;
}

.file-input-hidden {
  display: none;
}

.file-upload-label {
  background-color: rgba(79, 70, 229, 0.1);
  color: var(--primary-color);
  padding: 1rem 2rem;
  border-radius: 12px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.3s ease;
  margin-bottom: 1rem;
  border: 1px dashed var(--primary-color);
}

.file-upload-label:hover {
  background-color: rgba(79, 70, 229, 0.2);
  transform: scale(1.02);
}

.file-name {
  display: block;
  margin-bottom: 1.5rem;
  color: var(--subtle-text-color);
  font-style: italic;
  font-size: 0.9rem;
}

.upload-button {
  background-color: var(--primary-color);
  color: white;
  border: none;
  padding: 0.875rem 2rem;
  border-radius: 10px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  width: 100%;
  max-width: 300px;
  box-shadow: 0 4px 6px rgba(79, 70, 229, 0.25);
}

.upload-button:disabled {
  background-color: #cbd5e1;
  cursor: not-allowed;
  box-shadow: none;
}

.upload-button:hover:not(:disabled) {
  background-color: var(--secondary-color);
  transform: translateY(-2px);
  box-shadow: 0 6px 12px rgba(79, 70, 229, 0.3);
}

.message {
  margin-top: 1rem;
  color: var(--primary-color);
  font-weight: 500;
}

.manual-entry-section {
  background: var(--card-background);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: var(--glass-border);
  padding: 2.5rem;
  border-radius: 16px;
  box-shadow: var(--glass-shadow);
  margin-bottom: 2rem;
}

.manual-entry-section h2 {
  text-align: center;
  margin-top: 0;
  color: var(--text-color);
  margin-bottom: 2rem;
  font-weight: 800;
  font-size: 1.5rem;
}

.form-group {
  margin-bottom: 1.25rem;
  text-align: left;
}

.form-group label {
  display: block;
  font-weight: 600;
  margin-bottom: 0.5rem;
  color: var(--text-color);
  font-size: 0.9rem;
}

.form-group input, .form-group select {
  width: 100%;
  padding: 0.875rem;
  border: 1px solid var(--border-color);
  border-radius: 10px;
  font-size: 1rem;
  box-sizing: border-box;
  background-color: rgba(255, 255, 255, 0.5);
  transition: all 0.2s;
}

.form-group input:focus, .form-group select:focus {
  outline: none;
  border-color: var(--primary-color);
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
  background-color: white;
}

.submit-manual-button {
  background-color: var(--primary-color);
  color: white;
  border: none;
  padding: 0.875rem 2rem;
  border-radius: 10px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  width: 100%;
  margin-top: 1.5rem;
  box-shadow: 0 4px 6px rgba(79, 70, 229, 0.25);
}

.submit-manual-button:hover:not(:disabled) {
  background-color: var(--secondary-color);
  transform: translateY(-2px);
  box-shadow: 0 6px 12px rgba(79, 70, 229, 0.3);
}

.view-all-link {
  text-align: center;
  margin-bottom: 1.5rem;
}

.view-all-link a {
  font-weight: 600;
  color: var(--primary-color);
  text-decoration: none;
  transition: all 0.2s;
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
}

.view-all-link a:hover {
  color: var(--secondary-color);
  gap: 0.5rem;
}

.transactions-list {
  background: var(--card-background);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: var(--glass-border);
  padding: 2rem;
  border-radius: 16px;
  box-shadow: var(--glass-shadow);
  list-style: none;
  margin-top: 2rem;
}

.transactions-list h2 {
  text-align: center;
  padding: 0;
  margin-top: 0;
  margin-bottom: 1rem;
  color: var(--text-color);
  font-weight: 800;
  font-size: 1.5rem;
}

.no-transactions {
  text-align: center;
  color: var(--subtle-text-color);
  padding: 2rem;
  font-size: 1.1rem;
}

ul {
  list-style: none;
  padding: 0;
  margin: 0;
}

li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.25rem;
  border-bottom: 1px solid var(--border-color);
  transition: background-color 0.2s;
  border-radius: 8px;
}



li:last-child {
  border-bottom: none;
}

.transaction-info {
  display: flex;
  flex-direction: column;
  flex-grow: 1;
  gap: 8px;
  margin-right: 1rem;
}

.transaction-info .details {
  display: flex;
  flex-direction: column;
}

.transaction-info .date-time-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.25rem;
}

.transaction-info .date {
  color: var(--subtle-text-color);
  font-size: 0.85rem;
  font-weight: 500;
}

.time-pill {
    background-color: rgba(79, 70, 229, 0.08);
    color: var(--primary-color);
    padding: 2px 8px;
    border-radius: 6px;
    font-size: 0.75rem;
    font-weight: 600;
    font-family: 'JetBrains Mono', 'Courier New', monospace;
}

.transaction-info .description {
  color: var(--text-color);
  font-weight: 600;
  font-size: 1rem;
}

.transaction-info .category-and-amount {
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  align-items: center;
}

.transaction-info .amount {
  font-weight: 800;
  font-size: 1.2rem;
  color: var(--primary-color);
  white-space: nowrap;
  text-align: right;
  margin-right: 5px;
  letter-spacing: -0.02em;
}

.category-pill {
  background-color: var(--secondary-color);
  color: white;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
}

.action-buttons {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}


@media (max-width: 600px) {
  li {
    flex-direction: column;
    align-items: flex-start;
    gap: 1rem;
  }

  .transaction-info {
    width: 100%;
    margin-right: 0;
    margin-bottom: 0.5rem;
  }

  .transaction-info .details {
    width: 100%;
    margin-bottom: 0.5rem;
  }

  .transaction-info .category-and-amount {
    width: 100%;
    justify-content: space-between;
    margin-top: 0.25rem;
  }

  .action-buttons {
    width: 100%;
    flex-direction: row;
    justify-content: flex-end;
    gap: 1rem;
    border-top: 1px solid var(--border-color);
    padding-top: 0.75rem;
    margin-top: 0.5rem;
  }
}

html.dark .form-group input,
html.dark .form-group select {
  background-color: rgba(30, 41, 59, 0.5);
  color: white;
  border-color: rgba(255, 255, 255, 0.1);
}

html.dark .form-group input:focus,
html.dark .form-group select:focus {
  background-color: rgba(30, 41, 59, 0.8);
}

html.dark .category-pill {
  background-color: #c2410c; /* Orange 700 - Darker for contrast */
  color: #fce7f3; /* Very light text */
}

.category-pill.income {
  background-color: var(--positive-color); /* Green/Emerald */
}

html.dark .category-pill.income {
  background-color: #15803d; /* Green 700 - Darker for contrast in dark mode */
}

@media (min-width: 601px) {
  .transaction-info {
    flex-direction: row;
    align-items: center;
  }

  .transaction-info .details {
    flex-basis: 65%;
    flex-direction: row;
    align-items: center;
    gap: 1rem;
  }

  .transaction-info .category-and-amount {
    flex-basis: 35%;
  }

  .transaction-info .date-time-row { flex-basis: 180px; margin-bottom: 0;}
  .transaction-info .description { flex-grow: 1; }
  .transaction-info .amount { margin: 0; }
  
  .action-buttons {
    flex-direction: row;
  }
}

/* New CSS for Total Balance and Layouts */
.total-balance-card {
  background: linear-gradient(to right, var(--primary-color), var(--secondary-color));
  color: white;
  padding: 2rem;
  border-radius: 16px;
  margin-bottom: 2rem;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
  transition: transform 0.3s ease;
}

.total-balance-card:hover {
  transform: translateY(-2px);
}

.total-balance-title {
  font-size: 1.125rem;
  font-weight: 500;
  opacity: 0.9;
  margin: 0 0 0.5rem 0;
}

.total-balance-amount {
  font-size: 2.25rem;
  font-weight: 800;
  margin: 0;
}

.form-row {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  margin-bottom: 1.25rem;
}

@media (min-width: 768px) {
  .form-row {
    flex-direction: row;
  }
}

.half-width {
  flex: 1;
  margin-bottom: 0; /* Reset margin for flex children */
}

.type-selector {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
}

.type-option {
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    border: 2px solid transparent;
    transition: all 0.2s ease;
    flex: 1;
    text-align: center;
    min-width: 100px;
    background-color: rgba(255, 255, 255, 0.5);
    color: var(--text-color);
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.type-option:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 6px rgba(0,0,0,0.05);
}

/* Expense Styles */
.type-option.expense {
    border-color: rgba(239, 68, 68, 0.2);
    color: var(--negative-color);
}
.type-option.expense.active {
    background-color: var(--negative-color);
    color: white;
    border-color: var(--negative-color);
}

/* Income Styles */
.type-option.income {
    border-color: rgba(34, 197, 94, 0.2);
    color: var(--positive-color);
}
.type-option.income.active {
    background-color: var(--positive-color);
    color: white;
    border-color: var(--positive-color);
}

/* Transfer Styles - using Blue */
.type-option.transfer {
    border-color: rgba(59, 130, 246, 0.2);
    color: #3b82f6; /* Blue-500 */
}
.type-option.transfer.active {
    background-color: #3b82f6;
    color: white;
    border-color: #3b82f6;
}

/* Dark Mode */
html.dark .type-option {
    background-color: rgba(30, 41, 59, 0.4);
}
html.dark .type-option:hover {
    background-color: rgba(30, 41, 59, 0.6);
}

</style>