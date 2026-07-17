import { ref } from 'vue';
import { useTransactions } from './useTransactions';

// Shared edit / confirm-delete / category-detail modal plumbing used by the
// Home, Summary, Account and Search views.
export function useTransactionModals({ afterChange } = {}) {
  const { updateTransaction, deleteTransaction } = useTransactions();

  const isEditModalVisible = ref(false);
  const transactionToEdit = ref(null);
  const isDetailModalVisible = ref(false);
  const selectedCategoryData = ref({ name: '', transactions: [] });
  const isConfirmDeleteVisible = ref(false);
  const pendingDeleteId = ref(null);

  const openEditModal = (transaction) => {
    transactionToEdit.value = transaction;
    isEditModalVisible.value = true;
  };

  const handleSaveTransaction = async (updatedTransaction) => {
    try {
      await updateTransaction(updatedTransaction);
      isEditModalVisible.value = false;
      isDetailModalVisible.value = false;
      if (afterChange) await afterChange();
    } catch (error) {
      console.error('Error updating transaction:', error);
      alert('Failed to update transaction.');
    }
  };

  const requestDelete = (transactionId) => {
    pendingDeleteId.value = transactionId;
    isConfirmDeleteVisible.value = true;
  };

  const confirmDelete = async () => {
    isConfirmDeleteVisible.value = false;
    try {
      if (pendingDeleteId.value) {
        await deleteTransaction(pendingDeleteId.value);
      }
      isDetailModalVisible.value = false;
      if (afterChange) await afterChange();
    } finally {
      pendingDeleteId.value = null;
    }
  };

  const cancelDelete = () => {
    isConfirmDeleteVisible.value = false;
    pendingDeleteId.value = null;
  };

  const openDetailModal = (categoryName, type, transactions) => {
    selectedCategoryData.value = {
      name: categoryName,
      transactions: transactions.filter(tx =>
        (tx.category || (type === 'income' ? 'Other' : 'Uncategorized')) === categoryName &&
        (type === 'income' ? tx.type === 'income' : (tx.type === 'expense' || !tx.type))
      )
    };
    isDetailModalVisible.value = true;
  };

  return {
    isEditModalVisible,
    transactionToEdit,
    isDetailModalVisible,
    selectedCategoryData,
    isConfirmDeleteVisible,
    openEditModal,
    handleSaveTransaction,
    requestDelete,
    confirmDelete,
    cancelDelete,
    openDetailModal
  };
}
