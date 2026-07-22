<template>
  <div class="w-full">
    <!-- Header Section -->
    <section class="mb-6">
      <div class="flex items-center gap-4 mb-2">
        <router-link to="/" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center">
          <span class="material-symbols-outlined">arrow_back</span>
        </router-link>
        <h2 class="font-headline text-2xl md:text-3xl font-light text-on-surface uppercase tracking-tight m-0">Monthly Summary</h2>
      </div>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-3 mb-5"></div>
    </section>

    <div v-if="transactions.length > 0">
      <!-- Section 1: The Filter Controls -->
      <section class="mb-5 bg-surface-container-lowest border border-outline-variant/30 px-4 py-3 flex flex-row gap-4 items-end relative">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container"></div>
        <div class="flex flex-col gap-0.5 flex-1 min-w-0">
          <label class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">Year</label>
          <select v-model="selectedYear" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1 text-on-surface font-body text-sm rounded-none outline-none w-full">
            <option v-for="year in availableYears" :key="year" :value="year">{{ year }}</option>
          </select>
        </div>
        <div class="flex flex-col gap-0.5 flex-1 min-w-0">
          <label class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">Month</label>
          <select v-model="selectedMonth" :disabled="!selectedYear" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1 text-on-surface font-body text-sm rounded-none outline-none w-full disabled:opacity-50">
            <option v-for="month in availableMonths" :key="month" :value="month">{{ month }}</option>
          </select>
        </div>
      </section>

      <!-- Section 2: The Income and Expense Summary -->
      <section class="mb-6 grid grid-cols-1 md:grid-cols-3 gap-0 border border-outline-variant/20 bg-surface-container-lowest">
        <div class="p-6 border-b md:border-b-0 md:border-r border-outline-variant/20 flex flex-col items-center md:items-start text-center md:text-left">
          <h3 class="font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] mb-2">Income</h3>
          <p class="font-headline text-2xl md:text-4xl text-income tracking-tighter">RM {{ monthlyStats.income.toFixed(2) }}</p>
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

    <CategorySummaryList title="Expenses by Category" :items="categorySummary" variant="expense" @select="name => openDetail(name, 'expense')" />
    <CategorySummaryList title="Income by Category" :items="incomeCategorySummary" variant="income" @select="name => openDetail(name, 'income')" />

    <div v-if="categorySummary.length === 0 && incomeCategorySummary.length === 0" class="py-10 text-center border-b border-outline-variant/20">
      <p class="font-body text-on-surface-variant">No transactions recorded yet.</p>
    </div>
  </div>

  <CategoryDetailModal
    v-if="isDetailModalVisible"
    :categoryName="selectedCategoryData.name"
    :transactions="selectedCategoryData.transactions"
    @close="isDetailModalVisible = false"
    @select="openViewModal"
    @edit="openEditModal"
    @delete="requestDelete"
  />

  <TransactionDetailModal
    v-if="transactionToView"
    :transaction="transactionToView"
    :accounts="accounts"
    @close="closeViewModal"
  />

  <TransactionFormModal
    v-if="isEditModalVisible"
    :transaction="transactionToEdit"
    :categories="categories"
    :accounts="accounts"
    @close="isEditModalVisible = false"
    @save="handleSaveTransaction"
  />

  <ConfirmDeleteModal
    v-if="isConfirmDeleteVisible"
    @confirm="confirmDelete"
    @cancel="cancelDelete"
  />
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import axios from 'axios';

import { useTransactions } from '../composables/useTransactions';
import { useAccounts } from '../composables/useAccounts';
import { useMonthlyFilter, MONTH_NAMES } from '../composables/useMonthlyFilter';
import { useTransactionModals } from '../composables/useTransactionModals';

import TransactionFormModal from './TransactionFormModal.vue';
import CategoryDetailModal from './CategoryDetailModal.vue';
import CategorySummaryList from './CategorySummaryList.vue';
import ConfirmDeleteModal from './ConfirmDeleteModal.vue';
import TransactionDetailModal from './TransactionDetailModal.vue';

export default {
  name: 'AllTransactions',
  components: {
    TransactionFormModal,
    ConfirmDeleteModal,
    CategoryDetailModal,
    CategorySummaryList,
    TransactionDetailModal,
  },
  setup() {
    const { transactions, categories, fetchTransactions, fetchCategories } = useTransactions();
    const { accounts, fetchAccounts } = useAccounts();

    const monthly = useMonthlyFilter(computed(() => transactions.value));
    const modals = useTransactionModals();

    // Subscriptions feed the "Safe to Spend" figure for the current month
    const subscriptions = ref([]);
    const fetchSubscriptions = async () => {
      try {
        const response = await axios.get('/api/subscriptions');
        subscriptions.value = Array.isArray(response.data) ? response.data : [];
      } catch (error) {
        console.error('Error fetching subscriptions:', error);
      }
    };

    const remainingSubscriptions = computed(() => {
      const now = new Date();
      // Only applies when viewing the current month/year
      if (monthly.selectedYear.value !== String(now.getFullYear()) ||
          monthly.selectedMonth.value !== MONTH_NAMES[now.getMonth()]) {
        return 0;
      }
      const today = now.getDate();
      return subscriptions.value.reduce((sum, sub) => {
        const day = parseInt(sub.day_of_month) || 1;
        const amount = parseFloat(sub.amount);
        if (day > today && !isNaN(amount)) {
          return sum + amount;
        }
        return sum;
      }, 0);
    });

    const moneyLeft = computed(() => {
      let left = monthly.monthlyStats.value.income - monthly.monthlyStats.value.expense;
      let label = 'Balance';

      if (remainingSubscriptions.value > 0) {
        left -= remainingSubscriptions.value;
        label = 'Safe to Spend';
      }

      const status = left >= 0 ? 'positive' : 'negative';
      return { text: `RM ${left.toFixed(2)}`, status, label };
    });

    const openDetail = (name, type) => {
      modals.openDetailModal(name, type, monthly.filteredTransactions.value);
    };

    onMounted(async () => {
      await fetchTransactions();
      fetchCategories();
      fetchSubscriptions();
      fetchAccounts();
      monthly.selectLatestPeriod();
    });

    return {
      transactions,
      categories,
      accounts,
      moneyLeft,
      openDetail,
      ...monthly,
      ...modals,
    };
  }
}
</script>
