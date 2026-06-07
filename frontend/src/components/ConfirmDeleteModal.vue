<template>
  <div class="fixed inset-0 bg-surface/90 backdrop-blur-md z-[200] flex justify-center items-center p-4" @click.self="$emit('cancel')">
    <div class="bg-surface border border-outline-variant/30 w-full max-w-sm p-8 relative">
      <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-error"></div>
      <div class="flex items-start gap-4 mb-6">
        <span class="material-symbols-outlined text-error text-[24px] mt-0.5">warning</span>
        <div>
          <h2 class="font-headline text-xl text-on-surface uppercase tracking-tight mb-2">Delete Transaction</h2>
          <p class="font-body text-sm text-on-surface-variant">This action cannot be undone. The transaction will be permanently removed.</p>
        </div>
      </div>
      <div class="flex justify-end gap-3">
        <button @click="$emit('cancel')" class="border border-outline text-on-surface px-5 py-2.5 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors">
          Cancel
        </button>
        <button @click="$emit('confirm')" class="border border-error bg-error/10 text-error px-5 py-2.5 font-label text-xs uppercase tracking-widest hover:bg-error/20 transition-colors">
          Delete
        </button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'ConfirmDeleteModal',
  emits: ['confirm', 'cancel']
}
</script>
