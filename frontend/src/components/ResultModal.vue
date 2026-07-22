<template>
  <BaseModal size="sm" :title="title" @close="$emit('close')">
    <div class="flex flex-col items-center text-center gap-4 py-2">
      <span class="material-symbols-outlined text-[56px]" :class="isError ? 'text-error' : 'text-primary-container'">
        {{ isError ? 'error' : 'check_circle' }}
      </span>

      <p v-if="message" class="font-body text-sm text-on-surface break-words">{{ message }}</p>

      <div class="flex flex-col-reverse sm:flex-row justify-center gap-3 w-full mt-2">
        <button v-if="secondaryLabel" type="button" class="border border-outline text-on-surface px-4 sm:px-6 py-2 sm:py-3 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors flex-1" @click="$emit('secondary')">
          {{ secondaryLabel }}
        </button>
        <button type="button" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-4 sm:px-6 py-2 sm:py-3 hover:bg-primary transition-colors flex-1" @click="$emit('primary')">
          {{ primaryLabel }}
        </button>
      </div>
    </div>
  </BaseModal>
</template>

<script>
import BaseModal from './BaseModal.vue'

export default {
  name: 'ResultModal',
  components: { BaseModal },
  props: {
    status: {
      type: String,
      default: 'success',
      validator: (value) => ['success', 'error'].includes(value)
    },
    title: { type: String, required: true },
    message: { type: String, default: '' },
    primaryLabel: { type: String, default: 'Done' },
    secondaryLabel: { type: String, default: '' }
  },
  emits: ['close', 'primary', 'secondary'],
  computed: {
    isError() {
      return this.status === 'error'
    }
  }
}
</script>
