<template>
  <div class="fixed inset-0 bg-surface/90 backdrop-blur-md z-[100] flex justify-center items-center p-4" @click.self="$emit('close')">
    <div class="bg-surface border border-outline-variant/30 w-full max-w-md p-5 sm:p-8 relative max-h-[90vh] overflow-y-auto">
      <h2 class="font-headline text-xl sm:text-2xl text-primary-container uppercase tracking-tight mb-4 sm:mb-6">Confirm Details</h2>
      
      <!-- We use v-if to prevent errors before data is ready -->
      <form v-if="formData" @submit.prevent="saveTransaction" class="flex flex-col gap-4 sm:gap-6">
        
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
              <option v-for="category in filteredCategories" :key="category" :value="category">{{ category }}</option>
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
          <button type="submit" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-4 sm:px-6 py-2 sm:py-3 hover:bg-primary transition-colors">Commit</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
export default {
  name: 'ConfirmationModal',
  props: {
    scannedData: {
      type: Object,
      required: true,
    },
    categories: {
      type: Array, // Note: This might be an Object in practice
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
      if (!this.formData || !this.formData.date) return '';
      const parts = this.formData.date.split('-');
      if (parts.length === 3) {
        return `${parts[2]}/${parts[1]}/${parts[0]}`;
      }
      return this.formData.date;
    },
    filteredCategories() {
      if (!this.formData || !this.categories) return [];
      // If categories is an array (legacy or simple list), return it directly
      if (Array.isArray(this.categories)) return this.categories;
      
      // If categories is an object { expense: [], income: [] }, filter by type
      const type = this.formData.type; // 'expense' or 'income'
      return this.categories[type] || [];
    }
  },
  data() {
    return {
      formData: null,
    };
  },
  watch: {
    scannedData: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.formData = {
            date: newVal.date,
            time: newVal.time || '12:00:00', // Default to 12:00:00 if no time found
            amount: newVal.amount,
            category: newVal.category,
            description: '',
            account_id: null,
            to_account_id: null,
            type: 'expense'
          };
          
          // Auto-switch type if the category suggests it (optional, but good UX)
          // For now, default to expense as receipt scanning is usually for expenses
        }
      }
    }
  },
  methods: {
    saveTransaction() {
      if (this.formData.type === 'transfer') {
          if (!this.formData.account_id || !this.formData.to_account_id) {
              alert("Please select both From and To accounts.");
              return;
          }
      }
      
      // The backend needs DD/MM/YYYY format for the date
      const dateParts = this.formData.date.split('-'); // from YYYY-MM-DD
      const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;

      // Create the final object to send back to the parent
      const payload = {
        date: formattedDate,
        time: this.formData.time,
        description: this.formData.description,
        category: this.formData.category,
        amount: this.formData.amount,
        account_id: this.formData.account_id,
        to_account_id: this.formData.to_account_id,
        type: this.formData.type
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