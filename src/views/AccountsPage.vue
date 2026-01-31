<template>
  <div class="container">
    <div class="page-header">
      <h1>Accounts</h1>
      <button @click="openAddModal" class="add-btn" title="Add Account">
        +
      </button>
    </div>

    <!-- Total Balance Card -->
    <div class="total-balance-card">
      <h2 class="total-balance-title">Total Balance</h2>
      <p class="total-balance-amount">RM {{ totalBalance.toFixed(2) }}</p>
    </div>

    <!-- Accounts Grid -->
    <div class="accounts-grid">
      <div v-for="account in accounts" :key="account.id" class="account-card" @click="viewAccount(account.name)">
        <div class="account-header">
            <div class="account-icon" :class="getAccountColorClass(account.type)">
                {{ getAccountInitials(account.type) }}
            </div>
          <div class="account-details">
            <h3 class="account-name">{{ account.name }}</h3>
            <span class="account-type">{{ account.type || 'Account' }}</span>
          </div>
        </div>
        
        <div class="account-body">
            <p class="account-balance">RM {{ (account.balance || 0).toFixed(2) }}</p>
        </div>
        
        <!-- Actions -->
        <div class="account-actions">
          <button @click.stop="editAccount(account)" class="icon-btn edit" title="Edit">✎</button>
          <button @click.stop="confirmDelete(account)" class="icon-btn delete" title="Delete">🗑</button>
        </div>
      </div>
      
      <!-- Empty State -->
      <div v-if="accounts.length === 0" class="empty-state">
        <p>No accounts found. Add one to get started.</p>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal-content">
        <h2>{{ isEditing ? 'Edit Account' : 'New Account' }}</h2>
        
        <form @submit.prevent="saveAccount">
          <div class="form-group">
            <label>Account Name</label>
            <input v-model="form.name" type="text" required placeholder="e.g. Maybank, GrabPay">
          </div>
          
          <div class="form-group">
            <label>Type</label>
            <select v-model="form.type">
              <option value="Bank">Bank Account</option>
              <option value="E-Wallet">E-Wallet</option>
              <option value="Cash">Cash</option>
              <option value="Card">Card</option>
              <option value="Other">Other</option>
            </select>
          </div>
          
          <div class="form-group">
            <label>Initial Balance</label>
            <input v-model.number="form.initial_balance" type="number" step="0.01">
            <p class="help-text">Starting balance before any transactions.</p>
          </div>
          
          <div class="modal-actions">
            <button type="button" @click="showModal = false" class="cancel-btn">Cancel</button>
            <button type="submit" class="save-btn">{{ isEditing ? 'Save Changes' : 'Create Account' }}</button>
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
    getAccountInitials(type) {
        if (!type) return 'A';
        return type.substring(0, 1).toUpperCase();
    },
    getAccountColorClass(type) {
        const map = {
            'Bank': 'bg-blue',
            'E-Wallet': 'bg-purple',
            'Cash': 'bg-green',
            'Card': 'bg-orange',
            'Other': 'bg-gray'
        };
        return map[type] || 'bg-gray';
    }
  }
};
</script>

<style scoped>
.container {
  max-width: 900px;
  margin: 0 auto;
  padding: 2rem;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.page-header h1 {
  font-size: 2rem;
  font-weight: 800;
  color: var(--text-color);
  margin: 0;
}

.add-btn {
  background: var(--primary-color);
  color: white;
  border: none;
  width: 48px;
  height: 48px;
  border-radius: 50%;
  font-size: 1.5rem;
  cursor: pointer;
  box-shadow: 0 4px 6px rgba(79, 70, 229, 0.4);
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.add-btn:hover {
  transform: scale(1.1);
  background: var(--secondary-color);
}

/* Total Balance Card */
.total-balance-card {
  background: linear-gradient(to right, var(--primary-color), var(--secondary-color));
  color: white;
  padding: 2rem;
  border-radius: 16px;
  margin-bottom: 2rem;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

.total-balance-title {
  font-size: 1.125rem;
  font-weight: 500;
  opacity: 0.9;
  margin: 0 0 0.5rem 0;
}

.total-balance-amount {
  font-size: 2.25rem;
  font-weight: 800;
  margin: 0;
}

/* Accounts Grid */
.accounts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
}

.account-card {
  background: var(--card-background);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: var(--glass-border);
  border-radius: 16px;
  padding: 1.5rem;
  box-shadow: var(--glass-shadow);
  transition: transform 0.2s, box-shadow 0.2s;
  display: flex;
  flex-direction: column;
  cursor: pointer;
}

.account-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 24px -8px rgba(0, 0, 0, 0.15);
}

.account-header {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1rem;
}

.account-icon {
    width: 48px;
    height: 48px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-weight: 700;
    font-size: 1.25rem;
}

.bg-blue { background: linear-gradient(135deg, #3b82f6, #2563eb); }
.bg-purple { background: linear-gradient(135deg, #8b5cf6, #7c3aed); }
.bg-green { background: linear-gradient(135deg, #10b981, #059669); }
.bg-orange { background: linear-gradient(135deg, #f59e0b, #d97706); }
.bg-gray { background: linear-gradient(135deg, #6b7280, #4b5563); }

.account-details {
    flex-grow: 1;
}

.account-name {
    margin: 0;
    font-size: 1.1rem;
    color: var(--text-color);
}

.account-type {
    font-size: 0.85rem;
    color: var(--subtle-text-color);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    font-weight: 600;
}

.account-body {
    margin-bottom: 1.5rem;
    text-align: right;
}

.account-balance {
    font-size: 1.75rem;
    font-weight: 800;
    color: var(--text-color);
    margin: 0;
    letter-spacing: -0.02em;
}

.account-actions {
    margin-top: auto; /* Pushes actions to bottom */
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    border-top: 1px solid var(--border-color);
    padding-top: 1rem;
}

.empty-state {
    grid-column: 1 / -1;
    text-align: center;
    padding: 3rem;
    color: var(--subtle-text-color);
    font-size: 1.1rem;
    background: rgba(255,255,255,0.1);
    border-radius: 12px;
    border: 1px dashed var(--border-color);
}

/* Modal Styles */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 100;
}

.modal-content {
  background-color: var(--card-background);
  color: var(--text-color);
  padding: 2rem;
  border-radius: 16px;
  width: 90%;
  max-width: 450px;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  animation: modal-pop 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

@keyframes modal-pop {
    from { transform: scale(0.9); opacity: 0; }
    to { transform: scale(1); opacity: 1; }
}

.modal-content h2 {
    margin-top: 0;
    margin-bottom: 1.5rem;
    color: var(--primary-color);
    font-size: 1.5rem;
}

.form-group {
    margin-bottom: 1.25rem;
}

.form-group label {
    display: block;
    font-weight: 600;
    margin-bottom: 0.5rem;
    color: var(--text-color);
    font-size: 0.9rem;
}

.form-group input, .form-group select {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    font-size: 1rem;
    background: rgba(255, 255, 255, 0.5);
    color: var(--text-color);
    box-sizing: border-box;
    transition: all 0.2s;
}

.form-group input:focus, .form-group select:focus {
    outline: none;
    border-color: var(--primary-color);
    box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
    background: white;
}

html.dark .form-group input, 
html.dark .form-group select {
    background: rgba(30, 41, 59, 0.5);
    color: white;
}

html.dark .form-group input:focus, 
html.dark .form-group select:focus {
    background: rgba(30, 41, 59, 0.8);
}

.help-text {
    font-size: 0.8rem;
    color: var(--subtle-text-color);
    margin-top: 0.25rem;
    margin-bottom: 0;
}

.modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
    margin-top: 2rem;
}

.cancel-btn {
    padding: 0.75rem 1.5rem;
    background: transparent;
    border: 1px solid var(--border-color);
    color: var(--text-color);
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
}

.cancel-btn:hover {
    background: rgba(0,0,0,0.05);
}

.save-btn {
    padding: 0.75rem 1.5rem;
    background: var(--primary-color);
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 4px 6px rgba(79, 70, 229, 0.2);
}

.save-btn:hover {
    background: var(--secondary-color);
    transform: translateY(-1px);
    box-shadow: 0 6px 8px rgba(79, 70, 229, 0.25);
}
</style>
