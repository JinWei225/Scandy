<template>
  <div class="fixed inset-0 bg-surface/90 backdrop-blur-md z-[100] flex flex-col items-center modal-inset-safe modal-inset-safe-top" @click.self="$emit('close')">
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
        <div v-if="!searchQuery" class="py-12 text-center">
          <p class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Type to search transactions</p>
        </div>

        <div v-else-if="filteredTransactions.length === 0" class="py-12 text-center">
          <p class="font-label text-xs text-on-surface-variant uppercase tracking-widest">No results for "{{ searchQuery }}"</p>
        </div>

        <div v-else>
          <div class="hidden md:grid grid-cols-12 gap-4 py-3 px-6 bg-surface-container-lowest border-b border-outline-variant/20">
            <div class="col-span-2 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em]">Date</div>
            <div class="col-span-4 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em]">Description</div>
            <div class="col-span-2 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em]">Category</div>
            <div class="col-span-2 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em] text-right">Amount</div>
            <div class="col-span-2 font-label text-[10px] text-on-surface-variant uppercase tracking-[0.1em] text-right">Actions</div>
          </div>

          <div
            v-for="transaction in filteredTransactions"
            :key="transaction.id"
            class="group grid grid-cols-1 md:grid-cols-12 gap-2 md:gap-4 py-4 px-6 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative"
          >
            <div class="absolute left-0 top-0 bottom-0 w-[2px] opacity-0 group-hover:opacity-100 transition-opacity"
              :class="transaction.type === 'expense' ? 'bg-error' : transaction.type === 'transfer' ? 'bg-tertiary' : 'bg-primary-container'"></div>

            <div class="col-span-1 md:col-span-2 flex flex-col">
              <span class="font-body text-sm text-on-surface font-mono">{{ transaction.date }}</span>
              <span class="font-label text-[10px] text-on-surface-variant tracking-widest">{{ transaction.time }}</span>
            </div>

            <div class="col-span-1 md:col-span-4">
              <span class="font-headline text-md text-on-surface tracking-tight">{{ transaction.description }}</span>
            </div>

            <div class="col-span-1 md:col-span-2 flex items-center">
              <span v-if="transaction.category" class="px-2 py-1 bg-surface-container-high border border-outline-variant/20 font-label text-[10px] text-on-surface uppercase tracking-widest">{{ transaction.category }}</span>
            </div>

            <div class="col-span-1 md:col-span-2 flex md:justify-end items-center">
              <span class="font-headline text-lg tracking-tighter"
                :class="transaction.type === 'expense' ? 'text-error' : transaction.type === 'transfer' ? 'text-on-surface' : 'text-primary-container'">
                {{ transaction.amount }}
              </span>
            </div>

            <div class="col-span-1 md:col-span-2 flex justify-end gap-2 mt-2 md:mt-0">
              <button @click="openEditModal(transaction)" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center p-1">
                <span class="material-symbols-outlined text-[18px]">edit</span>
              </button>
              <button @click="requestDelete(transaction.id)" class="text-on-surface-variant hover:text-error transition-colors flex items-center justify-center p-1">
                <span class="material-symbols-outlined text-[18px]">delete</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer count -->
      <div v-if="searchQuery && filteredTransactions.length > 0" class="px-6 py-3 border-t border-outline-variant/20 bg-surface-container-lowest">
        <p class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">{{ filteredTransactions.length }} result{{ filteredTransactions.length !== 1 ? 's' : '' }} found</p>
      </div>
    </div>
  </div>

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

export default {
  name: 'SearchModal',
  components: { TransactionFormModal, ConfirmDeleteModal },
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
