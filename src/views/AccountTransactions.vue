<template>
  <div class="container">
    <div class="back-link">
      <router-link to="/accounts">&larr; Back to Accounts</router-link>
    </div>

    <div class="page-header">
        <h1 v-if="account">{{ account.name }} Transactions</h1>
        <h1 v-else>Loading...</h1>
    </div>

    <div v-if="transactions.length > 0" class="top-panel">
      <!-- Only Filter Controls, No Budget Summary -->
      <div class="filter-controls full-width">
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
    </div>

    <div v-if="categorySummary.length > 0" class="category-breakdown">
      <h3>Spending by Category</h3>
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
      No transactions found for this period.
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
</template>

<script>
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import { useTransactions } from '../composables/useTransactions';
import { useRoute } from 'vue-router';
import EditModal from '../components/EditModal.vue';
import CategoryDetailModal from '../components/CategoryDetailModal.vue';
import axios from 'axios';

export default {
  name: 'AccountTransactions',
  components: {
    EditModal,
    CategoryDetailModal,
  },
  setup() {
    const route = useRoute();
    const accountName = route.params.name;
    const account = ref(null);
    const accounts = ref([]);
    const resolvedAccountId = ref(null);

    const { transactions, categories, fetchTransactions, fetchCategories } = useTransactions();

    const selectedYear = ref(null);
    const selectedMonth = ref(null);
    
    const isModalVisible = ref(false);
    const transactionToEdit = ref(null);
    const isDetailModalVisible = ref(false);
    const selectedCategoryData = ref({ name: '', transactions: [] });

    // --- COMPUTED --
    const accountTransactions = computed(() => {
        if (!resolvedAccountId.value) return [];
        return transactions.value.filter(tx => String(tx.account_id) === String(resolvedAccountId.value));
    });

    const availableYears = computed(() => {
      if (!accountTransactions.value.length) return [];
      const years = new Set(accountTransactions.value.map(tx => tx.date.split('/')[2]));
      return Array.from(years).sort((a, b) => b - a);
    });

    const availableMonths = computed(() => {
      if (!selectedYear.value) return [];
      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const months = new Set(
        accountTransactions.value
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
        
        return accountTransactions.value.filter(tx => 
            tx.date.split('/')[1] === monthString && 
            tx.date.split('/')[2] === selectedYear.value
        );
    });

    const monthlyStats = computed(() => {
        let expense = 0;
        let income = 0;
        if (!filteredTransactions.value.length) return { expense, income };
        
        filteredTransactions.value.forEach(tx => {
            if (tx.category === 'Transfer' || tx.type === 'transfer') return;
            const amount = parseFloat(tx.amount.replace('RM', '').trim());
            if (isNaN(amount)) return;
            
            if (tx.type === 'income') {
                income += amount;
            } else {
                expense += amount;
            }
        });
        return { expense, income };
    });

    const categorySummary = computed(() => {
      if (!filteredTransactions.value.length || monthlyStats.value.expense === 0) return [];
      const summary = filteredTransactions.value.reduce((acc, tx) => {
        if (tx.category === 'Transfer' || tx.type === 'transfer') return acc;
        if (tx.type === 'income') return acc;
        
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
        percentage: (summary[name].total / monthlyStats.value.expense) * 100
      })).sort((a, b) => b.total - a.total);
    });

    const incomeCategorySummary = computed(() => {
        if (!filteredTransactions.value.length || monthlyStats.value.income === 0) return [];
        const summary = filteredTransactions.value.reduce((acc, tx) => {
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
    const openEditModal = (transaction) => {
      transactionToEdit.value = transaction;
      isModalVisible.value = true;
    };

    const handleSaveTransaction = async (updatedTransaction) => {
      try {
        await axios.put(`/api/transactions/${updatedTransaction.id}`, updatedTransaction);
        isModalVisible.value = false;
        await fetchTransactions(); 
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
        await fetchTransactions(); 
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
        } else {
            selectedMonth.value = null;
        }
    });

    // --- LIFECYCLE ---
    onMounted(async () => {
      await fetchTransactions();
      fetchCategories(); 
      
      // Fetch specific account logic
      try {
        const res = await axios.get('/api/accounts');
        accounts.value = res.data;
        account.value = accounts.value.find(acc => acc.name === accountName);
        if (account.value) {
            resolvedAccountId.value = account.value.id;
        }
      } catch (err) {
        console.error(err);
      }
      
      if (availableYears.value.length > 0) {
        selectedYear.value = availableYears.value[0];
        await nextTick();
        if (availableMonths.value.length > 0) {
          selectedMonth.value = availableMonths.value[availableMonths.value.length - 1];
        }
      }
    });

    return {
      account,
      accounts,
      transactions,
      selectedYear,
      selectedMonth,
      categories,
      isModalVisible,
      transactionToEdit,
      isDetailModalVisible,
      selectedCategoryData,
      availableYears,
      availableMonths,
      filteredTransactions,
      categorySummary,
      incomeCategorySummary,
      openEditModal,
      handleSaveTransaction,
      handleDeleteFromModal,
      handleEditFromModal,
      openDetailModal
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

.page-header {
    margin-bottom: 2rem;
    text-align: center;
}

.page-header h1 {
    color: var(--text-color);
    font-weight: 800;
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
  transition: transform 0.3s ease, box-shadow 0.3s ease;
  justify-content: center;
}

.top-panel:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 40px 0 rgba(31, 38, 135, 0.2);
}

.filter-controls {
  display: flex;
  flex-direction: row;
  gap: 1rem;
  justify-content: center;
  align-items: flex-start;
  width: 100%;
}

.select-wrapper {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  min-width: 0; /* Allow shrinking */
  flex: 1; /* Distribute space equally */
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
  width: 100%;
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

.income-section {
  margin-top: 2rem;
}

.income-section .category-percentage {
  background-color: var(--positive-color);
}

.no-transactions {
  text-align: center;
  color: var(--subtle-text-color);
  margin-top: 4rem;
  font-size: 1.1rem;
}

/* Dark Mode Overrides */
html.dark .filter-controls select {
  background-color: rgba(30, 41, 59, 0.5);
  color: white;
  border-color: rgba(255, 255, 255, 0.1);
}

html.dark .filter-controls select:focus {
  background-color: rgba(30, 41, 59, 0.8);
}
</style>
