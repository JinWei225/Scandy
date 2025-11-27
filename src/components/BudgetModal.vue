<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-content">
      <h2>Set Monthly Budget</h2>
      <form @submit.prevent="saveBudget">
        <div class="form-group">
          <label for="budget-amount">Amount (RM)</label>
          <input 
            type="number" 
            id="budget-amount" 
            v-model="budgetAmount" 
            step="0.01" 
            placeholder="Enter budget amount"
            required
            ref="budgetInput"
          >
        </div>
        <div class="modal-actions">
          <button type="button" class="cancel-btn" @click="$emit('close')">Cancel</button>
          <button type="submit" class="save-btn">Save</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue';

export default {
  name: 'BudgetModal',
  props: {
    initialAmount: {
      type: Number,
      default: null
    }
  },
  emits: ['save', 'close'],
  setup(props, { emit }) {
    const budgetAmount = ref(props.initialAmount);
    const budgetInput = ref(null);

    const saveBudget = () => {
      if (budgetAmount.value === null || budgetAmount.value === '' || isNaN(budgetAmount.value)) {
        alert('Please enter a valid number for the budget.');
        return;
      }
      emit('save', parseFloat(budgetAmount.value));
    };

    onMounted(() => {
      if (budgetInput.value) {
        budgetInput.value.focus();
      }
    });

    return {
      budgetAmount,
      saveBudget,
      budgetInput
    };
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.6);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}
.modal-content {
  background-color: var(--card-background);
  color: var(--text-color);
  padding: 2rem;
  border-radius: 8px;
  width: 90%;
  max-width: 400px;
  box-shadow: 0 5px 15px rgba(0,0,0,0.3);
}

.modal-content h2 {
  margin-top: 0;
  color: var(--primary-color);
  margin-bottom: 1.5rem;
}

.form-group { margin-bottom: 1.5rem; text-align: left; }
.form-group label { display: block; font-weight: bold; margin-bottom: 0.5rem; }
.form-group input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 5px;
  font-size: 1.1rem;
  box-sizing: border-box;
  background-color: var(--card-background);
  color: var(--text-color);
}

.form-group input:focus {
  outline: none;
  border-color: var(--secondary-color);
  box-shadow: 0 0 0 2px rgba(74, 122, 156, 0.3);
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
}

.modal-actions button {
  padding: 0.75rem 1.5rem;
  border-radius: 5px;
  font-size: 1rem;
  font-weight: bold;
  cursor: pointer;
  border: none;
  transition: background-color 0.2s;
}

.save-btn { background-color: var(--primary-color); color: white; }
.save-btn:hover { background-color: var(--secondary-color); }
.cancel-btn { background-color: var(--border-color); color: var(--text-color); }
.cancel-btn:hover { background-color: #d1d5db; }
</style>
