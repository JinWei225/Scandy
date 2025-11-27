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
            <h3>Budget <button class="edit-budget-btn" @click="isBudgetModalVisible = true">✎</button></h3>
            <p class="summary-amount">{{ currentBudget !== null ? `RM ${currentBudget.toFixed(2)}` : 'Not Set' }}</p>
          </div>
          <div class="summary-item">
            <h3>Spent</h3>
            <p class="summary-amount">{{ monthlyTotalText }}</p>
          </div>
          <div class="summary-item">
            <h3>{{ moneyLeft.label }}</h3>
            <p class="summary-amount" :class="moneyLeft.status">{{ moneyLeft.text }}</p>
          </div>
        </div>
        <!-- Removed set-budget-form -->
      </div>
    </div>
    <div v-if="categorySummary.length > 0" class="category-breakdown">
      <h3>Spending by Category</h3>
      <CategoryChart :categoryData="categorySummary" />
      <ul>
        <li v-for="item in categorySummary" :key="item.name">
          <button @click="openDetailModal(item.name)" class="category-item">
            <div class="category-info">
              <span class="category-name">{{ item.name }}</span>
              <span class="transaction-count">{{ item.count }} transactions</span>
            </div>
            <div class="category-spending">
              <span class="category-total">RM {{ item.total.toFixed(2) }}</span>
              <span class="category-percentage">{{ item.percentage.toFixed(0) }}%</span>
            </div>
          </button>
        </li>
      </ul>
    </div>
    <div v-else class="no-transactions">
      No transactions recorded yet.
    </div>
  </div>
  <CategoryDetailModal
    v-if="isDetailModalVisible"
    :categoryName="selectedCategoryData.name"
    :transactions="selectedCategoryData.transactions"
    @close="isDetailModalVisible = false"
    @edit="handleEditFromModal"
    @delete="handleDeleteFromModal"
  />
  <EditModal 
    v-if="isModalVisible" 
    :transaction="transactionToEdit"
    :categories="categories"
    @close="isModalVisible = false"
    @save="handleSaveTransaction"
  />
  <BudgetModal
    v-if="isBudgetModalVisible"
    :initialAmount="currentBudget"
    @close="isBudgetModalVisible = false"
    @save="setBudget"
  />
</template>

<script>
import { ref, computed, watch, onMounted, nextTick } from 'vue';

import { useTransactions } from '../composables/useTransactions';

import EditModal from '../components/EditModal.vue';
import CategoryDetailModal from '../components/CategoryDetailModal.vue';
import CategoryChart from '../components/CategoryChart.vue';
import BudgetModal from '../components/BudgetModal.vue';
import axios from 'axios';

export default {
  name: 'AllTransactions',
  components: {
    EditModal,
    CategoryDetailModal,
    CategoryChart,
    BudgetModal,
  },
  
  // The setup() function is the heart of the Composition API
  setup() {
    // --- COMPOSABLE ---
    // Get all our shared transaction data and methods from the composable!
    const { transactions, categories, fetchTransactions, fetchCategories } = useTransactions();

    // --- STATE (formerly `data()`) ---
    // All data properties are now defined as 'refs'
    const selectedYear = ref(null);
    const selectedMonth = ref(null);
    const currentBudget = ref(null);
    const budgetInput = ref(null);
    const isModalVisible = ref(false);
    const transactionToEdit = ref(null);
    const isDetailModalVisible = ref(false);
    const selectedCategoryData = ref({ name: '', transactions: [] });
    const isBudgetModalVisible = ref(false);

    // --- COMPUTED PROPERTIES ---
    const availableYears = computed(() => {
      if (!transactions.value.length) return [];
      const years = new Set(transactions.value.map(tx => tx.date.split('/')[2]));
      return Array.from(years).sort((a, b) => b - a);
    });

    const availableMonths = computed(() => {
      if (!selectedYear.value) return [];
      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const months = new Set(
        transactions.value
          .filter(tx => tx.date.endsWith(`/${selectedYear.value}`))
          .map(tx => monthNames[parseInt(tx.date.split('/')[1], 10) - 1])
      );
      return Array.from(months).sort((a, b) => monthNames.indexOf(a) - monthNames.indexOf(b));
    });
    
    const filteredTransactions = computed(() => {
        if (!selectedYear.value || !selectedMonth.value) return [];
        const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        const monthIndex = monthNames.indexOf(selectedMonth.value) + 1;
        const monthString = monthIndex < 10 ? `0${monthIndex}` : `${monthIndex}`;
        return transactions.value.filter(tx => tx.date.split('/')[1] === monthString && tx.date.split('/')[2] === selectedYear.value);
    });

    const monthlyTotal = computed(() => {
      if (!filteredTransactions.value.length) return 0;
      return filteredTransactions.value.reduce((sum, tx) => {
        const amount = parseFloat(tx.amount.replace('RM', '').trim());
        return isNaN(amount) ? sum : sum + amount;
      }, 0);
    });

    const monthlyTotalText = computed(() => `RM ${monthlyTotal.value.toFixed(2)}`);

    const subscriptions = ref([]);

    const fetchSubscriptions = async () => {
      try {
        const response = await axios.get('/api/subscriptions');
        subscriptions.value = response.data;
      } catch (error) {
        console.error("Error fetching subscriptions:", error);
      }
    };

    const remainingSubscriptions = computed(() => {
      const now = new Date();
      const currentYear = now.getFullYear().toString();
      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const currentMonthName = monthNames[now.getMonth()];

      // Only calculate for current month/year
      if (selectedYear.value !== currentYear || selectedMonth.value !== currentMonthName) {
        return 0;
      }

      const today = now.getDate();
      return subscriptions.value.reduce((sum, sub) => {
        // If day_of_month > today, it's remaining.
        // Also check if it's already recorded (though the backend check should handle this, 
        // strictly speaking "remaining" means "not yet paid/recorded").
        // A simple heuristic is just day > today.
        // A better one is checking if a transaction exists for it, but that's complex.
        // Let's stick to day > today for "upcoming".
        const day = parseInt(sub.day_of_month) || 1;
        if (day > today) {
          return sum + parseFloat(sub.amount);
        }
        return sum;
      }, 0);
    });

    const moneyLeft = computed(() => {
      if (currentBudget.value === null) return { text: 'N/A', status: 'neutral', label: 'Money Left' };
      
      let left = currentBudget.value - monthlyTotal.value;
      let label = 'Money Left';

      // If current month, subtract remaining subscriptions
      if (remainingSubscriptions.value > 0) {
        left -= remainingSubscriptions.value;
        label = 'Safe to Spend';
      }

      const status = left >= 0 ? 'positive' : 'negative';
      const text = `RM ${left.toFixed(2)}`;
      return { text, status, label };
    });

    const categorySummary = computed(() => {
      if (!filteredTransactions.value.length || monthlyTotal.value === 0) return [];
      const summary = filteredTransactions.value.reduce((acc, tx) => {
        const category = tx.category || 'Uncategorized';
        const amount = parseFloat(tx.amount.replace('RM', '').trim());
        if (!isNaN(amount)) {
          if (!acc[category]) acc[category] = { total: 0, count: 0 };
          acc[category].total += amount;
          acc[category].count += 1;
        }
        return acc;
      }, {});
      return Object.keys(summary).map(name => ({
        name,
        ...summary[name],
        percentage: (summary[name].total / monthlyTotal.value) * 100
      })).sort((a, b) => b.total - a.total);
    });

    // --- METHODS ---
    const fetchBudget = async () => {
      if (!selectedYear.value || !selectedMonth.value) return;
      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const monthIndex = monthNames.indexOf(selectedMonth.value) + 1;
      try {
        const response = await axios.get(`/api/budget/${selectedYear.value}/${monthIndex}`);
        currentBudget.value = response.data.amount;
        budgetInput.value = response.data.amount;
      } catch (error) {
        if (error.response && error.response.status === 404) {
          currentBudget.value = null;
          budgetInput.value = null;
        } else {
          console.error("Error fetching budget:", error);
        }
      }
    };

    const setBudget = async (amount) => {
      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const monthIndex = monthNames.indexOf(selectedMonth.value) + 1;
      try {
        await axios.post('/api/budget', {
          year: selectedYear.value,
          month: monthIndex,
          amount: amount,
        });
        await fetchBudget();
        isBudgetModalVisible.value = false;
      } catch (error) {
        console.error("Error setting budget:", error);
        alert("Failed to set budget.");
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
        await fetchTransactions(); // Refresh data from composable
        isDetailModalVisible.value = false;
      } catch (error) {
        console.error('Error updating transaction:', error);
        alert('Failed to update transaction.');
      }
    };

    const handleDeleteFromModal = async (transactionId) => {
      if (!confirm('Are you sure you want to delete this transaction?')) return;
      try {
        await axios.delete(`/api/transactions/${transactionId}`);
        await fetchTransactions(); // Refresh data from composable
        isDetailModalVisible.value = false;
      } catch (error) {
        console.error('Error deleting transaction:', error);
        alert('Failed to delete transaction.');
      }
    };
    
    const handleEditFromModal = (transaction) => {
      openEditModal(transaction);
    };

    const openDetailModal = (categoryName) => {
      selectedCategoryData.value = {
        name: categoryName,
        transactions: filteredTransactions.value.filter(tx => (tx.category || 'Uncategorized') === categoryName)
      };
      isDetailModalVisible.value = true;
    };
    
    // --- WATCHERS ---
    watch(selectedYear, () => {
        if (availableMonths.value.length > 0) {
            selectedMonth.value = availableMonths.value[availableMonths.value.length - 1];
        }
    });

    watch(selectedMonth, (newMonth) => {
        if (newMonth) fetchBudget();
    });

    // --- LIFECYCLE HOOKS (formerly `mounted()`) ---
    onMounted(async () => {
      await fetchTransactions(); // Call methods from the composable
      fetchCategories();
      fetchSubscriptions();
      if (availableYears.value.length > 0) {
        selectedYear.value = availableYears.value[0];
        
        await nextTick();
        
        if (availableMonths.value.length > 0) {
          selectedMonth.value = availableMonths.value[availableMonths.value.length - 1];
        }
      }
    });

    // --- RETURN ---
    // We must return everything the template needs to access.
    return {
      transactions,
      selectedYear,
      selectedMonth,
      currentBudget,
      budgetInput,
      categories,
      isModalVisible,
      transactionToEdit,
      isDetailModalVisible,
      selectedCategoryData,
      availableYears,
      availableMonths,
      filteredTransactions,
      monthlyTotal,
      monthlyTotalText,
      moneyLeft,
      categorySummary,
      fetchBudget,
      setBudget,
      openEditModal,
      handleSaveTransaction,
      handleDeleteFromModal,
      handleEditFromModal,
      openDetailModal,
      isBudgetModalVisible,
    };
  }
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
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
}

.edit-budget-btn {
  background: none;
  border: none;
  color: var(--primary-color);
  cursor: pointer;
  font-size: 1rem;
  padding: 0;
  opacity: 0.7;
  transition: opacity 0.2s;
}

.edit-budget-btn:hover {
  opacity: 1;
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

.category-breakdown {
  background-color: var(--card-background);
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.05);
  padding: 1.5rem;
  margin-top: 2rem;
}
.category-breakdown h3 {
  margin-top: 0;
  margin-bottom: 1.5rem;
  text-align: center;
  color: var(--primary-color);
}
.category-breakdown ul {
  list-style: none;
  padding: 0;
  margin: 0;
}
.category-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
  padding: 1rem;
  margin-bottom: 0.5rem;
  border-radius: 6px;
  background-color: transparent;
  border: 1px solid var(--border-color);
  text-align: left;
  cursor: pointer;
  transition: background-color 0.2s, border-color 0.2s;
}
.category-item:hover {
  background-color: var(--background-color);
  border-color: var(--secondary-color);
}
.category-info {
  display: flex;
  flex-direction: column;
}
.category-name {
  font-weight: 600;
  font-size: 1rem;
  color: var(--text-color);
}
.transaction-count {
  font-size: 0.8rem;
  color: var(--subtle-text-color);
}
.category-spending {
  text-align: right;
}
.category-total {
  font-weight: bold;
  font-size: 1.1rem;
  display: block;
  color: var(--text-color);
}
.category-percentage {
  font-size: 0.9rem;
  color: var(--primary-color);
  font-weight: 500;
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