<template>
  <div class="w-full">
    <!-- Header Section -->
    <section class="mb-12">
      <div class="flex items-center gap-4 mb-2">
        <router-link to="/accounts" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center">
          <span class="material-symbols-outlined">arrow_back</span>
        </router-link>
        <h2 class="font-headline text-4xl font-light text-on-surface uppercase tracking-tight m-0" v-if="account">{{ account.name }}</h2>
        <h2 class="font-headline text-4xl font-light text-on-surface uppercase tracking-tight m-0" v-else>Loading...</h2>
      </div>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-4 mb-8"></div>
    </section>

    <div v-if="transactions.length > 0">
      <!-- Section 1: The Filter Controls -->
      <section class="mb-12 bg-surface-container-lowest border border-outline-variant/30 p-6 flex flex-col md:flex-row gap-6 items-end relative">
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
    </div>

    <!-- Category Breakdown (Expenses) -->
    <section v-if="categorySummary.length > 0" class="mb-12">
      <h3 class="font-headline text-2xl text-on-surface uppercase tracking-tight mb-6">Spending by Category</h3>
      <div class="flex flex-col border-t border-outline-variant/20">
        <button v-for="item in categorySummary" :key="item.name" @click="openDetailModal(item.name, 'expense')" class="group grid grid-cols-12 gap-4 py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative text-left w-full">
          <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-error opacity-0 group-hover:opacity-100 transition-opacity"></div>
          <div class="col-span-8 flex flex-col">
            <span class="font-headline text-lg text-on-surface tracking-tight">{{ item.name }}</span>
            <span class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">{{ item.count }} transactions</span>
          </div>
          <div class="col-span-4 flex flex-col items-end">
            <span class="font-headline text-xl text-on-surface tracking-tighter">RM {{ item.total.toFixed(2) }}</span>
            <span class="px-2 py-1 mt-1 bg-error/10 border border-error/20 font-label text-[10px] text-error uppercase tracking-widest">{{ item.percentage.toFixed(0) }}%</span>
          </div>
        </button>
      </div>
    </section>
    
    <!-- Category Breakdown (Income) -->
    <section v-if="incomeCategorySummary.length > 0" class="mb-12">
      <h3 class="font-headline text-2xl text-on-surface uppercase tracking-tight mb-6">Income by Category</h3>
      <div class="flex flex-col border-t border-outline-variant/20">
        <button v-for="item in incomeCategorySummary" :key="item.name" @click="openDetailModal(item.name, 'income')" class="group grid grid-cols-12 gap-4 py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative text-left w-full">
          <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-[#34d399] opacity-0 group-hover:opacity-100 transition-opacity"></div>
          <div class="col-span-8 flex flex-col">
            <span class="font-headline text-lg text-on-surface tracking-tight">{{ item.name }}</span>
            <span class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">{{ item.count }} transactions</span>
          </div>
          <div class="col-span-4 flex flex-col items-end">
            <span class="font-headline text-xl text-on-surface tracking-tighter">RM {{ item.total.toFixed(2) }}</span>
            <span class="px-2 py-1 mt-1 bg-[#34d399]/10 border border-[#34d399]/20 font-label text-[10px] text-[#34d399] uppercase tracking-widest">{{ item.percentage.toFixed(0) }}%</span>
          </div>
        </button>
      </div>
    </section>

    <div v-if="categorySummary.length === 0 && incomeCategorySummary.length === 0" class="py-12 text-center border-b border-outline-variant/20">
      <p class="font-body text-on-surface-variant">No transactions found for this period.</p>
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
</style>
