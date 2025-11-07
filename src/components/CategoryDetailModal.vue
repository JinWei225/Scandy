<!-- src/components/CategoryDetailModal.vue -->

<template>
  <BaseModal @close="$emit('close')" :title="categoryName">
    <ul v-if="transactions.length > 0" class="transactions-list-modal">
      <li v-for="transaction in transactions" :key="transaction.id">
        <div class="transaction-details">
          <span class="date-modal">{{ transaction.date }}</span>
          <span class="description-modal">{{ transaction.description }}</span>
          <span class="amount-modal">{{ transaction.amount }}</span>
        </div>
        <div class="action-buttons-modal">
          <button @click="$emit('edit', transaction)" class="edit-btn" aria-label="Edit Transaction">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>
          </button>
          <button @click="$emit('delete', transaction.id)" class="delete-btn">&times;</button>
        </div>
      </li>
    </ul>
    <div v-else class="no-transactions-modal">
      <p>No transactions found for this category.</p>
    </div>
  </BaseModal>
</template>

<script>
import BaseModal from './BaseModal.vue';

export default {
  name: 'CategoryDetailModal',
  components: { BaseModal },
  props: {
    categoryName: {
      type: String,
      required: true
    },
    transactions: {
      type: Array,
      required: true
    }
  },
  emits: ['close', 'edit', 'delete']
}
</script>

<style scoped>
/* --- TRANSACTION LIST STYLES (THE FIX IS HERE) --- */
.transactions-list-modal {
  list-style: none; padding: 0; margin: 0;
}

/* MODIFIED: The main <li> is the master flex container */
.transactions-list-modal li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 0.25rem;
  border-bottom: 1px solid var(--border-color);
}
.transactions-list-modal li:last-child {
  border-bottom: none;
}

/* MODIFIED: This wrapper is now ALSO a flex container */
.transaction-details {
  flex-grow: 1; /* CRITICAL: This makes it take up all available horizontal space */
  display: flex;
  align-items: center;
  overflow: hidden; /* Prevents long descriptions from breaking the layout */
  margin-right: 1rem; /* Ensures space between text and buttons */
}

/* MODIFIED: Use flex-basis to distribute space WITHIN the details wrapper */
.date-modal {
  flex-basis: 25%;
  flex-shrink: 0; /* Prevents date from shrinking */
  color: var(--subtle-text-color);
  font-size: 0.9rem;
}
.description-modal {
  flex-basis: 50%;
  white-space: nowrap; /* Prevents wrapping */
  overflow: hidden; /* Hides overflow */
  text-overflow: ellipsis; /* Adds "..." if description is too long */
  padding: 0 1rem; /* Add some spacing */
}
.amount-modal {
  flex-basis: 25%;
  flex-shrink: 0; /* Prevents amount from shrinking */
  text-align: right;
  font-weight: bold;
}

/* ACTION BUTTONS (UNCHANGED BUT INCLUDED FOR COMPLETENESS) */
.action-buttons-modal {
  display: flex;
  gap: 0.5rem;
}
.edit-btn, .delete-btn {
  border: none; border-radius: 50%; width: 32px; height: 32px; /* Slightly larger */
  cursor: pointer; display: flex; justify-content: center;
  align-items: center; transition: background-color 0.2s; color: white;
  flex-shrink: 0; /* Prevents buttons from shrinking */
}
.edit-btn { background-color: var(--primary-color); }
.edit-btn:hover { background-color: var(--secondary-color); }
.delete-btn {
  background-color: #ef4444; font-size: 1.4rem; /* Slightly larger */
  font-weight: bold; line-height: 1;
  margin-top: 0;
}
.delete-btn:hover { background-color: #dc2626; }

/* OPTIONAL: Media query for better mobile layout */
@media (max-width: 500px) {
  .description-modal {
    flex-basis: 40%; /* Give less space to description on small screens */
  }
  .amount-modal {
    flex-basis: 35%;
  }
}
</style>