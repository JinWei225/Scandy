<template>
  <div class="fixed inset-0 bg-surface/90 backdrop-blur-md z-[100] flex justify-center items-center p-4" @click.self="$emit('close')">
    <div class="bg-surface border border-outline-variant/30 w-full max-w-md p-5 sm:p-8 relative max-h-[90vh] overflow-y-auto">
      <h2 class="font-headline text-xl sm:text-2xl text-primary-container uppercase tracking-tight mb-4 sm:mb-6">{{ title }}</h2>

      <form v-if="formData" @submit.prevent="save" class="flex flex-col gap-4 sm:gap-6">

        <!-- Type Selection -->
        <div class="flex gap-2">
          <button type="button" @click="formData.type = 'expense'" :class="['border px-2 sm:px-6 py-2 font-label text-[10px] sm:text-xs uppercase tracking-widest transition-colors flex-1', formData.type === 'expense' ? 'border-error text-error bg-error/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Expense</button>
          <button type="button" @click="formData.type = 'income'" :class="['border px-2 sm:px-6 py-2 font-label text-[10px] sm:text-xs uppercase tracking-widest transition-colors flex-1', formData.type === 'income' ? 'border-primary-container text-primary-container bg-primary-container/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Income</button>
          <button type="button" @click="formData.type = 'transfer'" :class="['border px-2 sm:px-6 py-2 font-label text-[10px] sm:text-xs uppercase tracking-widest transition-colors flex-1', formData.type === 'transfer' ? 'border-tertiary text-tertiary bg-tertiary/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Transfer</button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
          <div class="flex flex-col gap-1 sm:gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Date</label>
            <div class="relative w-full">
              <input type="text" :value="formattedDateDisplay" readonly class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full pointer-events-none">
              <input type="date" v-model="formData.date" required class="absolute inset-0 w-full h-full opacity-0 cursor-pointer date-input-overlay">
            </div>
          </div>

          <div class="flex flex-col gap-1 sm:gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Time</label>
            <input type="time" v-model="formData.time" step="1" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>

          <div class="flex flex-col gap-1 sm:gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Amount (RM)</label>
            <input type="number" v-model.number="formData.amount" step="0.01" @wheel="$event.target.blur()" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>

          <div class="flex flex-col gap-1 sm:gap-2" v-if="formData.type !== 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Description</label>
            <input type="text" v-model="formData.description" placeholder="e.g., Lunch with team" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>

          <div class="flex flex-col gap-1 sm:gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">{{ formData.type === 'transfer' ? 'From Account' : 'Account' }}</label>
            <select v-model="formData.account_id" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option :value="null">Unassigned</option>
              <option v-for="acc in accounts" :key="acc.id" :value="acc.id">{{ acc.name }}</option>
            </select>
          </div>

          <div class="flex flex-col gap-1 sm:gap-2" v-if="formData.type !== 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Category</label>
            <select v-model="formData.category" required class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option v-for="category in availableCategories" :key="category" :value="category">{{ category }}</option>
            </select>
          </div>

          <div class="flex flex-col gap-1 sm:gap-2" v-if="formData.type === 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">To Account</label>
            <select v-model="formData.to_account_id" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option :value="null">Select Account</option>
              <option v-for="acc in accounts" :key="acc.id" :value="acc.id" :disabled="acc.id === formData.account_id">{{ acc.name }}</option>
            </select>
          </div>
        </div>

        <div class="flex justify-end gap-4 mt-2 sm:mt-4">
          <button type="button" class="border border-outline text-on-surface px-4 sm:px-6 py-2 sm:py-3 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors" @click="$emit('close')">Cancel</button>
          <button type="submit" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-4 sm:px-6 py-2 sm:py-3 hover:bg-primary transition-colors">{{ submitLabel }}</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
export default {
  name: 'TransactionFormModal',
  props: {
    // Initial values: either an existing transaction from the API (edit) or
    // scanned/partial data (confirm). Dates in DD/MM/YYYY or YYYY-MM-DD both work.
    transaction: {
      type: Object,
      required: true,
    },
    categories: {
      type: [Array, Object],
      required: true,
    },
    accounts: {
      type: Array,
      required: false,
      default: () => []
    },
    title: {
      type: String,
      default: 'Edit Transaction'
    },
    submitLabel: {
      type: String,
      default: 'Save Changes'
    }
  },
  emits: ['close', 'save'],
  computed: {
    formattedDateDisplay() {
      if (!this.formData || !this.formData.date) return '';
      const parts = this.formData.date.split('-');
      if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
      return this.formData.date;
    },
    availableCategories() {
      if (!this.categories) return [];
      if (Array.isArray(this.categories)) return this.categories;

      const type = this.formData?.type || 'expense';
      if (type === 'income') return this.categories.income || [];
      return this.categories.expense || [];
    }
  },
  data() {
    return {
      formData: null,
    };
  },
  watch: {
    transaction: {
      immediate: true,
      handler(newVal) {
        if (!newVal) return;

        // The date input requires YYYY-MM-DD; the API uses DD/MM/YYYY
        let date = newVal.date || '';
        if (date.includes('/')) {
          const parts = date.split('/');
          date = `${parts[2]}-${parts[1]}-${parts[0]}`;
        }

        // Prefer amount_cents from the API; fall back to a raw number or "RM x.xx"
        let amount;
        if (newVal.amount_cents != null) {
          amount = newVal.amount_cents / 100;
        } else if (typeof newVal.amount === 'number') {
          amount = newVal.amount;
        } else {
          amount = parseFloat(String(newVal.amount || '').replace('RM', '').trim()) || 0;
        }

        // Transfer legs carry from/to derived by the backend
        const isTransferLeg = !!newVal.transfer_related_id;

        this.formData = {
          ...newVal,
          date,
          time: newVal.time || '00:00:00',
          amount,
          description: newVal.description || '',
          category: newVal.category || 'Uncategorized',
          account_id: (isTransferLeg ? newVal.from_account_id : newVal.account_id) || newVal.account_id || null,
          to_account_id: newVal.to_account_id || null,
          type: isTransferLeg ? 'transfer' : (newVal.type || 'expense')
        };
      }
    }
  },
  methods: {
    save() {
      if (this.formData.type === 'transfer') {
        if (!this.formData.account_id || !this.formData.to_account_id) {
          alert('Please select both From and To accounts.');
          return;
        }
      }

      // The backend expects DD/MM/YYYY
      const parts = this.formData.date.split('-');
      const payload = {
        ...this.formData,
        date: `${parts[2]}/${parts[1]}/${parts[0]}`,
      };

      this.$emit('save', payload);
    }
  }
}
</script>

<style scoped>
.date-input-overlay::-webkit-calendar-picker-indicator {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    opacity: 0;
    cursor: pointer;
}
</style>
