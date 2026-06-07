<template>
  <div class="w-full">
    <!-- Header Section for Page -->
    <section class="mb-12">
      <h2 class="font-headline text-3xl md:text-4xl font-light text-on-surface uppercase tracking-tight mb-2">Scan & Parse</h2>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-4 mb-8"></div>
    </section>

    <!-- Upload Section -->
    <section class="mb-12 border border-outline-variant/30 bg-surface-container-lowest p-6 md:p-8 relative">
      <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container"></div>
      <h3 class="font-headline text-xl md:text-2xl text-on-surface uppercase tracking-tight mb-6">Upload Document</h3>
      
      <div class="flex flex-col md:flex-row gap-6 items-start md:items-center w-full mt-4">
        <input type="file" @change="handleFileUpload" ref="fileInput" id="file-upload" class="hidden">
        <label for="file-upload" class="border border-outline text-on-surface px-6 py-3 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors cursor-pointer flex items-center gap-2 w-fit">
          <span class="material-symbols-outlined text-[18px]">folder</span>
          Select Source
        </label>
        <span class="font-body text-sm text-on-surface-variant font-mono">{{ selectedFile ? selectedFile.name : 'NO_FILE_SELECTED' }}</span>
      </div>

      <div class="mt-6 flex flex-col items-start w-full">
        <button @click="uploadImage" :disabled="!selectedFile || isLoading" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-8 py-4 hover:bg-primary transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
          {{ isLoading ? 'Processing...' : 'Execute Scan' }}
        </button>
        <div v-if="scanMessage" class="mt-4 flex items-center gap-3 border px-4 py-3 w-full" :class="scanMessageType === 'error' ? 'border-error/40 bg-error/5' : scanMessageType === 'success' ? 'border-primary-container/40 bg-primary-container/5' : 'border-outline-variant/40 bg-surface-container-lowest'">
          <span class="material-symbols-outlined text-[16px]" :class="scanMessageType === 'error' ? 'text-error' : scanMessageType === 'success' ? 'text-primary-container' : 'text-on-surface-variant'">{{ scanMessageType === 'error' ? 'error' : scanMessageType === 'success' ? 'check_circle' : 'info' }}</span>
          <p class="font-label text-xs uppercase tracking-widest" :class="scanMessageType === 'error' ? 'text-error' : scanMessageType === 'success' ? 'text-primary-container' : 'text-on-surface-variant'">{{ scanMessage }}</p>
        </div>
      </div>
    </section>

    <!-- Manual Entry Section -->
    <section class="mb-12 border-t border-outline-variant/20 pt-8">
      <h3 class="font-headline text-xl md:text-2xl text-on-surface uppercase tracking-tight mb-6">Manual Log</h3>
      
      <form @submit.prevent="addManualTransaction" class="flex flex-col gap-6">
        <!-- Type Selection -->
        <div class="flex gap-2">
          <button type="button" @click="manualForm.type = 'expense'" :class="['border px-6 py-2 font-label text-xs uppercase tracking-widest transition-colors flex-1', manualForm.type === 'expense' ? 'border-error text-error bg-error/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Expense</button>
          <button type="button" @click="manualForm.type = 'income'" :class="['border px-6 py-2 font-label text-xs uppercase tracking-widest transition-colors flex-1', manualForm.type === 'income' ? 'border-primary-container text-primary-container bg-primary-container/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Income</button>
          <button type="button" @click="manualForm.type = 'transfer'" :class="['border px-6 py-2 font-label text-xs uppercase tracking-widest transition-colors flex-1', manualForm.type === 'transfer' ? 'border-tertiary text-tertiary bg-tertiary/10' : 'border-outline-variant/50 text-on-surface-variant hover:border-outline']">Transfer</button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Date</label>
            <div class="relative w-full">
              <input type="text" :value="formattedDateDisplay" readonly class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full pointer-events-none">
              <input type="date" v-model="manualForm.date" required class="absolute inset-0 w-full h-full opacity-0 cursor-pointer date-input-overlay">
            </div>
          </div>
          
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Time</label>
            <input type="time" v-model="manualForm.time" step="1" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>
          
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Amount (RM)</label>
            <input type="number" v-model.number="manualForm.amount" step="0.01" @wheel="$event.target.blur()" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>
          
          <div class="flex flex-col gap-2" v-if="manualForm.type !== 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Description</label>
            <input type="text" v-model="manualForm.description" required class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full">
          </div>

          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">{{ manualForm.type === 'transfer' ? 'From Account' : 'Account' }}</label>
            <select v-model="manualForm.account_id" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option :value="null">Unassigned</option>
              <option v-for="acc in accounts" :key="acc.id" :value="acc.id">{{ acc.name }}</option>
            </select>
          </div>

          <div class="flex flex-col gap-2" v-if="manualForm.type !== 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Category</label>
            <select v-model="manualForm.category" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option v-for="cat in availableCategories" :key="cat" :value="cat">{{ cat }}</option>
            </select>
          </div>

          <div class="flex flex-col gap-2" v-if="manualForm.type === 'transfer'">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">To Account</label>
            <select v-model="manualForm.to_account_id" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none w-full">
              <option :value="null">Select Account</option>
              <option v-for="acc in accounts" :key="acc.id" :value="acc.id" :disabled="acc.id === manualForm.account_id">{{ acc.name }}</option>
            </select>
          </div>
        </div>

        <div class="flex flex-col items-start gap-4">
          <button type="submit" :disabled="isLoading" class="bg-outline-variant text-on-surface font-headline uppercase font-bold text-sm tracking-widest px-6 py-3 hover:bg-outline transition-colors disabled:opacity-50 mt-4">
            {{ isLoading ? 'Committing...' : 'Commit Log' }}
          </button>
          <div v-if="manualMessage" class="flex items-center gap-3 border px-4 py-3 w-full" :class="manualMessageType === 'error' ? 'border-error/40 bg-error/5' : 'border-primary-container/40 bg-primary-container/5'">
            <span class="material-symbols-outlined text-[16px]" :class="manualMessageType === 'error' ? 'text-error' : 'text-primary-container'">{{ manualMessageType === 'error' ? 'error' : 'check_circle' }}</span>
            <p class="font-label text-xs uppercase tracking-widest" :class="manualMessageType === 'error' ? 'text-error' : 'text-primary-container'">{{ manualMessage }}</p>
          </div>
        </div>
      </form>
    </section>

    <!-- Recent Transactions -->
    <section class="flex flex-col border-t border-outline-variant/20 pt-8">
      <div class="flex justify-between items-end mb-6">
        <h3 class="font-headline text-xl md:text-2xl text-on-surface uppercase tracking-tight">Recent Logs</h3>
        <router-link to="/all" class="font-label text-xs text-primary-container uppercase tracking-widest hover:text-primary transition-colors flex items-center gap-1">
          View Summary <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
        </router-link>
      </div>

      <div class="hidden md:grid grid-cols-12 gap-4 py-4 px-4 border-b border-outline-variant/20 bg-surface-container-lowest">
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Date</div>
        <div class="col-span-4 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Description</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Category</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Amount</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Actions</div>
      </div>

      <div v-if="transactions.length === 0" class="py-12 text-center border-b border-outline-variant/20">
        <p class="font-body text-on-surface-variant">No logs found.</p>
      </div>

      <div v-else class="group grid grid-cols-1 md:grid-cols-12 gap-2 md:gap-4 py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative" v-for="transaction in latestTransactions" :key="transaction.id">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] opacity-0 group-hover:opacity-100 transition-opacity" :class="transaction.type === 'expense' ? 'bg-error' : (transaction.type === 'transfer' ? 'bg-tertiary' : 'bg-primary-container')"></div>
        
        <div class="col-span-1 md:col-span-2 flex flex-col md:block">
          <div class="font-body text-sm text-on-surface font-mono">{{ transaction.date }}</div>
          <div class="font-label text-[10px] text-on-surface-variant tracking-widest">{{ transaction.time }}</div>
        </div>
        
        <div class="col-span-1 md:col-span-4">
          <div class="font-headline text-md text-on-surface tracking-tight">{{ transaction.description }}</div>
        </div>
        
        <div class="col-span-1 md:col-span-2 flex items-center">
          <span class="px-2 py-1 bg-surface-container-high border border-outline-variant/20 font-label text-[10px] text-on-surface uppercase tracking-widest" v-if="transaction.category">{{ transaction.category }}</span>
        </div>
        
        <div class="col-span-1 md:col-span-2 flex md:justify-end items-center">
          <span class="font-headline text-base md:text-lg tracking-tighter" :class="transaction.type === 'expense' ? 'text-error' : (transaction.type === 'transfer' ? 'text-on-surface' : 'text-primary-container')">{{ transaction.amount }}</span>
        </div>
        
        <div class="col-span-1 md:col-span-2 flex justify-end gap-2 mt-2 md:mt-0 transition-opacity">
          <button @click="openEditModal(transaction)" class="text-on-surface-variant hover:text-primary transition-colors flex items-center justify-center p-1"><span class="material-symbols-outlined text-[18px]">edit</span></button>
          <button @click="deleteTransaction(transaction.id)" class="text-on-surface-variant hover:text-error transition-colors flex items-center justify-center p-1"><span class="material-symbols-outlined text-[18px]">delete</span></button>
        </div>
      </div>
    </section>
  </div>

  <ConfirmationModal
    v-if="isConfirmationModalVisible"
    :scannedData="scannedData"
    :categories="categories"
    :accounts="accounts"
    @close="handleCancelConfirmation"
    @save="handleSaveConfirmation"
  />

  <EditModal
    v-if="isModalVisible"
    :transaction="transactionToEdit"
    :categories="categories"
    :accounts="accounts"
    @close="isModalVisible = false"
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
import { useIntent } from '../composables/useIntent';
import EditModal from '../components/EditModal.vue';
import ConfirmationModal from '../components/ConfirmationModal.vue';
import ConfirmDeleteModal from '../components/ConfirmDeleteModal.vue';
import axios from 'axios';
import { logger } from '../utils/logger';
import { registerPlugin } from '@capacitor/core';
const SendIntent = registerPlugin('SendIntent');


export default {
  name: 'HomePage',
  components: {
    EditModal,
    ConfirmationModal,
    ConfirmDeleteModal,
  },
  setup() {
    // --- COMPOSABLE ---
    const { transactions, fetchTransactions } = useTransactions();
    const { sharedIntentData, intentConsumed, clearIntentData, consumeIntent } = useIntent();

    // --- STATE ---
    const selectedFile = ref(null);
    const isLoading = ref(false);
    const isProcessingIntent = ref(false);
    const scanMessage = ref('');
    const scanMessageType = ref('');
    const manualMessage = ref('');
    const manualMessageType = ref('');
    const categories = ref([]);
    const manualForm = ref({
      date: new Date().toISOString().substr(0, 10),
      time: new Date().toTimeString().substr(0, 8),
      description: '',
      amount: '',
      category: 'Uncategorized',
      account_id: null,
      to_account_id: null,
      type: 'expense'
    });
    
    // Account related state
    const accounts = ref([]);
    const totalBalance = ref(0);
    
    // Load accounts
    const fetchAccounts = async () => {
        try {
            const res = await axios.get('/api/accounts');
            // Defensive check to prevent reduce errors if API fails or returns non-array
            accounts.value = Array.isArray(res.data) ? res.data : [];
            totalBalance.value = accounts.value.reduce((sum, acc) => sum + (acc.balance || 0), 0);
        } catch (err) {
            console.error("Failed to load accounts", err);
            accounts.value = [];
            totalBalance.value = 0;
        }
    };
    const scannedData = ref(null);
    const isConfirmationModalVisible = ref(false);
    const isModalVisible = ref(false);
    const transactionToEdit = ref(null);
    const isConfirmDeleteVisible = ref(false);
    const pendingDeleteId = ref(null);
    const fileInput = ref(null); // To reference the file input element

    // --- COMPUTED ---
    const formattedDateDisplay = computed(() => {
        if (!manualForm.value.date) return '';
        const parts = manualForm.value.date.split('-');
        if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
        return manualForm.value.date;
    });

    const availableCategories = computed(() => {
        if (!categories.value) return [];
        // If categories is still an array (legacy), return it
        if (Array.isArray(categories.value)) return categories.value;
        
        // Return based on type
        const type = manualForm.value.type;
        if (type === 'income') return categories.value.income || [];
        if (type === 'transfer') return []; // Should be hidden anyway
        return categories.value.expense || [];
    });

    const latestTransactions = computed(() => {
      // The transactions array is now reactive from the composable
      return transactions.value.slice(0, 5);
    });

    // --- METHODS ---
    const handleFileUpload = (event) => {
      selectedFile.value = event.target.files[0];
      scanMessage.value = '';
      scanMessageType.value = '';
    };

    const uploadImage = async () => {
      if (!selectedFile.value) return;
      isLoading.value = true;
      scanMessage.value = 'Scanning document...';
      scanMessageType.value = 'info';
      const formData = new FormData();
      formData.append('file', selectedFile.value);
      try {
        const response = await axios.post('/api/upload', formData);
        const dateParts = response.data.date.split('/');
        const formattedDate = `${dateParts[2]}-${dateParts[1]}-${dateParts[0]}`;
        const numericAmount = parseFloat(response.data.amount.replace('RM', '').trim());
        scannedData.value = {
          date: formattedDate,
          time: response.data.time || '00:00:00',
          amount: numericAmount,
          category: 'Uncategorized'
        };
        isConfirmationModalVisible.value = true;
        scanMessage.value = '';
        scanMessageType.value = '';
      } catch (error) {
        scanMessage.value = error.response?.data?.error || 'Error scanning file.';
        scanMessageType.value = 'error';
        selectedFile.value = null;
        if (fileInput.value) fileInput.value.value = null;
      } finally {
        isLoading.value = false;
      }
    };

    const handleSaveConfirmation = async (transactionPayload) => {
      isLoading.value = true;
      try {
        if (transactionPayload.type === 'transfer') {
            if (!transactionPayload.account_id || !transactionPayload.to_account_id) {
                alert("Please select both From and To accounts.");
                isLoading.value = false;
                return;
            }
            const transferPayload = {
                date: transactionPayload.date,
                time: transactionPayload.time,
                description: transactionPayload.description || 'Transfer',
                amount: transactionPayload.amount,
                from_account_id: transactionPayload.account_id,
                to_account_id: transactionPayload.to_account_id
            };
            await axios.post('/api/transactions/transfer', transferPayload);
        } else {
            await axios.post('/api/transactions/manual', transactionPayload);
        }
        scanMessage.value = 'Transaction saved from scan.';
        scanMessageType.value = 'success';
        setTimeout(() => { scanMessage.value = ''; scanMessageType.value = ''; }, 4000);
        await fetchTransactions();
        await fetchAccounts();
      } catch (error) {
        scanMessage.value = 'Failed to save scanned transaction.';
        scanMessageType.value = 'error';
      } finally {
        isLoading.value = false;
        isConfirmationModalVisible.value = false;
        selectedFile.value = null;
        scannedData.value = null;
        consumeIntent();
        if (fileInput.value) fileInput.value.value = null;
      }
    };

    const handleCancelConfirmation = () => {
      isConfirmationModalVisible.value = false;
      selectedFile.value = null;
      scannedData.value = null;
      scanMessage.value = '';
      scanMessageType.value = '';
      consumeIntent();
      if (fileInput.value) fileInput.value.value = null;
    };
    
    const addManualTransaction = async () => {
      isLoading.value = true;
      try {
        const payload = { ...manualForm.value };
        // Ensure date is dd/mm/yyyy
        const parts = payload.date.split('-');
        payload.date = `${parts[2]}/${parts[1]}/${parts[0]}`;
        
        if (payload.type === 'transfer') {
            if (!payload.account_id || !payload.to_account_id) {
                alert("Please select both From and To accounts."); // Simple validation
                isLoading.value = false;
                return;
            }
            // Map fields for transfer endpoint
            const transferPayload = {
                date: payload.date,
                time: payload.time,
                description: payload.description || 'Transfer',
                amount: payload.amount,
                from_account_id: payload.account_id,
                to_account_id: payload.to_account_id
            };
            await axios.post('/api/transactions/transfer', transferPayload);
        } else {
            await axios.post('/api/transactions/manual', payload);
        }
        
        await fetchTransactions();
        await fetchAccounts();

        manualForm.value = {
          date: new Date().toISOString().substr(0, 10),
          time: new Date().toTimeString().substr(0, 8),
          description: '',
          amount: '',
          category: 'Uncategorized',
          account_id: null,
          to_account_id: null,
          type: 'expense'
        };
        manualMessage.value = 'Transaction committed successfully.';
        manualMessageType.value = 'success';
        setTimeout(() => { manualMessage.value = ''; manualMessageType.value = ''; }, 4000);
      } catch (err) {
        console.error(err);
        manualMessage.value = 'Failed to commit transaction.';
        manualMessageType.value = 'error';
      } finally {
        isLoading.value = false;
      }
    };
    
    const deleteTransaction = (id) => {
      pendingDeleteId.value = id;
      isConfirmDeleteVisible.value = true;
    };

    const confirmDelete = async () => {
      isConfirmDeleteVisible.value = false;
      try {
        await axios.delete(`/api/transactions/${pendingDeleteId.value}`);
        await fetchTransactions();
        await fetchAccounts();
      } catch (error) {
        manualMessage.value = 'Failed to delete transaction.';
        manualMessageType.value = 'error';
      } finally {
        pendingDeleteId.value = null;
      }
    };

    const cancelDelete = () => {
      isConfirmDeleteVisible.value = false;
      pendingDeleteId.value = null;
    };
    
    const openEditModal = (transaction) => {
        transactionToEdit.value = transaction;
        isModalVisible.value = true;
    };
    
    const handleSaveTransaction = async (updatedTransaction) => {
        try {
            await axios.put(`/api/transactions/${updatedTransaction.id}`, updatedTransaction);
            isModalVisible.value = false;
            await fetchTransactions(); // Refresh shared data
            await fetchAccounts(); // Refresh accounts to update balance
        } catch (error) {
            alert('Failed to update transaction.');
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
        scanMessage.value = 'Loading shared image...';
        scanMessageType.value = 'info';
        
        // Clear intent data early so we don't re-trigger from clearing it later
        clearIntentData();
        
        // Use native bridge for content:// URIs as fetch() will fail due to security
        let blob;
        if (sharedUrl.startsWith('content://')) {
          logger.info('Detected content:// URI. Using native readContentUri.', 'Home.vue');
          const result = await SendIntent.readContentUri({ uri: sharedUrl });
          if (result && result.data) {
              const byteCharacters = atob(result.data);
              const byteNumbers = new Array(byteCharacters.length);
              for (let i = 0; i < byteCharacters.length; i++) {
                  byteNumbers[i] = byteCharacters.charCodeAt(i);
              }
              const byteArray = new Uint8Array(byteNumbers);
              blob = new Blob([byteArray], { type: result.mimeType || 'image/jpeg' });
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
        
        // Create a file object from the blob
        selectedFile.value = new File([blob], "shared_receipt.jpg", { type: blob.type || 'image/jpeg' });
        
        // Automatically trigger upload and scan
        logger.info('Triggering uploadImage after intent processing', 'Home.vue');
        await uploadImage();
      } catch (error) {
        logger.error('Error handling shared image: ' + error.message, 'Home.vue');
        scanMessage.value = 'Failed to load shared image: ' + error.message;
        scanMessageType.value = 'error';
        isLoading.value = false;
      } finally {
        isProcessingIntent.value = false;
      }
    }, { immediate: true });

    // --- LIFECYCLE HOOK ---
    onMounted(() => {
      fetchTransactions();
      fetchAccounts();
        
      // Load categories
      axios.get('/api/categories')
           .then(res => categories.value = res.data)
           .catch(err => console.error(err));
    });

    // --- RETURN ---
    return {
      selectedFile,
      transactions,
      isLoading,
      scanMessage,
      scanMessageType,
      manualMessage,
      manualMessageType,
      scannedData,
      isConfirmationModalVisible,
      isModalVisible,
      transactionToEdit,
      fileInput,
      latestTransactions,
      manualForm,
      formattedDateDisplay,
      categories,
      accounts,
      totalBalance,
      handleFileUpload,
      uploadImage,
      handleSaveConfirmation,
      handleCancelConfirmation,
      addManualTransaction,
      deleteTransaction,
      confirmDelete,
      cancelDelete,
      isConfirmDeleteVisible,
      openEditModal,
      handleSaveTransaction,
      fetchAccounts,
      availableCategories
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