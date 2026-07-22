<template>
  <BaseModal size="md" title="Transaction" @close="$emit('close')">
    <!-- Read-only counterpart to TransactionFormModal: same fields, same
         order, no inputs. Rows are label/value pairs so the modal stays
         legible on a phone without a two-column grid. -->
    <div class="flex flex-col">
      <div class="flex items-center gap-3 pb-4 border-b border-outline-variant/20">
        <span class="px-2 py-0.5 border font-label text-[10px] uppercase tracking-widest" :class="typeClass">{{ transaction.type || 'expense' }}</span>
        <span class="font-headline text-2xl tracking-tighter ml-auto" :class="amountClass">{{ transaction.amount }}</span>
      </div>

      <dl class="flex flex-col">
        <div v-for="field in fields" :key="field.label" class="flex items-baseline justify-between gap-4 py-2.5 border-b border-outline-variant/20">
          <dt class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest shrink-0">{{ field.label }}</dt>
          <dd class="font-body text-sm text-on-surface text-right break-words min-w-0">{{ field.value }}</dd>
        </div>
      </dl>

      <div class="flex justify-end mt-6">
        <button type="button" class="border border-outline text-on-surface px-6 py-2 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors" @click="$emit('close')">Close</button>
      </div>
    </div>
  </BaseModal>
</template>

<script>
import BaseModal from './BaseModal.vue'

export default {
  name: 'TransactionDetailModal',
  components: { BaseModal },
  props: {
    transaction: { type: Object, required: true },
    // Rows store account ids; names come from the caller's accounts list.
    accounts: { type: Array, default: () => [] }
  },
  emits: ['close'],
  computed: {
    isTransfer() {
      return this.transaction.type === 'transfer' || !!this.transaction.transfer_related_id
    },
    typeClass() {
      if (this.transaction.type === 'expense') return 'border-error text-error bg-error/10'
      return this.isTransfer ? 'border-tertiary text-tertiary bg-tertiary/10' : 'border-primary-container text-primary-container bg-primary-container/10'
    },
    amountClass() {
      if (this.transaction.type === 'expense') return 'text-error'
      return this.isTransfer ? 'text-on-surface' : 'text-primary-container'
    },
    fields() {
      const tx = this.transaction
      const rows = [
        { label: 'Description', value: tx.description || '—' },
        { label: 'Date', value: tx.date || '—' },
        { label: 'Time', value: tx.time || '—' }
      ]

      if (this.isTransfer) {
        rows.push({ label: 'From Account', value: this.accountName(tx.from_account_id ?? tx.account_id) })
        rows.push({ label: 'To Account', value: this.accountName(tx.to_account_id) })
      } else {
        rows.push({ label: 'Account', value: this.accountName(tx.account_id) })
        rows.push({ label: 'Category', value: tx.category || 'Uncategorized' })
      }

      return rows
    }
  },
  methods: {
    accountName(id) {
      if (id === null || id === undefined) return 'Unassigned'
      const account = this.accounts.find(acc => String(acc.id) === String(id))
      return account ? account.name : 'Unassigned'
    }
  }
}
</script>
