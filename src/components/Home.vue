<template>
  <div class="container">
    <div class="upload-section">
      <h2>Upload Transaction Records</h2>
      <input type="file" @change="handleFileUpload" ref="fileInput" id="file-upload" class="file-input-hidden">
      <label for ="file-upload" class="file-upload-label"> Choose Image </label>
      <span class="file-name">{{ selectedFile ? selectedFile.name : 'No file selected' }}</span>
      <div v-if="selectedFile" class="description-input-wrapper">
        <label for="description">Description:</label>
        <input type="text" v-model="description" id="description" placeholder="e.g. F2F Noodles" />
      </div>
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
            <span class="date">{{ transaction.date }}</span>
            <span class="description">{{ transaction.description }}</span>
            <span class="amount">{{ transaction.amount }}</span>
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
  <EditModal 
    v-if="isModalVisible" 
    :transaction="transactionToEdit"
    @close="isModalVisible = false"
    @save="handleSaveTransaction"
  />
</template>

<script>
import axios from 'axios';
import EditModal from './EditModal.vue';

export default {
  name: 'HomePage',
  components: {
    EditModal,
  },
  data() {
    return {
      selectedFile: null,
      transactions: [],
      isLoading: false,
      message: '',
      description: '',
      manualDate: '',
      manualDescription: '',
      manualAmount: '',
      isModalVisible: false,
      transactionToEdit: null,
    };
  },
  computed: {
    latestTransactions() {
      return this.transactions.slice(0, 5);
    }
  },
  methods: {
    async fetchTransactions() {
      try {
        const response = await axios.get('http://angs-mac-mini-1:5000/api/transactions');
        this.transactions = response.data;
      } catch (error) {
        console.error('Error fetching transactions:', error);
        this.message = 'Error fetching transactions.';
      }
    },
    handleFileUpload(event) {
      this.selectedFile = event.target.files[0];
      this.message = '';
    },
    async uploadImage() {
      if (!this.selectedFile) return;

      this.isLoading = true;
      this.message = 'Uploading and processing...';

      const formData = new FormData();
      formData.append('file', this.selectedFile);
      formData.append('description', this.description || 'Transaction');

      try {
        await axios.post('http://angs-mac-mini-1:5000/api/upload', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        });
        this.message = 'File uploaded successfully!';
        this.selectedFile = null;
        this.$refs.fileInput.value = null; 
        this.description = '';
        await this.fetchTransactions(); // Refresh the list
      } catch (error) {
        console.error('Error uploading file:', error);
        this.message = 'Error uploading file. Please try again.';
      } finally {
        this.isLoading = false;
      }
    },
    async deleteTransaction(id) {
      // Optional: Ask for confirmation
      if (!confirm('Are you sure you want to delete this transaction?')) {
        return;
      }

      try {
        await axios.delete(`http://angs-mac-mini-1:5000/api/transactions/${id}`);
        
        // Refresh the list to show the change
        await this.fetchTransactions();

      } catch (error) {
        console.error('Error deleting transaction:', error);
        this.message = 'Failed to delete transaction.';
      }
    },
    async addManualTransaction() {
      // Basic validation
      if (!this.manualDate || !this.manualDescription || !this.manualAmount) {
        this.message = 'Please fill out all manual entry fields.';
        return;
      }

      this.isLoading = true;
      this.message = 'Saving transaction...';

      // The date input gives YYYY-MM-DD, but we store DD/MM/YYYY. Let's format it.
      const formattedDate = this.manualDate.split('-').reverse().join('/');

      const newTransaction = {
        date: formattedDate,
        description: this.manualDescription,
        amount: this.manualAmount,
      };

      try {
        // We'll create this new API endpoint in the backend steps
        await axios.post('http://angs-mac-mini-1:5000/api/transactions/manual', newTransaction);

        this.message = 'Transaction added successfully!';
        
        // Clear the form fields
        this.manualDate = '';
        this.manualDescription = '';
        this.manualAmount = null;

        // Refresh the latest transactions list
        await this.fetchTransactions();

      } catch (error) {
        console.error('Error adding manual transaction:', error);
        this.message = 'Failed to add transaction.';
      } finally {
        this.isLoading = false;
      }
    },
    openEditModal(transaction) {
      this.transactionToEdit = transaction;
      this.isModalVisible = true;
    },

    async handleSaveTransaction(updatedTransaction) {
      try {
        await axios.put(`http://angs-mac-mini-1:5000/api/transactions/${updatedTransaction.id}`, updatedTransaction);
        this.isModalVisible = false;
        this.transactionToEdit = null;
        await this.fetchTransactions(); // Refresh the list
      } catch (error) {
        console.error('Error updating transaction:', error);
        alert('Failed to update transaction.');
      }
    },
  },
  mounted() {
    this.fetchTransactions();
  }
}
</script>

<style scoped>
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  background-color: var(--background-color);
  color: var(--text-color);
}

header {
  background-color: var(--primary-color);
  color: var(--header-color);
  padding: 1.5rem;
  border-radius: 8px;
  text-align: center;
  margin-bottom: 2rem;
}

header h1 {
  margin: 0;
  font-size: 2rem;
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
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.transactions-list h2 {
  text-align: center;
  padding: 1rem 0 0 0;
  margin-top: 10px;
  color: var(--primary-color);
}

.no-transactions {
  text-align: center;
  color: #777;
}

ul {
  list-style: none;
  padding: 0;
}

li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 0;
  border-bottom: 1px solid var(--border-color);
}

li:last-child {
    border-bottom: none;
}

.transaction-info {
  display: flex;
  flex-direction: column; /* Stack text vertically by default */
  flex-grow: 1; /* Allows this section to take up available space */
  gap: 5px;
}

.action-buttons {
  display: flex;
  gap: 0.5rem;
  margin-left: 1rem;
}
.edit-btn {
  background-color: var(--primary-color);
  border: none;
  color: white; /* The SVG icon will inherit this color */
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
  background-color: #ef4444; /* A nice red color */
  color: white;
  border: none;
  border-radius: 50%; /* Makes it a circle */
  width: 28px;
  height: 28px;
  font-size: 1.2rem;
  font-weight: bold;
  line-height: 0.5; /* Helps center the 'X' */
  cursor: pointer;
  transition: background-color 0.2s;
  flex-shrink: 0; /* Prevents the button from shrinking */
  margin-left: 0.5rem; /* Space between info and button */
  margin-right: 0.5rem;
}

.delete-btn:hover {
  background-color: #dc2626; /* A darker red on hover */
}

.date {
  flex-basis: 25%;
  color: #555;
}

.description {
  flex-basis: 50%;
}

.amount {
  flex-basis: 25%;
  text-align: right;
  font-weight: bold;
  color: var(--primary-color);
  margin-right: 1rem;
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
    flex-direction: row; /* Arrange text horizontally */
    align-items: center;
  }
  .transaction-info .date { flex-basis: 25%; margin-left: 1rem;}
  .transaction-info .description { flex-basis: 50%; }
  .transaction-info .amount { flex-basis: 25%; text-align: right; }
}

@media (max-width: 600px) {
  .transaction-info .date,
  .transaction-info .description,
  .transaction-info .amount {
    display: block;
    width: 100%;
  }

  .transaction-info .description {
    margin: 5px 0; /* Add some space before and after description */
  }

  .transaction-info .amount {
    font-weight: bold;
    margin-top: 8px; /* Add a bit more space before the amount */
    font-size: 1.1rem;
    text-align: left;
  }
}
</style>