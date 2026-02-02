<!-- src/components/BaseModal.vue -->
<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-content">
      <div class="modal-header">
        <h2>{{ title }}</h2>
        <button class="close-btn" @click="$emit('close')">&times;</button>
      </div>
      <div class="modal-body">
        <!-- The content of other modals will go here -->
        <slot></slot>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'BaseModal',
  props: {
    title: { type: String, required: true }
  },
  emits: ['close']
}
</script>

<style scoped>
.modal-overlay {
  position: fixed; top: 0; left: 0; width: 100%; height: 100%;
  background-color: rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  display: flex;
  justify-content: center; align-items: center; z-index: 1000;
}
.modal-content {
  background-color: var(--card-background); color: var(--text-color);
  padding: 1.5rem; border-radius: 8px; width: 95%; max-width: 600px;
  box-shadow: 0 5px 15px rgba(0,0,0,0.3);
  max-height: 80vh; display: flex; flex-direction: column;
}
.modal-header {
  display: flex; justify-content: space-between; align-items: center;
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 1rem; margin-bottom: 1rem;
}
.modal-header h2 { margin: 0; color: var(--primary-color); }
.close-btn {
  background: none; border: none; font-size: 2rem;
  font-weight: bold; cursor: pointer; color: var(--subtle-text-color);
}
.modal-body { overflow-y: auto; }
.no-transactions-modal { text-align: center; padding: 2rem; }
</style>