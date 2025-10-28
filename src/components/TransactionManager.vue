<template>
  <div class="container">
    <header>
      <h1>ScanDy</h1>
      <p>Upload a receipt image to extract transaction data.</p>
    </header>

    <div class="upload-section">
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
      message: '',
      description: ''
    };
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
    }
  },
  mounted() {
    this.fetchTransactions();
  }
}
</script>

<style>
/* Blue Color Palette */
:root {
  /* Palette 1: Corporate & Trustworthy */
  --primary-color: #3b82f6;     /* Electric Blue - For headers and key actions */
  --secondary-color: #60a5fa;   /* Bright Sky Blue - For secondary buttons and highlights */
  --background-color: #f8fafc;  /* Light Gray - For the main page background */
  --card-background: #ffffff;   /* Pure White - For cards */
  --text-color: #374151;        /* Almost Black - For body text */
  --header-color: #ffffff;      /* Pure White - For text on dark backgrounds */
  --border-color: #e5e7eb;      /* Medium Gray - For borders */
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

@media (max-width: 600px) {
  .transactions-list li {
    flex-direction: column;
    align-items: flex-start;
    gap: 5px;
  }

  .date, .description, .amount {
    flex-basis: 100%;
    text-align: left;
    margin-bottom: 0.5rem;
  }

  .amount {
    text-align: left;
  }

  .transactions-list .date,
  .transactions-list .description,
  .transactions-list .amount {
    flex-basis: auto; /* Let each item take its natural width */
    width: 100%;     /* Make them full-width within the list item */
    text-align: left;  /* Left-align all text for consistency */
  }

  /* Make the amount stand out a bit more */
  .transactions-list .amount {
    margin-top: 8px; /* Add some extra space above the amount */
    font-size: 1.1rem; /* Make the amount slightly bigger */
  }
}
</style>