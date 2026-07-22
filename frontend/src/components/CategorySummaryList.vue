<template>
  <section v-if="items.length > 0" class="mb-8">
    <h3 class="font-headline text-lg md:text-xl text-on-surface uppercase tracking-tight mb-4">{{ title }}</h3>
    <div class="flex flex-col border-t border-outline-variant/20">
      <button v-for="item in items" :key="item.name" @click="$emit('select', item.name)" class="group grid grid-cols-12 gap-3 py-2.5 px-3 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative text-left w-full">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] opacity-0 group-hover:opacity-100 transition-opacity" :class="accentClass"></div>
        <div class="col-span-8 flex flex-col min-w-0">
          <span class="font-headline text-base md:text-lg text-on-surface tracking-tight truncate">{{ item.name }}</span>
          <!-- Deliberately the smallest thing in the row: it's a footnote to
               the category name, not a peer of it. -->
          <span class="font-label text-[9px] text-on-surface-variant/80 uppercase tracking-widest">{{ item.count }} transactions</span>
        </div>
        <div class="col-span-4 flex flex-col items-end gap-0.5">
          <span class="font-headline text-base md:text-lg text-on-surface tracking-tighter whitespace-nowrap">RM {{ item.total.toFixed(2) }}</span>
          <span class="px-1.5 py-0.5 border font-label text-[9px] uppercase tracking-widest" :class="badgeClass">{{ item.percentage.toFixed(0) }}%</span>
        </div>
      </button>
    </div>
  </section>
</template>

<script>
export default {
  name: 'CategorySummaryList',
  props: {
    title: { type: String, required: true },
    items: { type: Array, required: true },
    variant: { type: String, default: 'expense' } // 'expense' | 'income'
  },
  emits: ['select'],
  computed: {
    accentClass() {
      return this.variant === 'income' ? 'bg-income' : 'bg-error';
    },
    badgeClass() {
      return this.variant === 'income'
        ? 'bg-income/10 border-income/20 text-income'
        : 'bg-error/10 border-error/20 text-error';
    }
  }
}
</script>
