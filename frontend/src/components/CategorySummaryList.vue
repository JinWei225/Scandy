<template>
  <section v-if="items.length > 0" class="mb-12">
    <h3 class="font-headline text-xl md:text-2xl text-on-surface uppercase tracking-tight mb-6">{{ title }}</h3>
    <div class="flex flex-col border-t border-outline-variant/20">
      <button v-for="item in items" :key="item.name" @click="$emit('select', item.name)" class="group grid grid-cols-12 gap-4 py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative text-left w-full">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] opacity-0 group-hover:opacity-100 transition-opacity" :class="accentClass"></div>
        <div class="col-span-8 flex flex-col">
          <span class="font-headline text-base md:text-lg text-on-surface tracking-tight">{{ item.name }}</span>
          <span class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">{{ item.count }} transactions</span>
        </div>
        <div class="col-span-4 flex flex-col items-end">
          <span class="font-headline text-lg md:text-xl text-on-surface tracking-tighter">RM {{ item.total.toFixed(2) }}</span>
          <span class="px-2 py-1 mt-1 border font-label text-[10px] uppercase tracking-widest" :class="badgeClass">{{ item.percentage.toFixed(0) }}%</span>
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
