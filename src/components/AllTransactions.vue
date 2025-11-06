<template>
  <div class="container">
    <div class="back-link">
      <router-link to="/">&larr; Back to Home</router-link>
    </div>

    <div v-if="transactions.length > 0" class="top-panel">

      <!-- Section 1: The Filter Controls -->
      <div class="filter-controls">
        <div class="select-wrapper">
          <label for="year-select">Year:</label>
          <select id="year-select" v-model="selectedYear">
            <option v-for="year in availableYears" :key="year" :value="year">
              {{ year }}
            </option>
          </select>
        </div>
        <div class="select-wrapper">
          <label for="month-select">Month:</label>
          <select id="month-select" v-model="selectedMonth" :disabled="!selectedYear">
            <option v-for="month in availableMonths" :key="month" :value="month">
              {{ month }}
            </option>
          </select>
        </div>
      </div>

      <!-- Section 2: The Budget and Summary -->
      <div class="budget-and-summary">
        <div class="summary-grid">
          <div class="summary-item">
            <h3>Budget</h3>
            <p class="summary-amount">{{ currentBudget !== null ? `RM ${currentBudget.toFixed(2)}` : 'Not Set' }}</p>
          </div>
          <div class="summary-item">
            <h3>Spent</h3>
            <p class="summary-amount">{{ monthlyTotal }}</p>
          </div>
          <div class="summary-item">
            <h3>Money Left</h3>
            <p class="summary-amount" :class="moneyLeft.status">{{ moneyLeft.text }}</p>
          </div>
        </div>
        <div class="set-budget-form">
          <input type="number" v-model="budgetInput" placeholder="Set monthly budget" step="0.01">
          <button @click="setBudget">Set Budget</button>
        </div>
      </div>
    </div>
    <div v-if="transactions.length > 0">
      <ul class="transactions-list">
        <!-- Display message if no transactions match the filter -->
        <li v-if="filteredTransactions.length === 0" class="no-transactions-period">
          No transactions found for this period.
        </li>
        <!-- Loop through only the filtered transactions -->
        <li v-else v-for="transaction in filteredTransactions" :key="transaction.id">
          <div class="transaction-info">
            <div class="details">
                <span class="date">{{ transaction.date }}</span>
                <span class="description">{{ transaction.description }}</span>
            </div>
            <div class="category-and-amount">
                <span class="category-pill">{{ transaction.category }}</span>
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
    
    <div v-else class="no-transactions">
      No transactions recorded yet.
    </div>
  </div>
  <EditModal 
    v-if="isModalVisible" 
    :transaction="transactionToEdit"
    :categories="categories"
    @close="isModalVisible = false"
    @save="handleSaveTransaction"
  />
</template>

<script>
import axios from 'axios';
import EditModal from './EditModal.vue';

export default {
  name: 'AllTransactions',
  components: {
    EditModal,
  },
  data() {
    return {
      transactions: [],
      categories: [],
      selectedYear: null,
      selectedMonth: null,
      currentBudget: null,
      budgetInput: null,
      isModalVisible: false,
      transactionToEdit: null,
    };
  },
  computed: {
    availableYears() {
      if (!this.transactions.length) return [];
      const years = new Set(this.transactions.map(tx => tx.date.split('/')[2]));
      return Array.from(years).sort((a, b) => b - a);
    },
    availableMonths() {
      if (!this.selectedYear) return [];
      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      
      const months = new Set(
        this.transactions
          .filter(tx => tx.date.endsWith(`/${this.selectedYear}`))
          .map(tx => {
            const monthIndex = parseInt(tx.date.split('/')[1], 10) - 1;
            return monthNames[monthIndex];
          })
      );
      
      return Array.from(months).sort((a, b) => monthNames.indexOf(a) - monthNames.indexOf(b));
    },
    filteredTransactions() {
      if (!this.selectedYear || !this.selectedMonth) return [];

      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const monthIndex = monthNames.indexOf(this.selectedMonth) + 1;
      const monthString = monthIndex < 10 ? `0${monthIndex}` : `${monthIndex}`;

      return this.transactions.filter(tx => {
        const parts = tx.date.split('/');
        return parts[1] === monthString && parts[2] === this.selectedYear;
      });
    },
    monthlyTotal() {
      // If there are no transactions for this period, the total is 0.
      if (!this.filteredTransactions.length) {
        return 'RM 0.00';
      }

      // Use the reduce method to sum up the amounts
      const total = this.filteredTransactions.reduce((sum, transaction) => {
        const amountValue = parseFloat(transaction.amount.replace('RM', '').trim());

        // In case the parsing fails, just add 0 to the sum
        if (isNaN(amountValue)) {
          return sum;
        }

        return sum + amountValue;
      }, 0);

      // Format the final total to have two decimal places
      return `RM ${total.toFixed(2)}`;
    },
    moneyLeft() {
      if (this.currentBudget === null) {
        return { text: 'N/A', status: 'neutral' };
      }
      
      const spent = parseFloat(this.monthlyTotal.replace('RM', '').trim());
      const left = this.currentBudget - spent;
      
      if (left >= 0) {
        return {
          text: `RM ${left.toFixed(2)}`,
          status: 'positive', // For green color
        };
      } else {
        return {
          text: `RM -${Math.abs(left).toFixed(2)}`,
          status: 'negative', // For red color
        };
      }
    },
  },
  methods: {
    async fetchCategories() {
      try {
        const response = await axios.get('http://angs-mac-mini-1:5000/api/categories');
        this.categories = response.data;
      } catch (error) {
        console.error('Error fetching categories:', error);
      }
    },
    async fetchTransactions() {
      try {
        const response = await axios.get('http://angs-mac-mini-1:5000/api/transactions');
        this.transactions = response.data;      
        if (this.transactions.length > 0) {
          this.selectedYear = this.availableYears[0];
          
        } else {
          // If there are no transactions, ensure filters are cleared
          this.selectedYear = null;
          this.selectedMonth = null;
        }

      } catch (error) {
        console.error('Error fetching transactions:', error);
      }
    },
    async deleteTransaction(id) {
      if (!confirm('Are you sure you want to delete this transaction?')) return;
      try {
        await axios.delete(`http://angs-mac-mini-1:5000/api/transactions/${id}`);
        await this.fetchTransactions();
      } catch (error) {
        console.error('Error deleting transaction:', error);
      }
    },
    async fetchBudget() {
      if (!this.selectedYear || !this.selectedMonth) return;

      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const monthIndex = monthNames.indexOf(this.selectedMonth) + 1;

      try {
        const response = await axios.get(`http://angs-mac-mini-1:5000/api/budget/${this.selectedYear}/${monthIndex}`);
        this.currentBudget = response.data.amount;
        this.budgetInput = response.data.amount; // Pre-fill the input box
      } catch (error) {
        if (error.response && error.response.status === 404) {
          // This is expected if no budget is set
          this.currentBudget = null;
          this.budgetInput = null;
        } else {
          console.error("Error fetching budget:", error);
        }
      }
    },
    async setBudget() {
      if (this.budgetInput === null || this.budgetInput === '' || isNaN(this.budgetInput)) {
        alert('Please enter a valid number for the budget.');
        return;
      }

      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const monthIndex = monthNames.indexOf(this.selectedMonth) + 1;

      try {
        await axios.post('http://angs-mac-mini-1:5000/api/budget', {
          year: this.selectedYear,
          month: monthIndex,
          amount: this.budgetInput,
        });
        // After setting, re-fetch the budget to update the display
        await this.fetchBudget();
      } catch (error) {
        console.error("Error setting budget:", error);
        alert("Failed to set budget.");
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
  },
  watch: {
    selectedYear(newYear) {
      if (newYear) {
        this.$nextTick(() => {
          if (this.availableMonths.length > 0) {
            this.selectedMonth = this.availableMonths[this.availableMonths.length - 1];
          } else {
            this.selectedMonth = null;
          }
        });
      }
    },
    selectedMonth(newMonth) {
      if (newMonth) {
        this.fetchBudget();
      }
    },
  },
}
</script>

<style>
.container { 
    max-width: 800px; 
    margin: 0 auto; 
    padding: 2rem;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
}

h1 { 
    margin: 0; 
    font-size: 2rem; 
}

.no-transactions { 
    text-align: center; 
    color: #777; 
    margin-top: 2rem; 
}

.back-link { 
    text-align: center; 
    margin-bottom: 1.5rem; 
}

.back-link a { 
    font-weight: bold;
    color: var(--primary-color); 
    text-decoration: none; 
}

.top-panel {
  display: flex;
  background-color: var(--card-background);
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.05);
  margin-bottom: 2rem;
  padding: 1.5rem;
  gap: 2rem; /* Space between filters and summary on desktop */
}

/* --- Section 1: Filter Styles --- */
.filter-controls {
  display: flex;
  flex-direction: column; /* Stack Year/Month vertically */
  gap: 1rem;
  justify-content: center;
  flex-basis: 30%; /* Takes up 30% of the width on desktop */
  flex-shrink: 0;
}

.select-wrapper {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.filter-controls label {
  font-weight: bold;
}

.filter-controls select {
  padding: 0.5rem;
  border: 1px solid var(--border-color);
  border-radius: 5px;
  min-width: 120px;
}

.no-transactions-period {
  text-align: center;
  color: #777;
  padding: 2rem;
}

.month-group { 
    margin-bottom: 2.5rem; 
}
.month-group h2 { 
    color: var(--primary-color); 
    border-bottom: 2px solid var(--border-color); 
    padding-bottom: 0.5rem; 
}

.monthly-summary {
  background-color: #eef2ff; /* A light, complementary blue */
  border: 1px solid #c7d2fe;
  border-radius: 8px;
  padding: 1.5rem;
  margin: 1rem 1rem; /* Adds space above and below */
  text-align: center;
}

.monthly-summary h3 {
  margin: 0;
  font-size: 1.1rem;
  font-weight: 600;
  color: var(--primary-color);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.summary-amount {
  margin: 0.5rem 0 0;
  font-size: 2.2rem;
  font-weight: bold;
  color: var(--text-color);
}

.budget-and-summary {
  flex-grow: 1; /* Takes up the remaining space */
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  text-align: center;
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 1rem;
  margin-bottom: 1rem;
}

.summary-item h3 {
  margin: 0 0 0.5rem;
  font-size: 0.8rem;
  color: #6b7280;
  text-transform: uppercase;
}

.summary-item .summary-amount {
  margin: 0;
  font-size: 1.4rem;
  font-weight: bold;
}

.summary-amount.positive { color: var(--positive-color); }
.summary-amount.negative { color: var(--negative-color); }

.set-budget-form {
  display: flex;
  gap: 0.5rem;
}

.set-budget-form input {
  flex-grow: 1;
  padding: 0.5rem;
  border: 1px solid var(--border-color);
  border-radius: 5px;
}

.set-budget-form button {
  background-color: var(--primary-color);
  color: white;
  border: none;
  border-radius: 5px;
  padding: 0.5rem 1rem;
  font-weight: bold;
  cursor: pointer;
}

.chart-section {
  background-color: var(--card-background);
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.05);
  padding: 1.5rem;
  margin-bottom: 2rem;
}

.chart-container {
  position: relative;
  /* You can adjust the height as you like */
  height: 350px;
  max-width: 600px;
  margin: 0 auto; /* Center the chart */
}

.transactions-list { 
    background-color: var(--card-background); 
    border-radius: 8px; 
    box-shadow: 0 4px 6px rgba(0,0,0,0.1); 
    list-style: none; 
    padding: 0; 
}
li { 
    display: flex; 
    justify-content: space-between; 
    align-items: center; 
    padding: 1rem; 
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
  font-weight: 700;
  font-size: 1.2rem;
  color: var(--primary-color);
  white-space: nowrap; /* Prevent amount from wrapping */
  text-align: right;
  margin-right: 1rem;
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
  margin: 0.75rem 0 0 0;
}

.delete-btn:hover {
  background-color: #dc2626; /* A darker red on hover */
}

.transaction-info { 
    display: flex;
    flex-direction: column;
    flex-grow: 1;
    gap: 8px;
}

.transaction-info .details {
  /* This will hold date and description */
  display: flex;
  flex-direction: column;
}

.transaction-info .category-and-amount {
  display: flex;
  justify-content: space-between; /* Pushes category left and amount right */
  align-items: center;
}

.category-pill {
  background-color: var(--secondary-color);
  color: white;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 500;
  white-space: nowrap; /* Prevent breaking into two lines */
}

@media (min-width: 601px) {
  .transaction-info {
    flex-direction: row; /* Side-by-side on desktop */
    align-items: center;
    justify-content: space-between;
  }

  .transaction-info .details {
    flex-basis: 60%; /* Take up more space */
    flex-direction: row;
    gap: 1rem;
    align-items: center;
  }
  
  .transaction-info .category-and-amount {
    flex-basis: 40%;
  }

  /* Override the old flex-basis for these items */
  .transaction-info .date { flex-basis: auto; }
  .transaction-info .description { flex-basis: auto; }
  .transaction-info .amount { flex-basis: auto; }
}

@media (max-width: 600px) {
  .top-panel {
    flex-direction: column; /* Stack filters and summary vertically */
    gap: 1.5rem;
  }

  .summary-grid {
    grid-template-columns: 1fr; /* Stack summary items vertically */
    gap: 1rem;
    border-bottom: none;
    padding-bottom: 0;
  }

  .summary-item {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1rem;
  }

}
</style>