<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-content search-modal">
      <div class="modal-header">
        <h2>Search Transactions</h2>
        <button class="close-btn" @click="$emit('close')">&times;</button>
      </div>

      <div class="search-input-wrapper">
        <input 
          type="text" 
          v-model="searchQuery" 
          placeholder="Search by description, category, amount..." 
          class="search-input"
          ref="searchInput"
        />
      </div>

      <div class="results-list" v-if="filteredTransactions.length > 0">
        <ul>
          <li v-for="transaction in filteredTransactions" :key="transaction.id">
            <div class="transaction-info">
              <div class="details">
                <span class="date">{{ transaction.date }}</span>
                <span class="description">{{ transaction.description }}</span>
                <span class="category-pill">{{ transaction.category }}</span>
              </div>
              <div class="amount">
                {{ transaction.amount }}
              </div>
            </div>
            <div class="action-buttons">
              <button @click="openEditModal(transaction)" class="icon-btn edit" title="Edit">✎</button>
              <button @click="deleteTransaction(transaction.id)" class="icon-btn delete" title="Delete">🗑</button>
            </div>
          </li>
        </ul>
      </div>
      <div v-else-if="searchQuery" class="no-results">
        No transactions found matching "{{ searchQuery }}"
      </div>
      <div v-else class="no-results">
        Type to search...
      </div>
    </div>
  </div>
  
  <EditModal 
    v-if="isEditModalVisible" 
    :transaction="transactionToEdit"
    :categories="categories"
    @close="isEditModalVisible = false"
    @save="handleSaveTransaction"
  />
</template>

<script>
import { ref, computed, onMounted, nextTick } from 'vue';
import { useTransactions } from '../composables/useTransactions';
import EditModal from './EditModal.vue';

export default {
  name: 'SearchModal',
  components: { EditModal },
  emits: ['close'],
  setup() {
    const { transactions, categories, deleteTransaction, updateTransaction } = useTransactions();
    const searchQuery = ref('');
    const searchInput = ref(null);
    
    // Edit Modal State
    const isEditModalVisible = ref(false);
    const transactionToEdit = ref(null);

    onMounted(() => {
      nextTick(() => {
        searchInput.value?.focus();
      });
    });

    const filteredTransactions = computed(() => {
      if (!searchQuery.value) return [];
      const query = searchQuery.value.toLowerCase();
      return transactions.value.filter(tx => {
        return (
          tx.description.toLowerCase().includes(query) ||
          tx.category.toLowerCase().includes(query) ||
          tx.amount.toString().toLowerCase().includes(query) ||
          tx.date.includes(query)
        );
      });
    });

    const openEditModal = (transaction) => {
      transactionToEdit.value = { ...transaction };
      isEditModalVisible.value = true;
    };

    const handleSaveTransaction = async (updatedData) => {
      await updateTransaction(updatedData);
      isEditModalVisible.value = false;
    };

    return {
      searchQuery,
      searchInput,
      filteredTransactions,
      deleteTransaction,
      categories,
      isEditModalVisible,
      transactionToEdit,
      openEditModal,
      handleSaveTransaction
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
  background-color: rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding-top: 4rem;
  z-index: 1000;
}

.modal-content.search-modal {
  background-color: var(--card-background);
  padding: 1.5rem;
  border-radius: 20px;
  width: 90%;
  max-width: 600px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.5rem;
  color: var(--text-color);
}

.close-btn {
  background: none;
  border: none;
  font-size: 2rem;
  cursor: pointer;
  color: var(--subtle-text-color);
  line-height: 1;
}

.search-input-wrapper {
  margin-bottom: 1.5rem;
}

.search-input {
  width: 100%;
  padding: 1rem;
  border: 2px solid var(--border-color);
  border-radius: 12px;
  font-size: 1.1rem;
  background-color: rgba(255, 255, 255, 0.5);
  transition: all 0.2s;
  box-sizing: border-box;
}

.search-input:focus {
  outline: none;
  border-color: var(--primary-color);
  background-color: white;
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
}

.results-list {
  overflow-y: auto;
  flex-grow: 1;
  padding-right: 0.5rem;
}

.results-list ul {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.results-list li {
  background: rgba(255, 255, 255, 0.4);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  transition: all 0.2s;
}

.results-list li:hover {
  background: rgba(255, 255, 255, 0.8);
  transform: translateY(-2px);
  box-shadow: 0 4px 6px rgba(0,0,0,0.05);
}

.transaction-info {
  display: flex;
  align-items: center;
  gap: 1rem;
  flex-grow: 1;
}

.details {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.date {
  font-size: 0.85rem;
  color: var(--subtle-text-color);
}

.description {
  font-weight: 600;
  color: var(--text-color);
}

.category-pill {
  display: inline-block;
  background-color: var(--secondary-color);
  color: white;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 600;
  align-self: flex-start;
}

.amount {
  font-weight: 700;
  font-size: 1.1rem;
  color: var(--primary-color);
  margin-left: auto;
  margin-right: 1rem;
  white-space: nowrap;
}

.action-buttons {
  display: flex;
  gap: 0.5rem;
}

.no-results {
  text-align: center;
  color: var(--subtle-text-color);
  padding: 2rem;
  font-style: italic;
}

/* Dark Mode Support */
:global(html.dark) .modal-content.search-modal {
  background-color: rgba(30, 41, 59, 0.95);
  border-color: rgba(255, 255, 255, 0.1);
}

:global(html.dark) .search-input {
  background-color: rgba(15, 23, 42, 0.5);
  border-color: rgba(255, 255, 255, 0.1);
  color: white;
}

:global(html.dark) .search-input:focus {
  background-color: rgba(15, 23, 42, 0.8);
}

:global(html.dark) .results-list li {
  background: rgba(255, 255, 255, 0.05);
  border-color: rgba(255, 255, 255, 0.1);
}

:global(html.dark) .results-list li:hover {
  background: rgba(255, 255, 255, 0.1);
}

@media (max-width: 600px) {
  .transaction-info {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }
  
  .amount {
    margin-left: 0;
  }
  
  .results-list li {
    align-items: flex-start;
  }
  
  .action-buttons {
    flex-direction: column;
  }
}
</style>
