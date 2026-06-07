<template>
  <div class="w-full">
    <!-- Header Section -->
    <section class="mb-12">
      <h2 class="font-headline text-3xl md:text-4xl font-light text-on-surface uppercase tracking-tight mb-2">Accounts</h2>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-4 mb-8"></div>
      <div class="flex flex-col md:flex-row md:justify-between md:items-end gap-6">
        <div>
          <p class="font-label text-sm text-on-surface-variant uppercase tracking-[0.1em] mb-1">Total Net Balance</p>
          <p class="font-headline text-4xl md:text-6xl text-primary-container tracking-tighter">RM {{ totalBalance.toFixed(2) }}</p>
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
      <div class="hidden md:grid grid-cols-12 gap-4 py-4 px-4 border-b border-outline-variant/20 bg-surface-container-lowest">
        <div class="col-span-4 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Institution / Alias</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Type</div>
        <div class="col-span-3 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Available Balance</div>
        <div class="col-span-3 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Actions</div>
      </div>

      <!-- Item -->
      <div class="group grid grid-cols-1 md:grid-cols-12 gap-2 md:gap-4 py-6 md:py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative cursor-pointer" v-for="account in accounts" :key="account.id" @click="viewAccount(account.name)">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container opacity-0 group-hover:opacity-100 transition-opacity"></div>
        <div class="col-span-1 md:col-span-4 flex items-center gap-4">
          <div class="w-10 h-10 border border-outline-variant/30 flex items-center justify-center text-on-surface-variant bg-surface-container-high group-hover:border-primary/50 transition-colors">
            <span class="material-symbols-outlined">{{ getAccountIcon(account.type) }}</span>
          </div>
          <div>
            <div class="font-headline text-base md:text-lg text-on-surface tracking-tight">{{ account.name }}</div>
          </div>
        </div>
        <div class="col-span-1 md:col-span-2 flex items-center md:items-start mt-2 md:mt-0">
          <span class="px-2 py-1 bg-surface-container-high border border-outline-variant/20 font-label text-[10px] text-on-surface uppercase tracking-widest">{{ account.type || 'Account' }}</span>
        </div>
        <div class="col-span-1 md:col-span-3 flex md:justify-end items-center mt-2 md:mt-0">
          <span class="font-headline text-lg md:text-xl tracking-tighter" :class="{'text-error': (account.balance || 0) < 0, 'text-primary-container': (account.balance || 0) >= 0}">RM {{ (account.balance || 0).toFixed(2) }}</span>
        </div>
        <div class="col-span-1 md:col-span-3 flex justify-end gap-2 mt-4 md:mt-0 transition-opacity">
          <button @click.stop="editAccount(account)" class="border border-outline text-on-surface px-4 py-2 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors">Manage</button>
          <button @click.stop="confirmDelete(account)" class="border border-error text-error px-4 py-2 font-label text-xs uppercase tracking-widest hover:bg-error/10 transition-colors">Delete</button>
        </div>
      </div>
      
      <!-- Empty State -->
      <div v-if="accounts.length === 0" class="py-12 text-center border-b border-outline-variant/20">
        <p class="font-body text-on-surface-variant">No entities found. Initialize one to proceed.</p>
      </div>
    </section>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-surface/90 backdrop-blur-md z-[100] flex justify-center items-center p-4" @click.self="showModal = false">
      <div class="bg-surface border border-outline-variant/30 w-full max-w-md p-8 relative">
        <h2 class="font-headline text-2xl text-primary-container uppercase tracking-tight mb-6">{{ isEditing ? 'Edit Entity' : 'New Entity' }}</h2>
        
        <form @submit.prevent="saveAccount" class="flex flex-col gap-6">
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
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';

const API_URL = '/api';

export default {
  name: 'AccountsPage',
  data() {
    return {
      accounts: [],
      showModal: false,
      isEditing: false,
      form: {
        id: null,
        name: '',
        type: 'Bank',
        initial_balance: 0
      }
    };
  },
  computed: {
    totalBalance() {
      return this.accounts.reduce((sum, acc) => sum + (acc.balance || 0), 0);
    }
  },
  mounted() {
    this.fetchAccounts();
  },
  methods: {
    async fetchAccounts() {
      try {
        const response = await axios.get(`${API_URL}/accounts`);
        this.accounts = response.data;
      } catch (error) {
        console.error('Error fetching accounts:', error);
      }
    },
    viewAccount(name) {
        this.$router.push(`/accounts/${name}`);
    },
    openAddModal() {
      this.isEditing = false;
      this.form = { id: null, name: '', type: 'Bank', initial_balance: 0 };
      this.showModal = true;
    },
    editAccount(account) {
      this.isEditing = true;
      this.form = { ...account };
      this.showModal = true;
    },
    async saveAccount() {
      try {
        if (this.isEditing) {
          await axios.put(`${API_URL}/accounts/${this.form.id}`, this.form);
        } else {
          await axios.post(`${API_URL}/accounts`, this.form);
        }
        await this.fetchAccounts();
        this.showModal = false;
      } catch (error) {
        console.error('Error saving account:', error);
        alert('Failed to save account');
      }
    },
    async confirmDelete(account) {
      if (confirm(`Are you sure you want to delete ${account.name}?`)) {
        try {
          await axios.delete(`${API_URL}/accounts/${account.id}`);
          await this.fetchAccounts();
        } catch (error) {
          console.error('Error deleting account:', error);
          alert('Failed to delete account');
        }
      }
    },
    getAccountIcon(type) {
        const map = {
            'Bank': 'account_balance',
            'E-Wallet': 'account_balance_wallet',
            'Cash': 'payments',
            'Card': 'credit_card',
            'Other': 'folder'
        };
        return map[type] || 'folder';
    }
  }
};
</script>

<style scoped>
/* Scoped styles are removed as we use Tailwind CSS globally for this design */
</style>
