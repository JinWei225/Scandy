<template>
  <BaseModal size="md" title="Scan Receipt" @close="$emit('close')">
    <div class="flex flex-col gap-6">
      <!-- Source pickers. The camera input differs only by `capture`, which
           Android honours by opening the camera directly; desktop browsers
           ignore it and fall back to the normal file picker. -->
      <div class="flex flex-col gap-3">
        <input type="file" accept="image/*" capture="environment" @change="onPick" ref="cameraInput" id="scan-camera" class="hidden">
        <label for="scan-camera" :class="['border border-outline text-on-surface px-6 py-4 font-label text-xs uppercase tracking-widest transition-colors flex items-center gap-3', isLoading ? 'opacity-50 pointer-events-none' : 'hover:bg-primary/10 cursor-pointer']">
          <span class="material-symbols-outlined text-[20px]">photo_camera</span>
          Take Photo
        </label>

        <input type="file" accept="image/*" @change="onPick" ref="fileInput" id="scan-file" class="hidden">
        <label for="scan-file" :class="['border border-outline text-on-surface px-6 py-4 font-label text-xs uppercase tracking-widest transition-colors flex items-center gap-3', isLoading ? 'opacity-50 pointer-events-none' : 'hover:bg-primary/10 cursor-pointer']">
          <span class="material-symbols-outlined text-[20px]">folder</span>
          Choose File
        </label>
      </div>

      <p class="font-body text-sm text-on-surface-variant font-mono break-all">{{ selectedFile ? selectedFile.name : 'NO_FILE_SELECTED' }}</p>

      <div v-if="status" class="flex items-center gap-3 border px-4 py-3" :class="statusType === 'error' ? 'border-error/40 bg-error/5' : 'border-outline-variant/40 bg-surface-container-lowest'">
        <span class="material-symbols-outlined text-[16px]" :class="statusType === 'error' ? 'text-error' : 'text-on-surface-variant'">{{ statusType === 'error' ? 'error' : 'info' }}</span>
        <p class="font-label text-xs uppercase tracking-widest" :class="statusType === 'error' ? 'text-error' : 'text-on-surface-variant'">{{ status }}</p>
      </div>

      <div class="flex justify-end gap-4">
        <button type="button" class="border border-outline text-on-surface px-4 sm:px-6 py-2 sm:py-3 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors" @click="$emit('close')">Cancel</button>
        <button type="button" :disabled="!selectedFile || isLoading" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-4 sm:px-6 py-2 sm:py-3 hover:bg-primary transition-colors disabled:opacity-50 disabled:cursor-not-allowed" @click="submit">
          {{ isLoading ? 'Scanning...' : 'Scan' }}
        </button>
      </div>
    </div>
  </BaseModal>
</template>

<script>
import BaseModal from './BaseModal.vue'

export default {
  name: 'ScanModal',
  components: { BaseModal },
  props: {
    isLoading: { type: Boolean, default: false },
    // Set by the Android share-intent path, which loads a file before the
    // user ever touches a picker.
    status: { type: String, default: '' },
    statusType: { type: String, default: 'info' }
  },
  emits: ['close', 'scan'],
  data() {
    return {
      selectedFile: null
    }
  },
  methods: {
    onPick(event) {
      const file = event.target.files[0]
      if (file) this.selectedFile = file
      // Reset both inputs so re-picking the same file still fires `change`.
      if (this.$refs.cameraInput) this.$refs.cameraInput.value = null
      if (this.$refs.fileInput) this.$refs.fileInput.value = null
    },
    submit() {
      if (this.selectedFile) this.$emit('scan', this.selectedFile)
    }
  }
}
</script>
