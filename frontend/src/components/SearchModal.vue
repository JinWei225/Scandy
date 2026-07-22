<template>
  <!-- Scrim matches BaseModal (see the note there). -->
  <div class="fixed inset-0 bg-on-surface/40 backdrop-blur-md z-[100] flex flex-col items-center modal-inset-safe modal-inset-safe-top" @click.self="$emit('close')">
    <div class="bg-surface border border-outline-variant/30 w-full max-w-2xl relative flex flex-col max-h-full">
      <!-- Header -->
      <div class="flex items-center justify-between px-6 py-5 border-b border-outline-variant/20">
        <h2 class="font-headline text-2xl text-primary-container uppercase tracking-tight">Search Logs</h2>
        <button @click="$emit('close')" class="text-on-surface-variant hover:text-on-surface transition-colors flex items-center justify-center">
          <span class="material-symbols-outlined">close</span>
        </button>
      </div>

      <!-- Search Input -->
      <div class="px-6 py-4 border-b border-outline-variant/20">
        <div class="flex items-center gap-3">
          <span class="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
          <input
            type="text"
            v-model="searchQuery"
            placeholder="Description, category, amount, date..."
            ref="searchInput"
            class="flex-1 bg-transparent border-0 focus:ring-0 px-0 py-1 text-on-surface font-body text-sm outline-none placeholder:text-on-surface-variant/50"
          />
          <button v-if="searchQuery" @click="searchQuery = ''" class="text-on-surface-variant hover:text-on-surface transition-colors">
            <span class="material-symbols-outlined text-[16px]">backspace</span>
          </button>
        </div>
      </div>

      <!-- Results -->
      <div class="flex-1 overflow-y-auto">
        <div v-if="!searchQuery" class="py-10 text-center">
          <p class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Type to search transactions</p>
        </div>

        <div v-else-if="filteredTransactions.length === 0" class="py-10 text-center">
          <p class="font-label text-xs text-on-surface-variant uppercase tracking-widest">No results for "{{ searchQuery }}"</p>
        </div>

        <div v-else>
          <div class="hidden md:grid grid-cols-12 gap-4 py-2.5 px-3 bg-surface-container-lowest border-b border-outline-variant/20">
            <div class="col-span-2 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em]">Date</div>
            <div class="col-span-4 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em]">Description</div>
            <div class="col-span-2 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em]">Category</div>
            <div class="col-span-2 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em] text-right">Amount</div>
            <div class="col-span-2 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em] text-right">Actions</div>
          </div>

          <TransactionRow
            v-for="transaction in filteredTransactions"
            :key="transaction.id"
            :transaction="transaction"
            @select="openViewModal"
            @edit="openEditModal"
            @delete="requestDelete"
          />
        </div>
      </div>

      <!-- Footer count -->
      <div v-if="searchQuery && filteredTransactions.length > 0" class="px-6 py-3 border-t border-outline-variant/20 bg-surface-container-lowest">
        <p class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">{{ filteredTransactions.length }} result{{ filteredTransactions.length !== 1 ? 's' : '' }} found</p>
      </div>
    </div>
  </div>

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
import { ref, computed, onMounted, nextTick } from 'vue';
import { useTransactions } from '../composables/useTransactions';
import { useAccounts } from '../composables/useAccounts';
import { useTransactionModals } from '../composables/useTransactionModals';
import TransactionFormModal from './TransactionFormModal.vue';
import ConfirmDeleteModal from './ConfirmDeleteModal.vue';
import TransactionRow from './TransactionRow.vue';
import TransactionDetailModal from './TransactionDetailModal.vue';

export default {
  name: 'SearchModal',
  components: { TransactionFormModal, ConfirmDeleteModal, TransactionRow, TransactionDetailModal },
  emits: ['close'],
  setup() {
    const { transactions, categories, fetchTransactions, fetchCategories } = useTransactions();
    const { accounts, fetchAccounts } = useAccounts();
    const modals = useTransactionModals();
    const searchQuery = ref('');
    const searchInput = ref(null);

    onMounted(async () => {
      fetchCategories();
      fetchAccounts();
      await fetchTransactions();
      nextTick(() => {
        searchInput.value?.focus();
      });
    });

    const filteredTransactions = computed(() => {
      if (!searchQuery.value) return [];
      const query = searchQuery.value.toLowerCase();
      return transactions.value.filter(tx => {
        return (
          tx.description?.toLowerCase().includes(query) ||
          tx.category?.toLowerCase().includes(query) ||
          tx.amount?.toString().toLowerCase().includes(query) ||
          tx.date?.includes(query)
        );
      });
    });

    return {
      searchQuery,
      searchInput,
      filteredTransactions,
      categories,
      accounts,
      ...modals
    };
  }
}
</script>
