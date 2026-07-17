<template>
  <div class="w-full">
    <!-- Header Section -->
    <section class="mb-12">
      <div class="flex items-center gap-4 mb-2">
        <router-link to="/accounts" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center">
          <span class="material-symbols-outlined">arrow_back</span>
        </router-link>
        <h2 class="font-headline text-3xl md:text-4xl font-light text-on-surface uppercase tracking-tight m-0" v-if="account">{{ account.name }}</h2>
        <h2 class="font-headline text-3xl md:text-4xl font-light text-on-surface uppercase tracking-tight m-0" v-else>Loading...</h2>
      </div>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-4 mb-8"></div>
    </section>

    <div v-if="accountTransactions.length > 0">
      <!-- Filter Controls -->
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

    <CategorySummaryList title="Spending by Category" :items="categorySummary" variant="expense" @select="name => openDetail(name, 'expense')" />
    <CategorySummaryList title="Income by Category" :items="incomeCategorySummary" variant="income" @select="name => openDetail(name, 'income')" />

    <div v-if="categorySummary.length === 0 && incomeCategorySummary.length === 0" class="py-12 text-center border-b border-outline-variant/20">
      <p class="font-body text-on-surface-variant">No transactions found for this period.</p>
    </div>
  </div>

  <CategoryDetailModal
    v-if="isDetailModalVisible"
    :categoryName="selectedCategoryData.name"
    :transactions="selectedCategoryData.transactions"
    @close="isDetailModalVisible = false"
    @edit="openEditModal"
    @delete="requestDelete"
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
import { computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';

import { useTransactions } from '../composables/useTransactions';
import { useAccounts } from '../composables/useAccounts';
import { useMonthlyFilter } from '../composables/useMonthlyFilter';
import { useTransactionModals } from '../composables/useTransactionModals';

import TransactionFormModal from '../components/TransactionFormModal.vue';
import CategoryDetailModal from '../components/CategoryDetailModal.vue';
import CategorySummaryList from '../components/CategorySummaryList.vue';
import ConfirmDeleteModal from '../components/ConfirmDeleteModal.vue';

export default {
  name: 'AccountTransactions',
  components: {
    TransactionFormModal,
    CategoryDetailModal,
    CategorySummaryList,
    ConfirmDeleteModal,
  },
  setup() {
    const route = useRoute();
    const accountId = route.params.id;

    const { transactions, categories, fetchTransactions, fetchCategories } = useTransactions();
    const { accounts, fetchAccounts } = useAccounts();

    const account = computed(() => accounts.value.find(acc => String(acc.id) === String(accountId)) || null);

    const accountTransactions = computed(() =>
      transactions.value.filter(tx => String(tx.account_id) === String(accountId))
    );

    const monthly = useMonthlyFilter(accountTransactions);
    const modals = useTransactionModals();

    const openDetail = (name, type) => {
      modals.openDetailModal(name, type, monthly.filteredTransactions.value);
    };

    onMounted(async () => {
      await fetchTransactions();
      fetchCategories();
      fetchAccounts();
      monthly.selectLatestPeriod();
    });

    return {
      account,
      accounts,
      accountTransactions,
      categories,
      openDetail,
      ...monthly,
      ...modals,
    };
  }
}
</script>
