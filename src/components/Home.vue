<template>
  <div class="container">
    <div class="upload-section">
      <h2>Upload Transaction Records</h2>
      <input type="file" @change="handleFileUpload" ref="fileInput" id="file-upload" class="file-input-hidden">
      <label for="file-upload" class="file-upload-label"> Choose Image </label>
      <span class="file-name">{{ selectedFile ? selectedFile.name : 'No file selected' }}</span>

      <button @click="uploadImage" :disabled="!selectedFile || isLoading" class="upload-button">
        {{ isLoading ? 'Processing...' : 'Upload and Scan' }}
      </button>
      <p v-if="message" class="message">{{ message }}</p>
    </div>

    <div class="manual-entry-section">
      <h2>Manual Entry</h2>
      <form @submit.prevent="addManualTransaction">
        <div class="form-group">
          <label for="manual-date">Date</label>
          <input type="date" id="manual-date" v-model="manualDate" required>
        </div>
        <div class="form-group">
          <label for="manual-description">Description</label>
          <input type="text" id="manual-description" v-model="manualDescription" placeholder="e.g., Coffee with client" required>
        </div>
        <div class="form-group">
          <label for="manual-category">Category</label>
          <select id="manual-category" v-model="manualCategory" required>
            <option v-for="category in categories" :key="category" :value="category">
              {{ category }}
            </option>
          </select>
        </div>
        <div class="form-group">
          <label for="manual-amount">Amount (RM)</label>
          <input type="number" id="manual-amount" v-model="manualAmount" placeholder="15.50" step="0.01" required>
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
                <span class="date">{{ transaction.date }}</span>
                <span class="description">{{ transaction.description }}</span>
            </div>
            <div class="category-and-amount">
                <!-- Display the category if it exists -->
                <span v-if="transaction.category" class="category-pill">{{ transaction.category }}</span>
                <span class="amount">{{ transaction.amount }}</span>
            </div>
          </div>
          <div class="action-buttons">
            <button @click="openEditModal(transaction)" class="edit-btn" aria-label="Edit Transaction">
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
              </svg>
            </button>
            <button @click="deleteTransaction(transaction.id)" class="delete-btn">&times;</button>
          </div>
        </li>
      </ul>
    </div>
  </div>

  <ConfirmationModal
    v-if="isConfirmationModalVisible"
    :scannedData="scannedData"
    :categories="categories"
    @close="isConfirmationModalVisible = false"
    @save="handleSaveConfirmation"
  />

  <EditModal 
    v-if="isModalVisible" 
    :transaction="transactionToEdit"
    :categories="categories"
    @close="isModalVisible = false"
    @save="handleSaveTransaction"
  />
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import { useTransactions } from '../composables/useTransactions';
import EditModal from '../components/EditModal.vue';
import ConfirmationModal from '../components/ConfirmationModal.vue';
import axios from 'axios';

export default {
  name: 'HomePage',
  components: {
    EditModal,
    ConfirmationModal,
  },
  setup() {
    // --- COMPOSABLE ---
    const { transactions, categories, fetchTransactions, fetchCategories } = useTransactions();

    // --- STATE ---
    const selectedFile = ref(null);
    const isLoading = ref(false);
    const message = ref('');
    const manualDate = ref('');
    const manualDescription = ref('');
    const manualAmount = ref(null);
    const manualCategory = ref('Uncategorized');
    const scannedData = ref(null);
    const isConfirmationModalVisible = ref(false);
    const isModalVisible = ref(false);
    const transactionToEdit = ref(null);
    const fileInput = ref(null); // To reference the file input element

    // --- COMPUTED ---
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
        await axios.post('/api/transactions/manual', transactionPayload);
        message.value = 'Transaction saved successfully!';
        await fetchTransactions(); // Refresh shared data
      } catch (error) {
        message.value = 'Failed to save transaction.';
      } finally {
        isLoading.value = false;
        isConfirmationModalVisible.value = false;
        selectedFile.value = null;
        if (fileInput.value) fileInput.value.value = null;
      }
    };
    
    const addManualTransaction = async () => {
      if (!manualDate.value || !manualDescription.value || !manualAmount.value) {
        message.value = 'Please fill out all manual entry fields.';
        return;
      }
      isLoading.value = true;
      const formattedDate = manualDate.value.split('-').reverse().join('/');
      const newTransaction = {
        date: formattedDate,
        description: manualDescription.value,
        amount: manualAmount.value,
        category: manualCategory.value,
      };
      try {
        await axios.post('/api/transactions/manual', newTransaction);
        message.value = 'Transaction added successfully!';
        manualDate.value = '';
        manualDescription.value = '';
        manualAmount.value = null;
        manualCategory.value = 'Uncategorized';
        await fetchTransactions(); // Refresh shared data
      } catch (error) {
        message.value = 'Failed to add transaction.';
      } finally {
        isLoading.value = false;
      }
    };
    
    const deleteTransaction = async (id) => {
        if (!confirm('Are you sure you want to delete this transaction?')) return;
        try {
            await axios.delete(`/api/transactions/${id}`);
            await fetchTransactions(); // Refresh shared data
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
        } catch (error) {
            alert('Failed to update transaction.');
        }
    };

    // --- LIFECYCLE HOOK ---
    onMounted(() => {
      fetchTransactions();
      fetchCategories();
    });

    // --- RETURN ---
    return {
      selectedFile,
      transactions,
      isLoading,
      message,
      description: ref(''), // description is not a shared state, but local to the form
      manualDate,
      manualDescription,
      manualAmount,
      manualCategory,
      categories,
      scannedData,
      isConfirmationModalVisible,
      isModalVisible,
      transactionToEdit,
      fileInput,
      latestTransactions,
      handleFileUpload,
      uploadImage,
      handleSaveConfirmation,
      addManualTransaction,
      deleteTransaction,
      openEditModal,
      handleSaveTransaction,
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
  background-color: var(--card-background);
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  text-align: center;
  margin-bottom: 2rem;
}

.upload-section h2 {
  margin-top: 0;
  color: var(--primary-color);
  margin-bottom: 1.5rem;
}

.file-input-hidden {
  display: none;
}

.file-upload-label {
  background-color: var(--primary-color);
  color: white;
  padding: 0.75rem 1.5rem;
  border-radius: 5px;
  font-size: 1rem;
  font-weight: bold;
  cursor: pointer;
  display: inline-block; /* Important for padding to work correctly */
  transition: background-color 0.3s ease;
  margin-bottom: 1rem;
}

.file-upload-label:hover {
  background-color: var(--secondary-color);
}

.file-name {
  display: block;
  margin-bottom: 1.5rem;
  color: #555;
  font-style: italic;
}

.upload-button {
  background-color: var(--secondary-color);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 5px;
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.3s;
  width: 100%;
  max-width: 300px;
}

.upload-button:disabled {
  background-color: #a0b4c2;
  cursor: not-allowed;
}

.upload-button:hover:not(:disabled) {
  background-color: var(--primary-color);
}

.message {
  margin-top: 1rem;
  color: var(--primary-color);
}

.confirmation-form {
  text-align: left;
}

.confirmation-form h2 {
  text-align: center;
  color: var(--primary-color);
  margin-bottom: 0.5rem;
}

.message-info {
  text-align: center;
  color: var(--subtle-text-color);
  margin-bottom: 2rem;
}

.confirmation-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 2rem;
}

.confirmation-actions button {
  padding: 0.75rem 1.5rem;
  border-radius: 5px;
  font-size: 1rem;
  font-weight: bold;
  cursor: pointer;
  border: none;
  transition: background-color 0.2s;
}

.save-btn {
  background-color: var(--primary-color);
  color: white;
}
.save-btn:hover {
  background-color: var(--secondary-color);
}

.cancel-btn {
  background-color: var(--border-color);
  color: var(--text-color);
}
.cancel-btn:hover {
  background-color: #d1d5db; /* A slightly darker gray for hover */
}

.manual-entry-section {
  background-color: var(--card-background);
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  margin-bottom: 2rem;
}

.manual-entry-section h2 {
  text-align: center;
  margin-top: 0;
  color: var(--primary-color);
  margin-bottom: 1.5rem;
}

.form-group {
  margin-bottom: 1rem;
  text-align: left;
}

.form-group label {
  display: block;
  font-weight: bold;
  margin-bottom: 0.5rem;
}

.form-group input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 5px;
  font-size: 1rem;
  box-sizing: border-box;
}

.form-group select {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 5px;
  font-size: 1rem;
  box-sizing: border-box;
  background-color: var(--card-background); /* For theme consistency */
  color: var(--text-color); /* For theme consistency */
}

.submit-manual-button {
  /* Re-use styles from the upload button for consistency */
  background-color: var(--primary-color);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 5px;
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.3s;
  width: 100%;
  margin-top: 1rem;
}

.submit-manual-button:hover:not(:disabled) {
  background-color: var(--secondary-color);
}

.view-all-link {
  text-align: center;
  margin-bottom: 1.5rem;
}

.view-all-link a {
  font-weight: bold;
  color: var(--primary-color);
  text-decoration: none;
  transition: color 0.2s;
}

.view-all-link a:hover {
  color: var(--secondary-color);
}

.transactions-list {
  background-color: var(--card-background);
  padding: 0 1.5rem; /* Add horizontal padding */
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  list-style: none; /* Remove default bullet points */
  margin-top: 2rem;
}

.transactions-list h2 {
  text-align: center;
  padding: 1rem 0 0 0;
  margin-top: 10px;
  color: var(--primary-color);
}

.no-transactions,
.no-transactions-period {
  text-align: center;
  color: var(--subtle-text-color);
  padding: 2rem;
}

ul {
  list-style: none;
  padding: 0;
}

li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.25rem 0;
  border-bottom: 1px solid var(--border-color);
}

li:last-child {
  border-bottom: none;
}

.transaction-info {
  display: flex;
  flex-direction: column; /* Stack text vertically by default */
  flex-grow: 1; /* Allows this section to take up available space */
  gap: 8px;
  margin-right: 1rem;
}

.transaction-info .details {
  display: flex;
  flex-direction: column; /* Date and description will stack in mobile */
}

.transaction-info .date {
  color: var(--subtle-text-color);
  font-size: 0.85rem;
  margin-bottom: 0.25rem;
}

.transaction-info .description {
  color: var(--text-color);
  font-weight: 600; /* Make description stand out */
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
  white-space: nowrap; /* Prevent amount from wrapping */
  text-align: right;
  margin-right: 5px;
}

.category-pill {
  background-color: var(--secondary-color);
  color: white;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 500;
  white-space: nowrap;
}

.action-buttons {
  display: flex;
  flex-direction: column;
}
.edit-btn {
  background-color: var(--primary-color);
  border: none;
  color: white;
  border-radius: 50%;
  width: 28px;
  height: 28px;
  cursor: pointer;
  display: flex;
  justify-content: center;
  align-items: center;
  transition: background-color 0.2s;
}
.edit-btn:hover {
  background-color: var(--secondary-color);
}

.delete-btn {
  background-color: #ef4444;
  color: white;
  border: none;
  border-radius: 50%;
  width: 28px;
  height: 28px;
  font-size: 1.2rem;
  font-weight: bold;
  line-height: 1;
  cursor: pointer;
  transition: background-color 0.2s;
  margin: 0.5rem 0 0 0;
}

.delete-btn:hover {
  background-color: #dc2626; /* A darker red on hover */
}

.description-input-wrapper {
  margin-top: 1.5rem;
  margin-bottom: 1.5rem;
  text-align: left;
}

.description-input-wrapper label {
  display: block;
  font-weight: bold;
  margin-bottom: 0.5rem;
  color: var(--primary-color);
}

#description {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 5px;
  font-size: 1rem;
  box-sizing: border-box; /* Ensures padding doesn't affect width */
}

#description:focus {
  outline: none;
  border-color: var(--secondary-color);
  box-shadow: 0 0 0 2px rgba(74, 122, 156, 0.3);
}

@media (min-width: 601px) {
  .transaction-info {
    flex-direction: row;
    align-items: center;
  }

  .transaction-info .details {
    flex-basis: 65%;
    flex-direction: row; /* Make date and description side-by-side */
    align-items: center;
    gap: 1rem;
  }

  .transaction-info .category-and-amount {
    flex-basis: 35%;
  }

  .transaction-info .date { flex-basis: 120px; margin-bottom: 0;}
  .transaction-info .description { flex-grow: 1; }
  .transaction-info .amount { margin: 0; }
}

</style>