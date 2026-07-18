<template>
  <div class="w-full">
    <!-- Header Section -->
    <section class="mb-12">
      <div class="flex items-center gap-4 mb-2">
        <h2 class="font-headline text-3xl md:text-4xl font-light text-on-surface uppercase tracking-tight m-0">Recurring Vault</h2>
      </div>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-4 mb-8"></div>
      <div class="flex flex-col md:flex-row md:justify-between md:items-end gap-6">
        <div>
          <p class="font-label text-sm text-on-surface-variant uppercase tracking-[0.1em] mb-1">Total Monthly Commitments</p>
          <p class="font-headline text-4xl md:text-6xl text-primary-container tracking-tighter">RM {{ totalMonthly.toFixed(2) }}</p>
        </div>
        <button @click="openAddModal" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-6 py-3 hover:bg-primary transition-colors flex items-center gap-2 w-fit">
          <span class="material-symbols-outlined text-[18px]">add</span>
          New Entity
        </button>
      </div>
    </section>

    <!-- Subscriptions List -->
    <section class="flex flex-col border-t border-outline-variant/20">
      <div class="hidden md:grid grid-cols-12 gap-4 py-4 px-4 border-b border-outline-variant/20 bg-surface-container-lowest">
        <div class="col-span-4 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Service</div>
        <div class="col-span-3 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">Category</div>
        <div class="col-span-3 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Commitment Amount</div>
        <div class="col-span-2 font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] text-right">Actions</div>
      </div>

      <div v-if="subscriptions.length === 0" class="py-12 text-center border-b border-outline-variant/20">
        <p class="font-body text-on-surface-variant">No recurring commitments found.</p>
      </div>

      <div v-else class="group grid grid-cols-1 md:grid-cols-12 gap-2 md:gap-4 py-6 md:py-4 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors items-center relative" v-for="sub in subscriptions" :key="sub.id">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container opacity-0 group-hover:opacity-100 transition-opacity"></div>
        <div class="col-span-1 md:col-span-4 flex items-center gap-4">
          <div class="w-10 h-10 border border-outline-variant/30 flex items-center justify-center text-on-surface-variant bg-surface-container-high group-hover:border-primary/50 transition-colors">
            <span class="material-symbols-outlined">event_repeat</span>
          </div>
          <div>
            <div class="font-headline text-base md:text-lg text-on-surface tracking-tight">{{ sub.name }}</div>
            <div class="font-body text-sm text-on-surface-variant tracking-[-0.02em] font-mono">Day: {{ sub.day_of_month }}</div>
            <div class="font-body text-xs text-on-surface-variant/70 tracking-[-0.02em]">{{ lastChargedLabel(sub) }}</div>
          </div>
        </div>
        <div class="col-span-1 md:col-span-3 flex items-center md:items-start mt-2 md:mt-0">
          <span class="px-2 py-1 bg-surface-container-high border border-outline-variant/20 font-label text-[10px] text-on-surface uppercase tracking-widest">{{ sub.category }}</span>
        </div>
        <div class="col-span-1 md:col-span-3 flex md:justify-end items-center mt-2 md:mt-0">
          <span class="font-headline text-lg md:text-xl text-on-surface tracking-tighter">RM {{ parseFloat(sub.amount).toFixed(2) }}</span>
        </div>
        <div class="col-span-1 md:col-span-2 flex justify-end gap-2 mt-4 md:mt-0 transition-opacity">
          <button @click="openEditModal(sub)" class="border border-outline text-on-surface px-4 py-2 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors">Edit</button>
          <button @click="requestDelete(sub)" class="border border-error text-error px-4 py-2 font-label text-xs uppercase tracking-widest hover:bg-error/10 transition-colors">Del</button>
        </div>
      </div>
    </section>

    <!-- Modal for Add/Edit -->
    <BaseModal v-if="isModalVisible" size="md" :title="isEditing ? 'Edit Entity' : 'New Entity'" @close="closeModal">
        <form @submit.prevent="saveSubscription" class="flex flex-col gap-6">
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Name</label>
            <input v-model="form.name" type="text" required placeholder="e.g. Netflix" class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none">
          </div>
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Amount (RM)</label>
            <input v-model="form.amount" type="number" step="0.01" @wheel="$event.target.blur()" required placeholder="0.00" class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none">
          </div>
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Day of Month</label>
            <input v-model="form.day_of_month" type="number" min="1" max="31" required placeholder="1-31" class="bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none">
          </div>
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Category</label>
            <select v-model="form.category" required class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none">
              <option v-for="cat in categories" :key="cat" :value="cat">{{ cat }}</option>
            </select>
          </div>
          <div class="flex flex-col gap-2">
            <label class="font-label text-xs text-on-surface-variant uppercase tracking-widest">Account</label>
            <select v-model="form.account_id" class="bg-surface border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-2 text-on-surface font-body rounded-none outline-none">
              <option :value="null">Unassigned</option>
              <option v-for="acc in accounts" :key="acc.id" :value="acc.id">{{ acc.name }}</option>
            </select>
          </div>
          <div class="flex justify-end gap-4 mt-4">
            <button type="button" class="border border-outline text-on-surface px-6 py-3 font-label text-xs uppercase tracking-widest hover:bg-primary/10 transition-colors" @click="closeModal">Cancel</button>
            <button type="submit" class="bg-primary-container text-on-primary font-headline uppercase font-bold text-sm tracking-widest px-6 py-3 hover:bg-primary transition-colors">Save</button>
          </div>
        </form>
    </BaseModal>

    <ConfirmDeleteModal
      v-if="subToDelete"
      title="Delete Subscription"
      :message="`Delete ${subToDelete.name}? Future months will no longer be recorded automatically.`"
      @confirm="confirmDelete"
      @cancel="subToDelete = null"
    />
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import axios from 'axios';
import { useAccounts } from '../composables/useAccounts';
import ConfirmDeleteModal from '../components/ConfirmDeleteModal.vue';
import BaseModal from '../components/BaseModal.vue';

export default {
  name: 'SubscriptionsPage',
  components: { ConfirmDeleteModal, BaseModal },
  setup() {
    const subscriptions = ref([]);
    const categories = ref([]);
    const { accounts, fetchAccounts } = useAccounts();
    const subToDelete = ref(null);
    const isModalVisible = ref(false);
    const isEditing = ref(false);
    const form = ref({
      id: null,
      name: '',
      amount: '',
      day_of_month: '',
      category: 'Bills & Utilities',
      account_id: null
    });

    const fetchSubscriptions = async () => {
      try {
        const response = await axios.get('/api/subscriptions');
        subscriptions.value = response.data;
      } catch (error) {
        console.error("Error fetching subscriptions:", error);
      }
    };

    const fetchCategories = async () => {
      try {
        const response = await axios.get('/api/categories');
        categories.value = response.data.expense;
      } catch (error) {
        console.error("Error fetching categories:", error);
      }
    };

    const totalMonthly = computed(() => {
      return subscriptions.value.reduce((sum, sub) => sum + parseFloat(sub.amount), 0);
    });

    // Charges are only recorded when a client opens the app during the due month
    // (see improvements.md 1.14) — surfacing the last one makes a skipped month visible.
    const lastChargedLabel = (sub) => {
      const raw = sub.last_recorded_date;
      if (!raw) return 'Never charged';
      const parsed = new Date(`${raw}T00:00:00`);
      if (isNaN(parsed)) return 'Never charged';
      const formatted = parsed.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
      return `Last charged ${formatted}`;
    };

    const openAddModal = () => {
      isEditing.value = false;
      form.value = { id: null, name: '', amount: '', day_of_month: '', category: 'Bills & Utilities', account_id: null };
      isModalVisible.value = true;
    };

    const openEditModal = (sub) => {
      isEditing.value = true;
      form.value = { ...sub };
      isModalVisible.value = true;
    };

    const closeModal = () => {
      isModalVisible.value = false;
    };

    const saveSubscription = async () => {
      try {
        const payload = { ...form.value };
        if (isEditing.value) {
          await axios.put(`/api/subscriptions/${payload.id}`, payload);
        } else {
          await axios.post('/api/subscriptions', payload);
        }
        await fetchSubscriptions();
        closeModal();
      } catch (error) {
        console.error("Error saving subscription:", error);
        alert("Failed to save subscription.");
      }
    };

    const requestDelete = (sub) => {
      subToDelete.value = sub;
    };

    const confirmDelete = async () => {
      const sub = subToDelete.value;
      subToDelete.value = null;
      try {
        await axios.delete(`/api/subscriptions/${sub.id}`);
        await fetchSubscriptions();
      } catch (error) {
        console.error("Error deleting subscription:", error);
        alert("Failed to delete subscription.");
      }
    };

    onMounted(() => {
      fetchSubscriptions();
      fetchCategories();
      fetchAccounts();
    });

    return {
      subscriptions,
      categories,
      accounts,
      isModalVisible,
      isEditing,
      form,
      subToDelete,
      totalMonthly,
      lastChargedLabel,
      openAddModal,
      openEditModal,
      closeModal,
      saveSubscription,
      requestDelete,
      confirmDelete
    };
  }
}
</script>

<style scoped>
/* Empty style, Tailwind is handling everything globally */
</style>
