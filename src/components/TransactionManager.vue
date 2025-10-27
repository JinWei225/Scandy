<template>
  <div class="container">
    <header>
      <h1>Transaction Scanner</h1>
      <p>Upload a receipt image to extract transaction data.</p>
    </header>

    <div class="upload-section">
      <input type="file" @change="handleFileUpload" ref="fileInput" class="file-input">
      <button @click="uploadImage" :disabled="!selectedFile || isLoading">
        {{ isLoading ? 'Processing...' : 'Upload and Scan' }}
      </button>
      <p v-if="message" class="message">{{ message }}</p>
    </div>

    <div class="transactions-list">
      <h2>Recorded Transactions</h2>
      <div v-if="transactions.length === 0" class="no-transactions">
        No transactions found.
      </div>
      <ul v-else>
        <li v-for="(transaction, index) in transactions" :key="index">
          <span class="date">{{ transaction.date }}</span>
          <span class="description">{{ transaction.description }}</span>
          <span class="amount">{{ transaction.amount }}</span>
        </li>
      </ul>
    </div>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  name: 'TransactionManager',
  data() {
    return {
      selectedFile: null,
      transactions: [],
      isLoading: false,
      message: ''
    };
  },
  methods: {
    async fetchTransactions() {
      try {
        const response = await axios.get('http://127.0.0.1:5000/api/transactions');
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

      try {
        await axios.post('http://127.0.0.1:5000/api/upload', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        });
        this.message = 'File uploaded successfully!';
        this.selectedFile = null;
        this.$refs.fileInput.value = null; 
        await this.fetchTransactions(); // Refresh the list
      } catch (error) {
        console.error('Error uploading file:', error);
        this.message = 'Error uploading file. Please try again.';
      } finally {
        this.isLoading = false;
      }
    }
  },
  mounted() {
    this.fetchTransactions();
  }
}
</script>

<style scoped>
/* Blue Color Palette */
:root {
  /* Palette 1: Corporate & Trustworthy */
  --primary-color: #0d2c54;     /* Deep Navy - For headers and primary text */
  --secondary-color: #1a5dab;   /* Professional Blue - For buttons and links */
  --background-color: #f0f5fa;  /* Very Light Blue-Gray - For the main page background */
  --card-background: #ffffff;   /* Pure White - For cards and panels */
  --text-color: #344054;        /* Dark Gray - For body text */
  --header-color: #ffffff;      /* Pure White - For text on dark backgrounds */
  --border-color: #e4e7eb;      /* Light Gray - For borders and dividers */
}

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

.file-input {
  display: block;
  margin: 0 auto 1rem;
  color: var(--text-color);
}

button {
  background-color: var(--secondary-color);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 5px;
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.3s;
}

button:disabled {
  background-color: #a0b4c2;
  cursor: not-allowed;
}

button:hover:not(:disabled) {
  background-color: var(--primary-color);
}

.message {
  margin-top: 1rem;
  color: var(--primary-color);
}

.transactions-list {
    background-color: var(--card-background);
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.transactions-list h2 {
  text-align: center;
  margin-top: 0;
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
  padding: 1rem;
  border-bottom: 1px solid var(--border-color);
}

li:last-child {
    border-bottom: none;
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
}
</style>