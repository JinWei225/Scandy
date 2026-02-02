<!-- src/components/CategoryDetailModal.vue -->

<template>
  <BaseModal @close="$emit('close')" :title="categoryName">
    <ul v-if="transactions.length > 0" class="transactions-list-modal">
      <li v-for="transaction in transactions" :key="transaction.id">
        <div class="transaction-details">
          <div class="date-time-group">
            <span class="date-modal">{{ transaction.date }}</span>
            <span class="time-modal">{{ transaction.time }}</span>
          </div>
          <span class="description-modal" :title="transaction.description">{{ transaction.description }}</span>
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
  flex-grow: 1;
  display: flex;
  align-items: center;
  gap: 1rem;
  overflow: hidden;
  margin-right: 0.5rem;
}

.date-time-group {
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  min-width: 80px;
}

.date-modal {
  color: var(--subtle-text-color);
  font-size: 0.8rem;
}

.time-modal {
  color: var(--primary-color);
  font-size: 0.75rem;
  font-weight: 600;
  font-family: 'JetBrains Mono', 'Courier New', monospace;
  opacity: 0.8;
}

.description-modal {
  flex-grow: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 0.95rem;
  min-width: 0; /* Allow shrinking */
}

.amount-modal {
  flex-shrink: 0;
  text-align: right;
  font-weight: bold;
  white-space: nowrap;
  color: var(--text-color);
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
@media (max-width: 600px) {
  .transactions-list-modal li {
    padding: 1rem 0;
  }
  
  .transaction-details {
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .date-time-group {
    flex-direction: row;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    margin-bottom: -0.25rem;
  }

  .description-modal {
    flex-basis: 60%;
    font-size: 0.9rem;
  }
  
  .amount-modal {
    flex-basis: 30%;
    flex-grow: 1;
    font-size: 1rem;
  }

  .action-buttons-modal {
    margin-left: 0.5rem;
  }
  
  .edit-btn, .delete-btn {
    width: 36px;
    height: 36px;
  }
}
</style>