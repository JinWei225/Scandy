<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-content">
      <h2>Confirm Transaction Details</h2>
      
      <!-- We use v-if to prevent errors before data is ready -->
      <form v-if="formData" @submit.prevent="saveTransaction">
        <div class="form-group">
          <label for="confirm-date">Date</label>
          <input type="date" id="confirm-date" v-model="formData.date" required>
        </div>
        
        <div class="form-group">
          <label for="confirm-description">Description</label>
          <input type="text" id="confirm-description" v-model="formData.description" placeholder="e.g., Lunch with team" required>
        </div>

        <div class="form-group">
          <label for="confirm-category">Category</label>
          <select id="confirm-category" v-model="formData.category" required>
            <option v-for="category in categories" :key="category" :value="category">
              {{ category }}
            </option>
          </select>
        </div>
        
        <div class="form-group">
          <label for="confirm-amount">Amount (RM)</label>
          <input type="number" id="confirm-amount" v-model="formData.amount" step="0.01" required>
        </div>
        
        <div class="form-group">
            <label for="confirm-account">Account</label>
            <select id="confirm-account" v-model="formData.account_id">
                <option :value="null">Unassigned</option>
                <option v-for="acc in accounts" :key="acc.id" :value="acc.id">{{ acc.name }}</option>
            </select>
        </div>

        <div class="form-group mb-4">
            <label class="block font-semibold mb-2">Transaction Type</label>
            <div class="type-selector">
                <div 
                    class="type-option expense" 
                    :class="{ active: formData.type === 'expense' }"
                    @click="formData.type = 'expense'"
                >
                    Expense
                </div>
                <div 
                    class="type-option income" 
                    :class="{ active: formData.type === 'income' }"
                    @click="formData.type = 'income'"
                >
                    Income
                </div>
            </div>
        </div>
        
        <div class="modal-actions">
          <button type="button" class="cancel-btn" @click="$emit('close')">Cancel</button>
          <button type="submit" class="save-btn">Save Transaction</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
export default {
  name: 'ConfirmationModal',
  props: {
    scannedData: {
      type: Object,
      required: true,
    },
    categories: {
      type: Array,
      required: true,
    },
    accounts: {
      type: Array,
      required: false,
      default: () => []
    }
  },
  data() {
    return {
      formData: null,
    };
  },
  watch: {
    scannedData: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.formData = {
            date: newVal.date,
            amount: newVal.amount,
            category: newVal.category,
            description: '',
            account_id: null,
            type: 'expense'
          };
        }
      }
    }
  },
  methods: {
    saveTransaction() {
      // The backend needs DD/MM/YYYY format for the date
      const dateParts = this.formData.date.split('-'); // from YYYY-MM-DD
      const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;

      // Create the final object to send back to the parent
      const payload = {
        date: formattedDate,
        description: this.formData.description,
        category: this.formData.category,
        amount: this.formData.amount,
        account_id: this.formData.account_id,
        type: this.formData.type
      };

      this.$emit('save', payload);
    }
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed; top: 0; left: 0; width: 100%; height: 100%;
  background-color: rgba(0, 0, 0, 0.6); display: flex;
  justify-content: center; align-items: center; z-index: 1000;
}
.modal-content {
  background-color: var(--card-background); color: var(--text-color);
  padding: 2rem; border-radius: 8px; width: 90%; max-width: 500px;
  box-shadow: 0 5px 15px rgba(0,0,0,0.3);
}
.modal-content h2 { margin-top: 0; color: var(--primary-color); }
.form-group { margin-bottom: 1rem; text-align: left; }
.form-group label { display: block; font-weight: bold; margin-bottom: 0.5rem; }
.form-group input, .form-group select {
  width: 100%; padding: 0.75rem; border: 1px solid var(--border-color);
  border-radius: 5px; font-size: 1rem; box-sizing: border-box;
  background-color: var(--card-background); color: var(--text-color);
}
.form-group input:focus, .form-group select:focus {
  outline: none; border-color: var(--secondary-color);
  box-shadow: 0 0 0 2px rgba(74, 122, 156, 0.3);
}
.modal-actions { display: flex; justify-content: flex-end; gap: 1rem; margin-top: 2rem; }
.modal-actions button {
  padding: 0.75rem 1.5rem; border-radius: 5px; font-size: 1rem;
  font-weight: bold; cursor: pointer; border: none; transition: background-color 0.2s;
}
.save-btn { background-color: var(--primary-color); color: white; }
.save-btn:hover { background-color: var(--secondary-color); }
.cancel-btn { background-color: var(--border-color); color: var(--text-color); }
.cancel-btn:hover { background-color: #d1d5db; }

.type-selector {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
    margin-top: 0.5rem;
}

.type-option {
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    border: 2px solid transparent;
    transition: all 0.2s ease;
    flex: 1;
    text-align: center;
    background-color: rgba(255, 255, 255, 0.5);
    color: var(--text-color);
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.type-option:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 6px rgba(0,0,0,0.05);
}

/* Expense Styles */
.type-option.expense {
    border-color: rgba(239, 68, 68, 0.2);
    color: var(--negative-color);
}
.type-option.expense.active {
    background-color: var(--negative-color);
    color: white;
    border-color: var(--negative-color);
}

/* Income Styles */
.type-option.income {
    border-color: rgba(34, 197, 94, 0.2);
    color: var(--positive-color);
}
.type-option.income.active {
    background-color: var(--positive-color);
    color: white;
    border-color: var(--positive-color);
}

/* Dark Mode */
html.dark .type-option {
    background-color: rgba(30, 41, 59, 0.4);
}
html.dark .type-option:hover {
    background-color: rgba(30, 41, 59, 0.6);
}
</style>