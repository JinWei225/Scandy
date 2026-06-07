<template>
  <div class="w-full">
    <!-- Header Section -->
    <section class="mb-12">
      <div class="flex items-center gap-4 mb-2">
        <router-link to="/" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center">
          <span class="material-symbols-outlined">arrow_back</span>
        </router-link>
        <h2 class="font-headline text-3xl md:text-4xl font-light text-on-surface uppercase tracking-tight m-0">Monthly Summary</h2>
      </div>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-4 mb-8"></div>
    </section>

    <div v-if="transactions.length > 0">
      <!-- Section 1: The Filter Controls -->
      <section class="mb-8 bg-surface-container-lowest border border-outline-variant/30 p-6 flex flex-col md:flex-row gap-6 items-end relative">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container"></div>
        <div class="flex flex-col gap-2 flex-1 w-full">
          <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Year</label>
          <select v-model="selectedYear" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full">
            <option v-for="year in availableYears" :key="year" :value="year">{{ year }}</option>
          </select>
        </div>
        <div class="flex flex-col gap-2 flex-1 w-full">
          <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Month</label>
          <select v-model="selectedMonth" :disabled="!selectedYear" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full disabled:opacity-50">
            <option v-for="month in availableMonths" :key="month" :value="month">{{ month }}</option>
          </select>
        </div>
      </section>

      <!-- Section 2: The Income and Expense Summary -->
      <section class="mb-12 grid grid-cols-1 md:grid-cols-3 gap-0 border border-outline-variant/20 bg-surface-container-lowest">
        <div class="p-6 border-b md:border-b-0 md:border-r border-outline-variant/20 flex flex-col items-center md:items-start text-center md:text-left">
          <h3 class="font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] mb-2">Income</h3>
          <p class="font-headline text-2xl md:text-4xl text-[#34d399] tracking-tighter">RM {{ monthlyStats.income.toFixed(2) }}</p>
        </div>
        <div class="p-6 border-b md:border-b-0 md:border-r border-outline-variant/20 flex flex-col items-center md:items-start text-center md:text-left">
          <h3 class="font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] mb-2">Expenses</h3>
          <p class="font-headline text-2xl md:text-4xl text-error tracking-tighter">RM {{ monthlyStats.expense.toFixed(2) }}</p>
        </div>
        <div class="p-6 flex flex-col items-center md:items-start text-center md:text-left relative overflow-hidden group">
          <div class="absolute inset-0 bg-primary-container/5 opacity-0 group-hover:opacity-100 transition-opacity"></div>
          <h3 class="font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] mb-2 z-10">{{ moneyLeft.label }}</h3>
          <p class="font-headline text-2xl md:text-4xl tracking-tighter z-10" :class="moneyLeft.status === 'positive' ? 'text-primary-container' : 'text-error'">{{ moneyLeft.text }}</p>
        </div>
      </section>
    </div>

    <!-- Category Breakdown (Expenses) -->
    <section v-if="categorySummary.length > 0" class="mb-12">
      <h3 class="font-headline text-xl md:text-2xl text-on-surface uppercase tracking-tight mb-6">Expenses by Category</h3>
      <div class="flex flex-col border-t border-outline-variant/20">
        <button v-for="item in categorySummary" :key="item.name" @click="openDetailModal(item.name, 'expense')" class="group grid grid-cols-12 gap-4 py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative text-left w-full">
          <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-error opacity-0 group-hover:opacity-100 transition-opacity"></div>
          <div class="col-span-8 flex flex-col">
            <span class="font-headline text-base md:text-lg text-on-surface tracking-tight">{{ item.name }}</span>
            <span class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">{{ item.count }} transactions</span>
          </div>
          <div class="col-span-4 flex flex-col items-end">
            <span class="font-headline text-lg md:text-xl text-on-surface tracking-tighter">RM {{ item.total.toFixed(2) }}</span>
            <span class="px-2 py-1 mt-1 bg-error/10 border border-error/20 font-label text-[10px] text-error uppercase tracking-widest">{{ item.percentage.toFixed(0) }}%</span>
          </div>
        </button>
      </div>
    </section>
    
    <!-- Category Breakdown (Income) -->
    <section v-if="incomeCategorySummary.length > 0" class="mb-12">
      <h3 class="font-headline text-xl md:text-2xl text-on-surface uppercase tracking-tight mb-6">Income by Category</h3>
      <div class="flex flex-col border-t border-outline-variant/20">
        <button v-for="item in incomeCategorySummary" :key="item.name" @click="openDetailModal(item.name, 'income')" class="group grid grid-cols-12 gap-4 py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative text-left w-full">
          <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-[#34d399] opacity-0 group-hover:opacity-100 transition-opacity"></div>
          <div class="col-span-8 flex flex-col">
            <span class="font-headline text-base md:text-lg text-on-surface tracking-tight">{{ item.name }}</span>
            <span class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">{{ item.count }} transactions</span>
          </div>
          <div class="col-span-4 flex flex-col items-end">
            <span class="font-headline text-lg md:text-xl text-on-surface tracking-tighter">RM {{ item.total.toFixed(2) }}</span>
            <span class="px-2 py-1 mt-1 bg-[#34d399]/10 border border-[#34d399]/20 font-label text-[10px] text-[#34d399] uppercase tracking-widest">{{ item.percentage.toFixed(0) }}%</span>
          </div>
        </button>
      </div>
    </section>

    <div v-if="categorySummary.length === 0 && incomeCategorySummary.length === 0" class="py-12 text-center border-b border-outline-variant/20">
      <p class="font-body text-on-surface-variant">No transactions recorded yet.</p>
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

  <ConfirmDeleteModal
    v-if="isConfirmDeleteVisible"
    @confirm="confirmDelete"
    @cancel="cancelDelete"
  />
</template>

<script>
import { ref, computed, watch, onMounted, nextTick } from 'vue';

import { useTransactions } from '../composables/useTransactions';

import EditModal from '../components/EditModal.vue';
import CategoryDetailModal from '../components/CategoryDetailModal.vue';
import ConfirmDeleteModal from '../components/ConfirmDeleteModal.vue';
import axios from 'axios';

export default {
  name: 'AllTransactions',
  components: {
    EditModal,
    ConfirmDeleteModal,
    CategoryDetailModal,
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
    const isModalVisible = ref(false);
    const transactionToEdit = ref(null);
    const isDetailModalVisible = ref(false);
    const selectedCategoryData = ref({ name: '', transactions: [] });
    const isConfirmDeleteVisible = ref(false);
    const pendingDeleteId = ref(null);

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
      // Income - Expenses
      let left = monthlyStats.value.income - monthlyStats.value.expense;
      let label = 'Balance';

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
      if (!filteredTransactions.value.length || monthlyStats.value.expense === 0) return [];
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
        percentage: (summary[name].total / monthlyStats.value.expense) * 100
      })).sort((a, b) => b.total - a.total);
    });

    const incomeCategorySummary = computed(() => {
        if (!filteredTransactions.value.length || monthlyStats.value.income === 0) return [];
        const summary = filteredTransactions.value.reduce((acc, tx) => {
            // Include ONLY income, and exclude Transfers
            if (tx.type !== 'income' || tx.category === 'Transfer') return acc;
            
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
        await fetchTransactions(); // Refresh data from composable
        isDetailModalVisible.value = false;
      } catch (error) {
        console.error('Error updating transaction:', error);
        alert('Failed to update transaction.');
      }
    };

    const handleDeleteFromModal = (transactionId) => {
      pendingDeleteId.value = transactionId;
      isConfirmDeleteVisible.value = true;
    };

    const confirmDelete = async () => {
      isConfirmDeleteVisible.value = false;
      try {
        await axios.delete(`/api/transactions/${pendingDeleteId.value}`);
        await fetchTransactions();
        isDetailModalVisible.value = false;
      } catch (error) {
        console.error('Error deleting transaction:', error);
      } finally {
        pendingDeleteId.value = null;
      }
    };

    const cancelDelete = () => {
      isConfirmDeleteVisible.value = false;
      pendingDeleteId.value = null;
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
      categories,
      isModalVisible,
      transactionToEdit,
      isDetailModalVisible,
      selectedCategoryData,
      availableYears,
      availableMonths,
      filteredTransactions,
      monthlyStats,
      moneyLeft,
      categorySummary,
      incomeCategorySummary,
      openEditModal,
      handleSaveTransaction,
      handleDeleteFromModal,
      confirmDelete,
      cancelDelete,
      isConfirmDeleteVisible,
      handleEditFromModal,
      openDetailModal,
      accounts
    };
  }
}
</script>

<style scoped>
/* Scoped styles removed in favor of global Tailwind classes */
</style>