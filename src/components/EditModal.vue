<template>
  <div class="fixed inset-0 bg-surface/90 backdrop-blur-md z-[100] flex justify-center items-center p-4" @click.self="$emit('close')">
    <div class="bg-surface border border-outline-variant/30 w-full max-w-md p-5 sm:p-8 relative max-h-[90vh] overflow-y-auto">
      <h2 class="font-headline text-xl sm:text-2xl text-primary-container uppercase tracking-tight mb-4 sm:mb-6">Edit Transaction</h2>
      
      <form v-if="editableTransaction" @submit.prevent="saveChanges" class="flex flex-col gap-4 sm:gap-6">
        
        <!-- Type Selection -->
        <div class="flex gap-2">
          <button type="button" @click="editableTransaction.type = 'expense'" :class="['border px-2 sm:px-6 py-2 font-label text-[10px] sm:text-xs uppercase tracking-widest transition-colors flex-1', editableTransaction.type === 'expense' ? 'border-error text-error bg-error/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Expense</button>
          <button type="button" @click="editableTransaction.type = 'income'" :class="['border px-2 sm:px-6 py-2 font-label text-[10px] sm:text-xs uppercase tracking-widest transition-colors flex-1', editableTransaction.type === 'income' ? 'border-primary-container text-primary-container bg-primary-container/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Income</button>
          <button type="button" @click="editableTransaction.type = 'transfer'" :class="['border px-2 sm:px-6 py-2 font-label text-[10px] sm:text-xs uppercase tracking-widest transition-colors flex-1', editableTransaction.type === 'transfer' ? 'border-tertiary text-tertiary bg-tertiary/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Transfer</button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
          <div class="flex flex-col gap-1 sm:gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Date</label>
            <div class="relative w-full">
              <input type="text" :value="formattedDateDisplay" readonly class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full pointer-events-none">
              <input type="date" v-model="editableTransaction.date" required class="absolute inset-0 w-full h-full opacity-0 cursor-pointer date-input-overlay">
            </div>
          </div>
          
          <div class="flex flex-col gap-1 sm:gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Time</label>
            <input type="time" v-model="editableTransaction.time" step="1" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>
          
          <div class="flex flex-col gap-1 sm:gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Amount (RM)</label>
            <input type="number" v-model.number="editableTransaction.amount" step="0.01" @wheel="$event.target.blur()" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>
          
          <div class="flex flex-col gap-1 sm:gap-2" v-if="editableTransaction.type !== 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Description</label>
            <input type="text" v-model="editableTransaction.description" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>

          <div class="flex flex-col gap-1 sm:gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">{{ editableTransaction.type === 'transfer' ? 'From Account' : 'Account' }}</label>
            <select v-model="editableTransaction.account_id" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option :value="null">Unassigned</option>
              <option v-for="acc in accounts" :key="acc.id" :value="acc.id">{{ acc.name }}</option>
            </select>
          </div>

          <div class="flex flex-col gap-1 sm:gap-2" v-if="editableTransaction.type !== 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Category</label>
            <select v-model="editableTransaction.category" required class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option v-for="category in availableCategories" :key="category" :value="category">{{ category }}</option>
            </select>
          </div>

          <div class="flex flex-col gap-1 sm:gap-2" v-if="editableTransaction.type === 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">To Account</label>
            <select v-model="editableTransaction.to_account_id" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1.5 sm:py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option :value="null">Select Account</option>
              <option v-for="acc in accounts" :key="acc.id" :value="acc.id" :disabled="acc.id === editableTransaction.account_id">{{ acc.name }}</option>
            </select>
          </div>
        </div>
        
        <div class="flex justify-end gap-4 mt-2 sm:mt-4">
          <button type="button" class="border border-outline text-on-surface px-4 sm:px-6 py-2 sm:py-3 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors" @click="$emit('close')">Cancel</button>
          <button type="submit" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-4 sm:px-6 py-2 sm:py-3 hover:bg-primary transition-colors">Save Changes</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
export default {
  name: 'EditModal',
  props: {
    transaction: {
      type: Object,
      required: true,
    },
    categories: {
      type: [Array, Object], // Accept both during migration
      required: true,
    },
    accounts: {
      type: Array,
      required: false,
      default: () => []
    }
  },
  computed: {
    formattedDateDisplay() {
      if (!this.editableTransaction || !this.editableTransaction.date) return '';
      const parts = this.editableTransaction.date.split('-');
      if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
      return this.editableTransaction.date;
    },
    availableCategories() {
        if (!this.categories) return [];
        if (Array.isArray(this.categories)) return this.categories;
        
        const type = this.editableTransaction?.type || 'expense';
        if (type === 'income') return this.categories.income || [];
        // Transfer usually doesn't have categories, but default to empty or expense if needed
        return this.categories.expense || [];
    }
  },
  data() {
    return {
      editableTransaction: null,
    };
  },
  watch: {
    // When the transaction prop changes, update our local data
    transaction: {
      immediate: true, // Run this watcher immediately when the component is created
      handler(newVal) {
        if (newVal) {
          // The date input requires YYYY-MM-DD format
          const dateParts = newVal.date.split('/'); // DD/MM/YYYY
          const formattedDate = `${dateParts[2]}-${dateParts[1]}-${dateParts[0]}`;

          // The amount input requires a number, not "RM 10.50"
          const numericAmount = parseFloat(newVal.amount.replace('RM', '').trim());

          // Create a local, editable copy of the transaction data
          this.editableTransaction = {
            ...newVal,
            date: formattedDate,
            time: newVal.time || '00:00:00', // Ensure time is present
            amount: numericAmount,
            account_id: newVal.account_id || null, // Ensure account_id is present
            to_account_id: newVal.to_account_id || null, // For transfers
            type: newVal.type || 'expense' // Ensure type is present
          };
        }
      }
    }
  },
  methods: {
    saveChanges() {
        if (this.editableTransaction.type === 'transfer') {
            if (!this.editableTransaction.account_id || !this.editableTransaction.to_account_id) {
                alert("Please select both From and To accounts.");
                return;
            }
        }
        
        // The backend expects DD/MM/YYYY format for the date
        const dateParts = this.editableTransaction.date.split('-'); // YYYY-MM-DD
        const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;

        const payload = {
            ...this.editableTransaction,
            date: formattedDate,
            time: this.editableTransaction.time,
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