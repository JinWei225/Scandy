<template>
  <div class="container">
    <div class="back-link">
      <router-link to="/">&larr; Back to Home</router-link>
    </div>

    <div v-if="transactions.length > 0" class="top-panel">

      <!-- Section 1: The Filter Controls -->
      <div class="filter-controls">
        <div class="select-wrapper">
          <label for="year-select">Year</label>
          <select id="year-select" v-model="selectedYear">
            <option v-for="year in availableYears" :key="year" :value="year">
              {{ year }}
            </option>
          </select>
        </div>
        <div class="select-wrapper">
          <label for="month-select">Month</label>
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
          <button @click="openDetailModal(item.name, 'expense')" class="category-item">
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
    
    <div v-if="incomeCategorySummary.length > 0" class="category-breakdown income-section">
      <h3>Income by Category</h3>
      <!-- No chart for income as requested -->
      <ul>
        <li v-for="item in incomeCategorySummary" :key="item.name">
          <button @click="openDetailModal(item.name, 'income')" class="category-item">
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

    <div v-if="categorySummary.length === 0 && incomeCategorySummary.length === 0" class="no-transactions">
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
    :accounts="accounts"
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

    const monthlyStats = computed(() => {
        let expense = 0;
        let income = 0;
        
        if (!filteredTransactions.value.length) return { expense, income };
        
        filteredTransactions.value.forEach(tx => {
            // Exclude transfers from calculations
            if (tx.category === 'Transfer' || tx.type === 'transfer') return;
            
            const amount = parseFloat(tx.amount.replace('RM', '').trim());
            if (isNaN(amount)) return;
            
            if (tx.type === 'income') {
                income += amount;
            } else {
                // Default to expense
                expense += amount;
            }
        });
        
        return { expense, income };
    });

    const monthlyTotal = computed(() => monthlyStats.value.expense);

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
        const day = parseInt(sub.day_of_month) || 1;
        if (day > today) {
          return sum + parseFloat(sub.amount);
        }
        return sum;
      }, 0);
    });

    const accounts = ref([]);
    
    
    const moneyLeft = computed(() => {
      if (currentBudget.value === null) return { text: 'N/A', status: 'neutral', label: 'Money Left' };
      
      // Budget + Income - Expenses
      let left = (currentBudget.value + monthlyStats.value.income) - monthlyTotal.value;
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
        // Match logic with monthlyStats:
        // Exclude transfers
        if (tx.category === 'Transfer' || tx.type === 'transfer') return acc;
        // Exclude income
        if (tx.type === 'income') return acc;
        
        // Everything else is treated as an expense
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

    const incomeCategorySummary = computed(() => {
        if (!filteredTransactions.value.length || monthlyStats.value.income === 0) return [];
        const summary = filteredTransactions.value.reduce((acc, tx) => {
            // Include ONLY income
            if (tx.type !== 'income') return acc;
            
            const category = tx.category || 'Other';
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
            percentage: (summary[name].total / monthlyStats.value.income) * 100
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

    const openDetailModal = (categoryName, type) => {
      selectedCategoryData.value = {
        name: categoryName,
        transactions: filteredTransactions.value.filter(tx => 
            (tx.category || (type === 'income' ? 'Other' : 'Uncategorized')) === categoryName && 
            (type === 'income' ? tx.type === 'income' : (tx.type === 'expense' || !tx.type))
        )
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
      
      axios.get('/api/accounts')
           .then(res => accounts.value = res.data)
           .catch(err => console.error(err));
      
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
      incomeCategorySummary,
      fetchBudget,
      setBudget,
      openEditModal,
      handleSaveTransaction,
      handleDeleteFromModal,
      handleEditFromModal,
      openDetailModal,
      isBudgetModalVisible,
      accounts
    };
  }
}
</script>

<style scoped>
.container { 
    max-width: 900px; 
    margin: 0 auto; 
    padding: 2rem;
}

.back-link { 
    margin-bottom: 2rem; 
}

.back-link a { 
    font-weight: 600;
    color: var(--primary-color); 
    text-decoration: none; 
    display: inline-flex;
    align-items: center;
    transition: transform 0.2s;
}

.back-link a:hover {
    transform: translateX(-4px);
}

.top-panel {
  display: flex;
  background: var(--card-background);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: var(--glass-border);
  border-radius: 16px;
  box-shadow: var(--glass-shadow);
  margin-bottom: 2rem;
  padding: 2rem;
  gap: 3rem;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.top-panel:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 40px 0 rgba(31, 38, 135, 0.2);
}

.filter-controls {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  justify-content: center;
  flex-basis: 25%;
  flex-shrink: 0;
  border-right: 1px solid var(--border-color);
  padding-right: 2rem;
}

.select-wrapper {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.filter-controls label {
  font-weight: 600;
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--subtle-text-color);
}

.filter-controls select {
  padding: 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background-color: rgba(255, 255, 255, 0.5);
  font-size: 1rem;
  color: var(--text-color);
  cursor: pointer;
  transition: all 0.2s;
}

.filter-controls select:hover {
  border-color: var(--primary-color);
}

.filter-controls select:focus {
  outline: none;
  border-color: var(--primary-color);
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
}

.budget-and-summary {
  flex-grow: 1;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  text-align: center;
  height: 100%;
  align-items: center;
}

.summary-item {
  position: relative;
  padding: 0 1rem;
}

.summary-item:not(:last-child)::after {
  content: '';
  position: absolute;
  right: 0;
  top: 20%;
  height: 60%;
  width: 1px;
  background-color: var(--border-color);
}

.summary-item h3 {
  margin: 0 0 0.75rem;
  font-size: 0.85rem;
  color: var(--subtle-text-color);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-weight: 600;
}

.summary-item .summary-amount {
  margin: 0;
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--text-color);
  letter-spacing: -0.02em;
  white-space: nowrap; /* Prevent line break */
}

.summary-amount.positive { color: var(--positive-color); }
.summary-amount.negative { color: var(--negative-color); }

.edit-budget-btn {
  background: none;
  border: none;
  color: var(--primary-color);
  cursor: pointer;
  font-size: 1rem;
  padding: 4px;
  border-radius: 4px;
  transition: all 0.2s;
  margin-left: 4px;
}

.edit-budget-btn:hover {
  background-color: rgba(79, 70, 229, 0.1);
}

html.dark .edit-budget-btn {
  color: #f1f5f9; /* Slate 100 */
}

html.dark .edit-budget-btn:hover {
  background-color: rgba(255, 255, 255, 0.1);
}

.category-breakdown {
  background: var(--card-background);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: var(--glass-border);
  border-radius: 16px;
  box-shadow: var(--glass-shadow);
  padding: 2rem;
}

.category-breakdown h3 {
  margin-top: 0;
  margin-bottom: 2rem;
  text-align: center;
  color: var(--text-color);
  font-size: 1.5rem;
  font-weight: 700;
}

.category-breakdown ul {
  list-style: none;
  padding: 0;
  margin: 2rem 0 0;
  display: grid;
  gap: 1rem;
}

.category-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
  padding: 1.25rem;
  border-radius: 12px;
  background-color: rgba(255, 255, 255, 0.4);
  border: 1px solid var(--border-color);
  text-align: left;
  cursor: pointer;
  transition: all 0.3s ease;
}

.category-item:hover {
  background-color: rgba(255, 255, 255, 0.8);
  transform: translateX(4px);
  border-color: var(--primary-color);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.category-name {
  font-weight: 600;
  font-size: 0.9rem;
  color: var(--text-color);
  display: block;
  margin-bottom: 0.25rem;
}

.transaction-count {
  font-size: 0.75rem;
  color: var(--subtle-text-color);
}

.category-spending {
  text-align: right;
}

.category-total {
  font-weight: 700;
  font-size: 1rem;
  display: block;
  color: var(--text-color);
  margin-bottom: 0.25rem;
}

.category-percentage {
  font-size: 0.8rem;
  color: white;
  font-weight: 600;
  background: var(--primary-color);
  padding: 2px 8px;
  border-radius: 12px;
}

.no-transactions {
  text-align: center;
  color: var(--subtle-text-color);
  margin-top: 4rem;
  font-size: 1.1rem;
}

.income-section {
  margin-top: 2rem;
}

.income-section .category-percentage {
  background-color: var(--positive-color);
}

@media (max-width: 768px) {
  .top-panel {
    flex-direction: column;
    gap: 2rem;
    padding: 1.5rem;
  }

  .filter-controls {
    flex-direction: row;
    border-right: none;
    border-bottom: 1px solid var(--border-color);
    padding-right: 0;
    padding-bottom: 1.5rem;
    flex-basis: auto;
  }
  
  .select-wrapper {
    flex: 1;
  }

  .summary-grid {
    grid-template-columns: 1fr;
    gap: 1.5rem;
  }
  
  .summary-item:not(:last-child)::after {
    display: none;
  }
  
  .summary-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1rem;
  }
  
  .summary-item h3 {
    margin: 0;
    text-align: left;
  }

  .summary-item .summary-amount {
    font-size: 1.2rem;
  }
}
</style>