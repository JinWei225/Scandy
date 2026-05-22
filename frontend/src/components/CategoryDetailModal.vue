<template>
  <BaseModal @close="$emit('close')" :title="categoryName">
    <div v-if="transactions.length > 0" class="flex flex-col border-t border-outline-variant/20">
      <div v-for="transaction in transactions" :key="transaction.id" class="group grid grid-cols-1 md:grid-cols-12 gap-2 md:gap-4 py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container opacity-0 group-hover:opacity-100 transition-opacity"></div>
        <div class="col-span-1 md:col-span-2 flex flex-col md:block">
          <div class="font-body text-sm text-on-surface font-mono">{{ transaction.date }}</div>
          <div class="font-label text-[10px] text-on-surface-variant tracking-widest">{{ transaction.time }}</div>
        </div>
        <div class="col-span-1 md:col-span-4">
          <div class="font-headline text-md text-on-surface tracking-tight">{{ transaction.description }}</div>
        </div>
        <div class="col-span-1 md:col-span-4 flex md:justify-end items-center">
          <span class="font-headline text-lg tracking-tighter" :class="transaction.type === 'expense' ? 'text-error' : (transaction.type === 'transfer' ? 'text-on-surface' : 'text-primary-container')">{{ transaction.amount }}</span>
        </div>
        <div class="col-span-1 md:col-span-2 flex justify-end gap-2 mt-2 md:mt-0 transition-opacity">
          <button @click="$emit('edit', transaction)" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center p-1"><span class="material-symbols-outlined text-[18px]">edit</span></button>
          <button @click="$emit('delete', transaction.id)" class="text-on-surface-variant hover:text-error transition-colors flex items-center justify-center p-1"><span class="material-symbols-outlined text-[18px]">delete</span></button>
        </div>
      </div>
    </div>
    <div v-else class="py-12 text-center border-b border-outline-variant/20">
      <p class="font-body text-on-surface-variant">No transactions found for this category.</p>
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
/* Removed old CSS, replaced with Tailwind classes */
</style>