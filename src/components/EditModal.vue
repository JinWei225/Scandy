<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-content">
      <h2>Edit Transaction</h2>
      <form @submit.prevent="saveChanges">
        <div class="form-group">
          <label for="edit-date">Date</label>
          <input type="date" id="edit-date" v-model="editableTransaction.date" required>
        </div>
        <div class="form-group">
          <label for="edit-description">Description</label>
          <input type="text" id="edit-description" v-model="editableTransaction.description" required>
        </div>
        <div class="form-group">
          <label for="edit-amount">Amount (RM)</label>
          <input type="number" id="edit-amount" v-model="editableTransaction.amount" step="0.01" required>
        </div>
        <div class="modal-actions">
          <button type="button" class="cancel-btn" @click="$emit('close')">Cancel</button>
          <button type="submit" class="save-btn">Save Changes</button>
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
            amount: numericAmount,
          };
        }
      }
    }
  },
  methods: {
    saveChanges() {
        // The backend expects DD/MM/YYYY format for the date
        const dateParts = this.editableTransaction.date.split('-'); // YYYY-MM-DD
        const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;

        const payload = {
            ...this.editableTransaction,
            date: formattedDate,
        };

        this.$emit('save', payload);
    }
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.6);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}
.modal-content {
  background-color: white;
  padding: 2rem;
  border-radius: 8px;
  width: 90%;
  max-width: 500px;
}
.form-group { margin-bottom: 1rem; text-align: left; }
.form-group label { display: block; font-weight: bold; margin-bottom: 0.5rem; }
.form-group input { width: 100%; padding: 0.75rem; border: 1px solid #e5e7eb; border-radius: 5px; font-size: 1rem; box-sizing: border-box; }
.modal-actions { display: flex; justify-content: flex-end; gap: 1rem; margin-top: 2rem; }
.modal-actions button { padding: 0.75rem 1.5rem; border-radius: 5px; font-size: 1rem; font-weight: bold; cursor: pointer; border: none; }
.save-btn { background-color: var(--primary-color); color: white; }
.cancel-btn { background-color: #e5e7eb; }
</style>