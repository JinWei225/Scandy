<template>
  <div class="w-full">
    <!-- Header Section -->
    <section class="mb-12">
      <h2 class="font-headline text-3xl md:text-4xl font-light text-on-surface uppercase tracking-tight mb-2">Settings</h2>
      <div class="h-px w-full bg-outline-variant opacity-20 mt-4"></div>
    </section>

    <!-- Appearance -->
    <section class="mb-12">
      <h3 class="font-headline text-xl md:text-2xl text-on-surface uppercase tracking-tight mb-6">Appearance</h3>
      <div class="flex items-center justify-between border border-outline-variant/20 bg-surface-container-lowest px-4 py-4">
        <div>
          <div class="font-label text-xs text-on-surface-variant uppercase tracking-[0.1em] mb-1">Theme</div>
          <div class="font-headline text-base text-on-surface tracking-tight">{{ themeStore.theme === 'light' ? 'Light Mode' : 'Dark Mode' }}</div>
        </div>
        <ThemeSwitcher />
      </div>
    </section>

    <!-- Categories -->
    <section class="flex flex-col border-t border-outline-variant/20 pt-8">
      <h3 class="font-headline text-xl md:text-2xl text-on-surface uppercase tracking-tight mb-2">Categories</h3>
      <p class="font-body text-sm text-on-surface-variant mb-6">Renaming a category also updates existing logs and recurring charges. Deleting one keeps old logs unchanged.</p>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div v-for="group in groups" :key="group.type">
          <div class="py-3 px-4 border-b border-outline-variant/20 bg-surface-container-lowest font-label text-xs text-on-surface-variant uppercase tracking-[0.1em]">{{ group.label }}</div>

          <div v-for="name in listFor(group.type)" :key="name" class="flex items-center gap-2 py-3 px-4 border-b border-outline-variant/20 hover:bg-surface-container-lowest transition-colors">
            <template v-if="isRenaming(group.type, name)">
              <input
                v-model="renameValue"
                v-focus
                @keyup.enter="submitRename"
                @keyup.esc="cancelRename"
                maxlength="40"
                class="flex-grow min-w-0 bg-transparent border-0 border-b border-primary-container focus:ring-0 px-0 py-1 text-on-surface font-body text-sm rounded-none outline-none">
              <button @click="submitRename" class="text-primary-container hover:text-primary transition-colors p-1" aria-label="Save name"><span class="material-symbols-outlined text-[18px]">check</span></button>
              <button @click="cancelRename" class="text-on-surface-variant hover:text-on-surface transition-colors p-1" aria-label="Cancel rename"><span class="material-symbols-outlined text-[18px]">close</span></button>
            </template>
            <template v-else>
              <span class="flex-grow font-body text-sm text-on-surface truncate">{{ name }}</span>
              <button @click="startRename(group.type, name)" class="text-on-surface-variant hover:text-primary transition-colors p-1" aria-label="Rename category"><span class="material-symbols-outlined text-[18px]">edit</span></button>
              <button @click="requestDelete(group.type, name)" class="text-on-surface-variant hover:text-error transition-colors p-1" aria-label="Delete category"><span class="material-symbols-outlined text-[18px]">delete</span></button>
            </template>
          </div>

          <form @submit.prevent="submitAdd(group.type)" class="flex items-center gap-2 py-3 px-4">
            <input
              v-model="addValue[group.type]"
              :placeholder="`New ${group.type} category`"
              maxlength="40"
              class="flex-grow min-w-0 bg-transparent border-0 border-b border-outline-variant focus:border-primary-container focus:ring-0 px-0 py-1 text-on-surface font-body text-sm rounded-none outline-none">
            <button type="submit" class="text-primary-container hover:text-primary transition-colors p-1" aria-label="Add category"><span class="material-symbols-outlined text-[20px]">add</span></button>
          </form>
        </div>
      </div>

      <p v-if="errorMessage" class="font-label text-xs text-error uppercase tracking-widest mt-6">{{ errorMessage }}</p>
    </section>

    <ConfirmDeleteModal
      v-if="pendingDelete"
      title="Delete Category"
      :message="`Delete '${pendingDelete.name}'? Existing logs keep this label; it just stops being selectable.`"
      @confirm="confirmDelete"
      @cancel="pendingDelete = null"
    />
  </div>
</template>

<script>
import { ref, onMounted } from 'vue';
import axios from 'axios';
import { useTransactions } from '../composables/useTransactions';
import { themeStore } from '../themeStore.js';
import ThemeSwitcher from '../components/ThemeSwitcher.vue';
import ConfirmDeleteModal from '../components/ConfirmDeleteModal.vue';

export default {
  name: 'SettingsPage',
  components: { ThemeSwitcher, ConfirmDeleteModal },
  directives: {
    focus: { mounted: (el) => el.focus() }
  },
  setup() {
    // Singleton state: writing the API's response back into `categories`
    // updates every category dropdown in the app at once.
    const { categories, fetchCategories } = useTransactions();

    const groups = [
      { type: 'expense', label: 'Expense Categories' },
      { type: 'income', label: 'Income Categories' }
    ];

    const addValue = ref({ expense: '', income: '' });
    const renaming = ref(null);
    const renameValue = ref('');
    const pendingDelete = ref(null);
    const errorMessage = ref('');

    const listFor = (type) => {
      if (!categories.value || Array.isArray(categories.value)) return [];
      return categories.value[type] || [];
    };

    const setApiError = (error, fallback) => {
      errorMessage.value = error?.response?.data?.error || fallback;
    };

    const submitAdd = async (type) => {
      const name = addValue.value[type].trim();
      if (!name) return;
      try {
        const response = await axios.post('/api/categories', { type, name });
        categories.value = response.data;
        addValue.value[type] = '';
        errorMessage.value = '';
      } catch (error) {
        setApiError(error, 'Failed to add category');
      }
    };

    const isRenaming = (type, name) => renaming.value && renaming.value.type === type && renaming.value.name === name;

    const startRename = (type, name) => {
      renaming.value = { type, name };
      renameValue.value = name;
      errorMessage.value = '';
    };

    const cancelRename = () => {
      renaming.value = null;
    };

    const submitRename = async () => {
      const { type, name } = renaming.value;
      const newName = renameValue.value.trim();
      if (!newName || newName === name) {
        renaming.value = null;
        return;
      }
      try {
        const response = await axios.put('/api/categories', { type, old_name: name, new_name: newName });
        categories.value = response.data;
        renaming.value = null;
        errorMessage.value = '';
      } catch (error) {
        setApiError(error, 'Failed to rename category');
      }
    };

    const requestDelete = (type, name) => {
      pendingDelete.value = { type, name };
      errorMessage.value = '';
    };

    const confirmDelete = async () => {
      const { type, name } = pendingDelete.value;
      pendingDelete.value = null;
      try {
        const response = await axios.delete('/api/categories', { data: { type, name } });
        categories.value = response.data;
        errorMessage.value = '';
      } catch (error) {
        setApiError(error, 'Failed to delete category');
      }
    };

    onMounted(fetchCategories);

    return {
      themeStore,
      groups,
      addValue,
      renameValue,
      pendingDelete,
      errorMessage,
      listFor,
      submitAdd,
      isRenaming,
      startRename,
      cancelRename,
      submitRename,
      requestDelete,
      confirmDelete
    };
  }
};
</script>
