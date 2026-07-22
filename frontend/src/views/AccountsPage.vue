<template>
  <div class="w-full">
    <!-- Header Section -->
    <section class="mb-6">
      <h2 class="font-headline text-2xl md:text-3xl font-light text-on-surface uppercase tracking-tight mb-2">Accounts</h2>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-3 mb-5"></div>
      <div class="flex flex-col md:flex-row md:justify-between md:items-end gap-6">
        <div>
          <p class="font-label text-sm text-on-surface-variant uppercase tracking-[0.1em] mb-1">Total Net Balance</p>
          <p class="font-headline text-3xl md:text-5xl text-primary-container tracking-tighter">RM {{ totalBalance.toFixed(2) }}</p>
        </div>
        <button @click="openAddModal" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-6 py-3 hover:bg-primary transition-colors flex items-center gap-2 w-fit">
          <span class="material-symbols-outlined text-[18px]">add</span>
          New Entity
        </button>
      </div>
    </section>

    <!-- Accounts Grid/List -->
    <section class="flex flex-col border-t border-outline-variant/20">
      <!-- List Header (Desktop) -->
      <div class="hidden md:grid grid-cols-12 gap-4 py-2.5 px-3 border-b border-outline-variant/20 bg-surface-container-lowest">
        <div class="col-span-5 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Institution / Alias</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Type</div>
        <div class="col-span-3 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Available Balance</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Actions</div>
      </div>

      <!-- Item. Same two-line-on-mobile shape as TransactionRow: name and
           balance lead, the type chip and actions sit underneath. -->
      <div class="group grid grid-cols-[1fr_auto] items-center gap-x-3 gap-y-1 py-2.5 px-3 md:grid-cols-12 md:gap-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors relative cursor-pointer" v-for="account in accounts" :key="account.id" @click="viewAccount(account)">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container opacity-0 group-hover:opacity-100 transition-opacity"></div>

        <div class="flex items-center gap-2.5 min-w-0 md:col-span-5 md:order-1">
          <div class="w-8 h-8 shrink-0 border border-outline-variant/30 flex items-center justify-center text-on-surface-variant bg-surface-container-high group-hover:border-primary/50 transition-colors">
            <span class="material-symbols-outlined text-[18px]">{{ getAccountIcon(account.type) }}</span>
          </div>
          <div class="font-headline text-lg md:text-xl text-on-surface tracking-tight truncate">{{ account.name }}</div>
        </div>

        <div class="text-right md:col-span-3 md:order-3">
          <span class="font-headline text-xl md:text-2xl tracking-tighter whitespace-nowrap" :class="{'text-error': (account.balance || 0) < 0, 'text-primary-container': (account.balance || 0) >= 0}">RM {{ (account.balance || 0).toFixed(2) }}</span>
        </div>

        <div class="flex items-center min-w-0 md:col-span-2 md:order-2">
          <span class="px-1.5 py-0.5 bg-surface-container-high border border-outline-variant/20 font-label text-[9px] text-on-surface-variant uppercase tracking-widest truncate">{{ account.type || 'Account' }}</span>
        </div>

        <div class="flex justify-end gap-1 md:col-span-2 md:order-4">
          <button @click.stop="editAccount(account)" aria-label="Manage account" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center p-1">
            <span class="material-symbols-outlined text-[16px] md:text-[18px]">edit</span>
          </button>
          <button @click.stop="requestDelete(account)" aria-label="Delete account" class="text-on-surface-variant hover:text-error transition-colors flex items-center justify-center p-1">
            <span class="material-symbols-outlined text-[16px] md:text-[18px]">delete</span>
          </button>
        </div>
      </div>

      <!-- Empty State -->
      <div v-if="accounts.length === 0" class="py-10 text-center border-b border-outline-variant/20">
        <p class="font-body text-on-surface-variant">No entities found. Initialize one to proceed.</p>
      </div>
    </section>

    <!-- Add/Edit Modal -->
    <BaseModal v-if="showModal" size="md" :title="isEditing ? 'Edit Entity' : 'New Entity'" @close="showModal = false">
        <form @submit.prevent="submitAccount" class="flex flex-col gap-6">
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Account Name</label>
            <input v-model="form.name" type="text" required placeholder="e.g. Maybank" class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none">
          </div>

          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Type</label>
            <select v-model="form.type" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none">
              <option value="Bank">Bank Account</option>
              <option value="E-Wallet">E-Wallet</option>
              <option value="Cash">Cash</option>
              <option value="Card">Card</option>
              <option value="Other">Other</option>
            </select>
          </div>

          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Initial Balance</label>
            <input v-model.number="form.initial_balance" type="number" step="0.01" class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none">
            <p class="font-body text-xs text-on-surface-variant mt-1">Starting balance before any transactions.</p>
          </div>

          <div class="flex justify-end gap-4 mt-4">
            <button type="button" @click="showModal = false" class="border border-outline text-on-surface px-6 py-3 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors">Cancel</button>
            <button type="submit" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-6 py-3 hover:bg-primary transition-colors">{{ isEditing ? 'Save' : 'Create' }}</button>
          </div>
        </form>
    </BaseModal>

    <ConfirmDeleteModal
      v-if="accountToDelete"
      title="Delete Account"
      :message="`Delete ${accountToDelete.name}? Its transactions will remain but become unassigned. This cannot be undone.`"
      @confirm="confirmDelete"
      @cancel="accountToDelete = null"
    />
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAccounts } from '../composables/useAccounts';
import ConfirmDeleteModal from '../components/ConfirmDeleteModal.vue';
import BaseModal from '../components/BaseModal.vue';

export default {
  name: 'AccountsPage',
  components: { ConfirmDeleteModal, BaseModal },
  setup() {
    const router = useRouter();
    const { accounts, fetchAccounts, saveAccount, deleteAccount } = useAccounts();

    const showModal = ref(false);
    const isEditing = ref(false);
    const form = ref({ id: null, name: '', type: 'Bank', initial_balance: 0 });
    const accountToDelete = ref(null);

    const totalBalance = computed(() =>
      accounts.value.reduce((sum, acc) => sum + (acc.balance || 0), 0)
    );

    const viewAccount = (account) => {
      router.push(`/accounts/${account.id}`);
    };

    const openAddModal = () => {
      isEditing.value = false;
      form.value = { id: null, name: '', type: 'Bank', initial_balance: 0 };
      showModal.value = true;
    };

    const editAccount = (account) => {
      isEditing.value = true;
      form.value = { ...account };
      showModal.value = true;
    };

    const submitAccount = async () => {
      try {
        await saveAccount(form.value);
        showModal.value = false;
      } catch (error) {
        console.error('Error saving account:', error);
        alert('Failed to save account');
      }
    };

    const requestDelete = (account) => {
      accountToDelete.value = account;
    };

    const confirmDelete = async () => {
      const account = accountToDelete.value;
      accountToDelete.value = null;
      try {
        await deleteAccount(account.id);
      } catch (error) {
        console.error('Error deleting account:', error);
        alert('Failed to delete account');
      }
    };

    const getAccountIcon = (type) => {
      const map = {
        'Bank': 'account_balance',
        'E-Wallet': 'account_balance_wallet',
        'Cash': 'payments',
        'Card': 'credit_card',
        'Other': 'folder'
      };
      return map[type] || 'folder';
    };

    onMounted(fetchAccounts);

    return {
      accounts,
      showModal,
      isEditing,
      form,
      accountToDelete,
      totalBalance,
      viewAccount,
      openAddModal,
      editAccount,
      submitAccount,
      requestDelete,
      confirmDelete,
      getAccountIcon
    };
  }
};
</script>
