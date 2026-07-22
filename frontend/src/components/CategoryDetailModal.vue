<template>
  <BaseModal @close="$emit('close')" :title="categoryName">
    <div v-if="transactions.length > 0" class="flex flex-col border-t border-outline-variant/20">
      <TransactionRow
        v-for="transaction in transactions"
        :key="transaction.id"
        :transaction="transaction"
        :showCategory="false"
        @select="tx => $emit('select', tx)"
        @edit="tx => $emit('edit', tx)"
        @delete="id => $emit('delete', id)"
      />
    </div>
    <div v-else class="py-10 text-center border-b border-outline-variant/20">
      <p class="font-body text-on-surface-variant">No transactions found for this category.</p>
    </div>
  </BaseModal>
</template>

<script>
import BaseModal from './BaseModal.vue';
import TransactionRow from './TransactionRow.vue';

export default {
  name: 'CategoryDetailModal',
  components: { BaseModal, TransactionRow },
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
  emits: ['close', 'select', 'edit', 'delete']
}
</script>

<style scoped>
/* Removed old CSS, replaced with Tailwind classes */
</style>