<template>
  <!--
    One DOM for both layouts. On a phone this is a 2x2 grid — description and
    amount on the first line, date/time/category and the actions on the second
    — which keeps a row to two lines instead of five. From `md` the meta
    wrapper becomes `display: contents`, so its children drop into the
    12-column grid alongside their siblings and `md:order-*` puts them back in
    table order (date, description, category, amount, actions).

    Description and amount are deliberately one step larger than the
    surrounding metadata — they are what you scan a ledger for.
  -->
  <div
    role="button"
    tabindex="0"
    @click="$emit('select', transaction)"
    @keydown.enter="$emit('select', transaction)"
    @keydown.space.prevent="$emit('select', transaction)"
    class="group grid grid-cols-[1fr_auto] items-center gap-x-3 gap-y-1 py-2.5 px-3 md:grid-cols-12 md:gap-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors relative cursor-pointer">
    <div class="absolute left-0 top-0 bottom-0 w-[2px] opacity-0 group-hover:opacity-100 transition-opacity" :class="accentClass"></div>

    <!-- Absorbs the category column when it's hidden, so the desktop grid still
         totals 12 and amount/actions stay under their headers. -->
    <div class="min-w-0 md:order-2" :class="showCategory ? 'md:col-span-4' : 'md:col-span-6'">
      <div class="font-headline text-base md:text-lg text-on-surface tracking-tight truncate">{{ transaction.description }}</div>
    </div>

    <div class="text-right md:col-span-2 md:order-4">
      <span class="font-headline text-base md:text-lg tracking-tighter whitespace-nowrap" :class="amountClass">{{ transaction.amount }}</span>
    </div>

    <div class="flex items-center gap-2 min-w-0 md:contents">
      <div class="flex items-baseline gap-1.5 md:block md:col-span-2 md:order-1 shrink-0">
        <span class="font-body text-[11px] md:text-sm text-on-surface-variant md:text-on-surface font-mono">{{ transaction.date }}</span>
        <span class="font-label text-[10px] text-on-surface-variant tracking-widest">{{ transaction.time }}</span>
      </div>

      <span v-if="showCategory && transaction.category" class="px-1.5 py-0.5 bg-surface-container-high border border-outline-variant/20 font-label text-[10px] text-on-surface uppercase tracking-widest truncate md:col-span-2 md:order-3 md:justify-self-start">{{ transaction.category }}</span>
    </div>

    <!-- Stops the row's own click: the buttons are actions on the row, not a
         way into the detail view. -->
    <div class="flex justify-end gap-1 md:col-span-2 md:order-5" @click.stop>
      <button @click="$emit('edit', transaction)" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center p-1">
        <span class="material-symbols-outlined text-[16px] md:text-[18px]">edit</span>
      </button>
      <button @click="$emit('delete', transaction.id)" class="text-on-surface-variant hover:text-error transition-colors flex items-center justify-center p-1">
        <span class="material-symbols-outlined text-[16px] md:text-[18px]">delete</span>
      </button>
    </div>
  </div>
</template>

<script>
export default {
  name: 'TransactionRow',
  props: {
    transaction: { type: Object, required: true },
    // CategoryDetailModal lists a single category, so the chip is noise there.
    showCategory: { type: Boolean, default: true }
  },
  emits: ['edit', 'delete', 'select'],
  computed: {
    accentClass() {
      if (this.transaction.type === 'expense') return 'bg-error';
      return this.transaction.type === 'transfer' ? 'bg-tertiary' : 'bg-primary-container';
    },
    amountClass() {
      if (this.transaction.type === 'expense') return 'text-error';
      return this.transaction.type === 'transfer' ? 'text-on-surface' : 'text-primary-container';
    }
  }
}
</script>
