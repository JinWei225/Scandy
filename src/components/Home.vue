<template>
  <div class="container">
    <div class="upload-section" data-aos="fade-down">
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

    <div class="manual-entry-section" data-aos="fade-up">
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

    <div class="transactions-list" data-aos="fade-up" data-aos-delay="50">
      <h2>Recent Transactions</h2>
      <div class="view-all-link">
        <router-link to="/all">View All Transactions &rarr;</router-link>
      </div>
      <div v-if="transactions.length === 0" class="no-transactions">
        No transactions found.
      </div>
      <ul v-else>
        <li v-for="(transaction, index) in latestTransactions" :key="transaction.id"
            data-aos="fade-up" :data-aos-delay="index * 30">
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

li:hover {
  background-color: rgba(255, 255, 255, 0.3);
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

.transaction-info .date {
  color: var(--subtle-text-color);
  font-size: 0.85rem;
  margin-bottom: 0.25rem;
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

  .transaction-info .date { flex-basis: 120px; margin-bottom: 0;}
  .transaction-info .description { flex-grow: 1; }
  .transaction-info .amount { margin: 0; }
  
  .action-buttons {
    flex-direction: row;
  }
}
</style>