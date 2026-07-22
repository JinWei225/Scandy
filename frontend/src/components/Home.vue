<template>
  <div class="w-full">
    <!-- Primary actions. Scanning and manual entry are actions, not page
         content, so they live behind these cards rather than as always-open
         forms — the page is a ledger first. -->
    <section class="grid grid-cols-2 gap-3 mb-5">
      <button @click="startScanFlow" class="border border-outline-variant/30 bg-surface-container-lowest px-4 py-3 relative flex items-center gap-3 text-left hover:bg-primary/5 transition-colors">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container"></div>
        <span class="material-symbols-outlined text-[22px] text-primary-container">photo_camera</span>
        <span class="font-headline text-sm text-on-surface uppercase tracking-tight leading-tight">Scan<br>Receipt</span>
      </button>

      <button @click="startManualFlow" class="border border-outline-variant/30 bg-surface-container-lowest px-4 py-3 relative flex items-center gap-3 text-left hover:bg-primary/5 transition-colors">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-outline"></div>
        <span class="material-symbols-outlined text-[22px] text-on-surface-variant">edit_note</span>
        <span class="font-headline text-sm text-on-surface uppercase tracking-tight leading-tight">Manual<br>Log</span>
      </button>
    </section>

    <!-- Recent Transactions -->
    <section class="flex flex-col border-t border-outline-variant/20 pt-5">
      <div class="flex justify-between items-baseline gap-3 mb-3">
        <div class="flex items-baseline gap-2 min-w-0">
          <h3 class="font-headline text-lg md:text-xl text-on-surface uppercase tracking-tight">Recent Logs</h3>
        </div>
        <router-link to="/all" class="font-label text-xs text-primary-container uppercase tracking-widest hover:text-primary transition-colors flex items-center gap-1 whitespace-nowrap">
          View Summary <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
        </router-link>
      </div>

      <!-- Date range filter. Defaults to the last 3 days and always shows real
           dates, so the range is legible without opening a picker. -->
      <div class="flex items-end gap-2 mb-4">
        <div class="flex flex-col gap-0.5 min-w-0 flex-1">
          <span class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">From</span>
          <div class="relative border border-outline-variant/30 bg-surface-container-lowest px-2.5 py-1.5 flex items-center gap-1.5 hover:border-primary/50 transition-colors">
            <span class="material-symbols-outlined text-[15px] text-on-surface-variant">calendar_today</span>
            <span class="font-body text-xs font-mono text-on-surface whitespace-nowrap">{{ rangeStartDisplay }}</span>
            <input type="date" v-model="rangeStart" :max="rangeEnd || undefined" class="absolute inset-0 w-full h-full opacity-0 cursor-pointer date-input-overlay" aria-label="Filter from date">
          </div>
        </div>

        <span class="font-label text-xs text-on-surface-variant pb-2">&mdash;</span>

        <div class="flex flex-col gap-0.5 min-w-0 flex-1">
          <span class="font-label text-[10px] text-on-surface-variant uppercase tracking-widest">To</span>
          <div class="relative border border-outline-variant/30 bg-surface-container-lowest px-2.5 py-1.5 flex items-center gap-1.5 hover:border-primary/50 transition-colors">
            <span class="material-symbols-outlined text-[15px] text-on-surface-variant">event</span>
            <span class="font-body text-xs font-mono text-on-surface whitespace-nowrap">{{ rangeEndDisplay }}</span>
            <input type="date" v-model="rangeEnd" :min="rangeStart || undefined" class="absolute inset-0 w-full h-full opacity-0 cursor-pointer date-input-overlay" aria-label="Filter to date">
          </div>
        </div>

        <button @click="resetRange" class="text-on-surface-variant hover:text-primary transition-colors p-1 flex items-center shrink-0" aria-label="Reset date range">
          <span class="material-symbols-outlined text-[18px]">refresh</span>
        </button>
      </div>

      <div class="hidden md:grid grid-cols-12 gap-4 py-2.5 px-3 border-b border-outline-variant/20 bg-surface-container-lowest">
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Date</div>
        <div class="col-span-6 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Description</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Amount</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Actions</div>
      </div>

      <div v-if="displayedTransactions.length === 0" class="py-10 text-center border-b border-outline-variant/20">
        <p class="font-body text-on-surface-variant">No logs in the selected range.</p>
      </div>

      <TransactionRow
        v-else
        v-for="transaction in displayedTransactions"
        :key="transaction.id"
        :transaction="transaction"
        :showCategory="false"
        @select="openViewModal"
        @edit="openEditModal"
        @delete="requestDelete"
      />
    </section>
  </div>

  <!-- Capture/entry flow: scan -> form -> result. Only one step is mounted at
       a time; `flowSource` decides where cancel and "another" lead back to. -->
  <ScanModal
    v-if="flow === 'scan'"
    :isLoading="isLoading"
    :status="scanStatus"
    @close="closeFlow"
    @scan="uploadImage"
  />

  <TransactionFormModal
    v-if="flow === 'form'"
    :transaction="formSeed"
    :categories="categories"
    :accounts="accounts"
    :title="flowSource === 'scan' ? 'Confirm Details' : 'Manual Log'"
    submitLabel="Commit"
    :cancelLabel="flowSource === 'scan' ? 'Cancel' : 'Back'"
    @close="cancelForm"
    @save="commitTransaction"
  />

  <ResultModal
    v-if="flow === 'result'"
    :status="result.status"
    :title="result.title"
    :message="result.message"
    :primaryLabel="result.primaryLabel"
    :secondaryLabel="result.secondaryLabel"
    @close="closeFlow"
    @primary="result.onPrimary"
    @secondary="closeFlow"
  />

  <TransactionDetailModal
    v-if="transactionToView"
    :transaction="transactionToView"
    :accounts="accounts"
    @close="closeViewModal"
  />

  <TransactionFormModal
    v-if="isEditModalVisible"
    :transaction="transactionToEdit"
    :categories="categories"
    :accounts="accounts"
    @close="isEditModalVisible = false"
    @save="handleSaveTransaction"
  />

  <ConfirmDeleteModal
    v-if="isConfirmDeleteVisible"
    @confirm="confirmDelete"
    @cancel="cancelDelete"
  />
</template>

<script>
import { ref, computed, onMounted, watch } from 'vue';
import { useTransactions } from '../composables/useTransactions';
import { useAccounts } from '../composables/useAccounts';
import { useIntent, SendIntent } from '../composables/useIntent';
import { useTransactionModals } from '../composables/useTransactionModals';
import TransactionFormModal from '../components/TransactionFormModal.vue';
import ConfirmDeleteModal from '../components/ConfirmDeleteModal.vue';
import TransactionDetailModal from '../components/TransactionDetailModal.vue';
import ScanModal from '../components/ScanModal.vue';
import ResultModal from '../components/ResultModal.vue';
import TransactionRow from '../components/TransactionRow.vue';
import axios from 'axios';
import { logger } from '../utils/logger';


export default {
  name: 'HomePage',
  components: {
    TransactionFormModal,
    ConfirmDeleteModal,
    TransactionDetailModal,
    ScanModal,
    ResultModal,
    TransactionRow,
  },
  setup() {
    // --- COMPOSABLES ---
    const { transactions, categories, fetchTransactions, fetchCategories } = useTransactions();
    const { accounts, fetchAccounts } = useAccounts();
    const { sharedIntentData, intentConsumed, clearIntentData, consumeIntent } = useIntent();
    const modals = useTransactionModals({ afterChange: fetchAccounts });

    // --- STATE ---
    const isLoading = ref(false);
    const isProcessingIntent = ref(false);

    // Capture/entry flow. `flow` is the visible step, `flowSource` records how
    // it started so the same form and result components serve both paths.
    const flow = ref(null);        // null | 'scan' | 'form' | 'result'
    const flowSource = ref(null);  // 'scan' | 'manual'
    const formSeed = ref(null);    // initial values handed to TransactionFormModal
    const result = ref(null);
    const scanStatus = ref('');

    // Local date (not toISOString, which is UTC and gives yesterday's date before 8 AM in MYT)
    const localDateString = (date = new Date()) => {
      return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
    };

    const makeEmptyForm = () => ({
      date: localDateString(),
      time: new Date().toTimeString().substr(0, 8),
      description: '',
      amount: '',
      category: 'Uncategorized',
      account_id: null,
      to_account_id: null,
      type: 'expense'
    });

    // --- DATE RANGE FILTER (Recent Logs) ---
    // Native date inputs hold YYYY-MM-DD; the API serves DD/MM/YYYY.
    // Defaults to a 3-day window (today and the two days before it).
    const DEFAULT_RANGE_DAYS = 3;
    const defaultRangeStart = () => {
      const start = new Date();
      start.setDate(start.getDate() - (DEFAULT_RANGE_DAYS - 1));
      return localDateString(start);
    };

    const rangeStart = ref(defaultRangeStart());
    const rangeEnd = ref(localDateString());
    const resetRange = () => {
      rangeStart.value = defaultRangeStart();
      rangeEnd.value = localDateString();
    };

    const isoToDisplay = (iso) => {
      const parts = String(iso || '').split('-');
      return parts.length === 3 ? `${parts[2]}/${parts[1]}/${parts[0]}` : '';
    };
    const rangeStartDisplay = computed(() => isoToDisplay(rangeStart.value));
    const rangeEndDisplay = computed(() => isoToDisplay(rangeEnd.value));

    const displayedTransactions = computed(() => {
      // Bounds are seeded on load, but the native picker lets a user clear one;
      // an empty bound means "open-ended on that side".
      const start = rangeStart.value ? rangeStart.value.replace(/-/g, '') : '';
      const end = rangeEnd.value ? rangeEnd.value.replace(/-/g, '') : '99999999';
      return transactions.value.filter(tx => {
        const parts = String(tx.date || '').split('/');
        if (parts.length !== 3) return false;
        const key = `${parts[2]}${parts[1]}${parts[0]}`;
        return key >= start && key <= end;
      });
    });

    // --- FLOW CONTROL ---
    const startScanFlow = () => {
      flowSource.value = 'scan';
      scanStatus.value = '';
      flow.value = 'scan';
    };

    const startManualFlow = () => {
      flowSource.value = 'manual';
      formSeed.value = makeEmptyForm();
      flow.value = 'form';
    };

    const closeFlow = () => {
      flow.value = null;
      flowSource.value = null;
      formSeed.value = null;
      result.value = null;
      scanStatus.value = '';
      // A shared image is finished with once the flow is dismissed, however it
      // ended — otherwise it re-triggers when Home remounts.
      consumeIntent();
    };

    // Scan cancel steps back to the picker; manual cancel leaves the flow.
    const cancelForm = () => {
      if (flowSource.value === 'scan') {
        formSeed.value = null;
        scanStatus.value = '';
        flow.value = 'scan';
      } else {
        closeFlow();
      }
    };

    const showResult = (payload) => {
      result.value = payload;
      flow.value = 'result';
    };

    // --- METHODS ---
    const uploadImage = async (file) => {
      if (!file) return;
      isLoading.value = true;
      scanStatus.value = 'Scanning document...';
      const formData = new FormData();
      formData.append('file', file);
      try {
        const response = await axios.post('/api/upload', formData);
        const dateParts = String(response.data.date || '').split('/');
        const formattedDate = dateParts.length === 3 ? `${dateParts[2]}-${dateParts[1]}-${dateParts[0]}` : localDateString();
        const numericAmount = parseFloat(String(response.data.amount || '').replace('RM', '').trim());
        formSeed.value = {
          date: formattedDate,
          time: response.data.time || '00:00:00',
          amount: isNaN(numericAmount) ? 0 : numericAmount,
          category: 'Uncategorized'
        };
        scanStatus.value = '';
        flow.value = 'form';
      } catch (error) {
        showResult({
          status: 'error',
          title: 'Scan Failed',
          message: error.response?.data?.error || 'Error scanning file.',
          primaryLabel: 'Try Again',
          secondaryLabel: 'Close',
          onPrimary: startScanFlow
        });
      } finally {
        isLoading.value = false;
      }
    };

    const commitTransaction = async (payload) => {
      isLoading.value = true;
      try {
        if (payload.type === 'transfer') {
          // The transfer endpoint takes from/to rather than a single account.
          await axios.post('/api/transactions/transfer', {
            date: payload.date,
            time: payload.time,
            description: payload.description || 'Transfer',
            amount: payload.amount,
            from_account_id: payload.account_id,
            to_account_id: payload.to_account_id
          });
        } else {
          await axios.post('/api/transactions/manual', payload);
        }

        await fetchTransactions();
        await fetchAccounts();

        const amount = Number(payload.amount);
        const summary = [
          `RM ${isNaN(amount) ? payload.amount : amount.toFixed(2)}`,
          payload.type === 'transfer' ? 'Transfer' : payload.category
        ].filter(Boolean).join(' · ');

        const wasScan = flowSource.value === 'scan';
        showResult({
          status: 'success',
          title: 'Log Committed',
          message: summary,
          primaryLabel: wasScan ? 'Scan Another' : 'Add Another',
          secondaryLabel: 'Done',
          onPrimary: wasScan ? startScanFlow : startManualFlow
        });
        consumeIntent();
      } catch (error) {
        logger.error('Failed to commit transaction: ' + error.message, 'Home.vue');
        const seed = payload;
        showResult({
          status: 'error',
          title: 'Commit Failed',
          message: error.response?.data?.error || 'Failed to save transaction.',
          primaryLabel: 'Back To Form',
          secondaryLabel: 'Close',
          // Hand the entered values back so nothing is retyped. The form takes
          // DD/MM/YYYY or YYYY-MM-DD, so the payload can go straight back in.
          onPrimary: () => {
            formSeed.value = { ...seed };
            flow.value = 'form';
          }
        });
      } finally {
        isLoading.value = false;
      }
    };

    // --- WATCHERS ---
    watch(sharedIntentData, async (newData) => {
      // Handle both the 'url' property and the 'extras.STREAM' property from the intent
      const sharedUrl = newData?.url || newData?.extras?.['android.intent.extra.STREAM'];

      if (!sharedUrl) {
          if (newData) logger.warn('Intent data present but no valid URL found', 'Home.vue');
          return;
      }

      // Guard: if this intent was already handled (saved or cancelled), skip re-processing.
      // This prevents re-triggering when the component remounts after navigation.
      if (intentConsumed.value) {
          logger.info('Intent already consumed. Skipping re-trigger on remount.', 'Home.vue');
          clearIntentData(); // Clean up stale data
          return;
      }

      // Prevents multiple concurrent triggers
      if (isProcessingIntent.value) {
          logger.info('Intent processing already in progress. Skipping duplicate trigger.', 'Home.vue');
          return;
      }

      logger.info('Intent data watcher triggered. Data: ' + JSON.stringify(newData), 'Home.vue');

      try {
        isProcessingIntent.value = true;
        isLoading.value = true;
        // Open the scan modal immediately so the shared image visibly lands
        // in the same flow the manual path uses.
        flowSource.value = 'scan';
        flow.value = 'scan';
        scanStatus.value = 'Loading shared image...';

        // Clear intent data early so we don't re-trigger from clearing it later
        clearIntentData();

        // Use native bridge for content:// URIs as fetch() will fail due to security
        let blob;
        if (sharedUrl.startsWith('content://')) {
          logger.info('Detected content:// URI. Using native readContentUri.', 'Home.vue');
          const uriResult = await SendIntent.readContentUri({ uri: sharedUrl });
          if (uriResult && uriResult.data) {
              const byteCharacters = atob(uriResult.data);
              const byteNumbers = new Array(byteCharacters.length);
              for (let i = 0; i < byteCharacters.length; i++) {
                  byteNumbers[i] = byteCharacters.charCodeAt(i);
              }
              const byteArray = new Uint8Array(byteNumbers);
              blob = new Blob([byteArray], { type: uriResult.mimeType || 'image/jpeg' });
              logger.info('Blob created from Base64. Size: ' + blob.size, 'Home.vue');
          } else {
              throw new Error('Native readContentUri returned no data');
          }
        } else {
          // Standard fetch for file:// or other URIs (if permissions allow)
          logger.info('Attempting to fetch blob from URL: ' + sharedUrl, 'Home.vue');
          const response = await fetch(sharedUrl);
          if (!response.ok) {
             throw new Error(`Fetch failed with status ${response.status}`);
          }
          blob = await response.blob();
          logger.info('Blob fetched successfully via fetch(). Size: ' + blob.size, 'Home.vue');
        }

        const sharedFile = new File([blob], "shared_receipt.jpg", { type: blob.type || 'image/jpeg' });

        // Automatically trigger upload and scan
        logger.info('Triggering uploadImage after intent processing', 'Home.vue');
        await uploadImage(sharedFile);
      } catch (error) {
        logger.error('Error handling shared image: ' + error.message, 'Home.vue');
        isLoading.value = false;
        showResult({
          status: 'error',
          title: 'Share Failed',
          message: 'Failed to load shared image: ' + error.message,
          primaryLabel: 'Try Again',
          secondaryLabel: 'Close',
          onPrimary: startScanFlow
        });
      } finally {
        isProcessingIntent.value = false;
      }
    }, { immediate: true });

    // --- LIFECYCLE HOOK ---
    onMounted(() => {
      fetchTransactions();
      fetchAccounts();
      fetchCategories();
    });

    // --- RETURN ---
    return {
      transactions,
      isLoading,
      flow,
      flowSource,
      formSeed,
      result,
      scanStatus,
      displayedTransactions,
      rangeStart,
      rangeEnd,
      rangeStartDisplay,
      rangeEndDisplay,
      resetRange,
      categories,
      accounts,
      startScanFlow,
      startManualFlow,
      closeFlow,
      cancelForm,
      uploadImage,
      commitTransaction,
      fetchAccounts,
      ...modals
    };
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
