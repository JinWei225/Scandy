<template>
  <div class="container">
    <header>
      <h1>All Transactions</h1>
    </header>

    <div class="back-link">
      <router-link to="/">&larr; Back to Home</router-link>
    </div>

    <div v-if="transactions.length > 0" class="filter-controls">
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
      <div v-if="filteredTransactions.length > 0" class="monthly-summary">
        <h3>Monthly Total</h3>
        <p class="summary-amount">{{ monthlyTotal }}</p>
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
            <span class="date">{{ transaction.date }}</span>
            <span class="description">{{ transaction.description }}</span>
            <span class="amount">{{ transaction.amount }}</span>
          </div>
          <button @click="deleteTransaction(transaction.id)" class="delete-btn">&times;</button>
        </li>
      </ul>
    </div>
    
    <div v-else class="no-transactions">
      No transactions recorded yet.
    </div>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  name: 'AllTransactions',
  data() {
    return {
      transactions: [],
      selectedYear: null,
      selectedMonth: null,
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
    }
  },
  watch: {
    selectedYear(newYear) {
      if (newYear) {
        this.$nextTick(() => {
          if (this.availableMonths.length > 0) {
            this.selectedMonth = this.availableMonths[0];
          } else {
            this.selectedMonth = null;
          }
        });
      }
    }
  },
  methods: {
    async fetchTransactions() {
      try {
        const response = await axios.get('http://angs-mac-mini-1:5000/api/transactions');
        this.transactions = response.data.sort((a, b) => new Date(b.id) - new Date(a.id));
        
        if (this.transactions.length > 0) {
          this.selectedYear = this.availableYears[0];
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
  },
  // This is the corrected section
  mounted() {
    this.fetchTransactions();
  }
}
</script>

<style>
/* You can copy most styles from Home.vue, but here are specific ones */
:root {
  --primary-color: #3b82f6;
  --secondary-color: #60a5fa;
  --background-color: #f8fafc;
  --card-background: #ffffff;
  --text-color: #374151;
  --header-color: #ffffff;
  --border-color: #e5e7eb;
}

.container { 
    max-width: 800px; 
    margin: 0 auto; 
    padding: 2rem; 
}

header { 
    background-color: var(--primary-color); 
    color: var(--header-color); 
    padding: 1.5rem; 
    border-radius: 8px; 
    text-align: center; 
    margin-bottom: 2rem; 
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

.filter-controls {
  display: flex;
  gap: 1rem;
  justify-content: center;
  align-items: center;
  padding: 1rem;
  background-color: var(--card-background);
  border-radius: 8px;
  margin-bottom: 2rem;
  box-shadow: 0 4px 6px rgba(0,0,0,0.05);
}

.select-wrapper {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.filter-controls label {
  font-weight: bold;
  color: var(--text-color);
  margin-left: 1rem;
}

.filter-controls select {
  padding: 0.5rem;
  border: 1px solid var(--border-color);
  border-radius: 5px;
  font-size: 1rem;
  background-color: #fff;
  margin-right: 1rem;
}

.filter-controls select:disabled {
  background-color: #f3f4f6;
  cursor: not-allowed;
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
    flex-grow: 1; 
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
    flex-shrink: 0; 
    margin-left: 1rem; 
}

.delete-btn:hover { 
    background-color: #dc2626; 
}

/* Re-use your mobile and desktop media queries here for the transaction-info spans */
@media (min-width: 601px) {
  .transaction-info { 
    display: flex; 
    flex-direction: row; 
    align-items: center; 
  }
  .transaction-info .date { flex-basis: 25%; }
  .transaction-info .description { flex-basis: 50%; }
  .transaction-info .amount { flex-basis: 25%; text-align: right; font-weight: bold; color: var(--primary-color); }
}

@media (max-width: 600px) {
  .transaction-info .date, 
  .transaction-info .description, 
  .transaction-info .amount { 
    display: block; 
    width: 100%; 
  }

  .transaction-info .description { margin: 5px 0; }
  .transaction-info .amount { 
    font-weight: bold; 
    margin-top: 8px; 
    font-size: 1.1rem; 
    color: var(--primary-color); 
  }

  .filter-controls {
  /* Change the flex direction to stack the dropdowns */
  flex-direction: column;
  
  /* Make the items stretch to the full width for a cleaner look */
  align-items: stretch;
  }

  /* Ensure the wrappers take up the full width */
  .filter-controls .select-wrapper {
    justify-content: space-between; /* Pushes the label and select apart */
    width: 100%;

  }
}
</style>