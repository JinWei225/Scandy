<template>
  <div class="container">
    <div class="header-actions">
      <h1>Subscriptions</h1>
      <button class="add-btn" @click="openAddModal">Add Subscription</button>
    </div>

    <div v-if="subscriptions.length > 0" class="subscriptions-list">
      <div v-for="sub in subscriptions" :key="sub.id" class="subscription-card">
        <div class="sub-info">
          <h3>{{ sub.name }}</h3>
          <p class="sub-details">
            <span class="category-pill">{{ sub.category }}</span>
            <span class="due-date">Due: Day {{ sub.day_of_month }}</span>
          </p>
        </div>
        <div class="sub-amount">
          RM {{ parseFloat(sub.amount).toFixed(2) }}
        </div>
        <div class="sub-actions">
          <button @click="openEditModal(sub)" class="icon-btn edit">✎</button>
          <button @click="deleteSubscription(sub.id)" class="icon-btn delete">🗑</button>
        </div>
      </div>
      
      <div class="total-summary">
        <h3>Total Monthly: RM {{ totalMonthly.toFixed(2) }}</h3>
      </div>
    </div>
    <div v-else class="no-subscriptions">
      <p>No subscriptions added yet.</p>
    </div>

    <!-- Modal for Add/Edit -->
    <div v-if="isModalVisible" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <h2>{{ isEditing ? 'Edit Subscription' : 'Add Subscription' }}</h2>
        <form @submit.prevent="saveSubscription">
          <div class="form-group">
            <label>Name</label>
            <input v-model="form.name" type="text" required placeholder="e.g. Netflix">
          </div>
          <div class="form-group">
            <label>Amount (RM)</label>
            <input v-model="form.amount" type="number" step="0.01" required placeholder="0.00">
          </div>
          <div class="form-group">
            <label>Day of Month</label>
            <input v-model="form.day_of_month" type="number" min="1" max="31" required placeholder="1-31">
          </div>
          <div class="form-group">
            <label>Category</label>
            <select v-model="form.category" required>
              <option v-for="cat in categories" :key="cat" :value="cat">{{ cat }}</option>
            </select>
          </div>
          <div class="modal-actions">
            <button type="button" class="cancel-btn" @click="closeModal">Cancel</button>
            <button type="submit" class="save-btn">Save</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import axios from 'axios';

export default {
  name: 'SubscriptionsPage',
  setup() {
    const subscriptions = ref([]);
    const categories = ref([]);
    const isModalVisible = ref(false);
    const isEditing = ref(false);
    const form = ref({
      id: null,
      name: '',
      amount: '',
      day_of_month: '',
      category: 'Bills & Utilities'
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
        categories.value = response.data;
      } catch (error) {
        console.error("Error fetching categories:", error);
      }
    };

    const totalMonthly = computed(() => {
      return subscriptions.value.reduce((sum, sub) => sum + parseFloat(sub.amount), 0);
    });

    const openAddModal = () => {
      isEditing.value = false;
      form.value = { id: null, name: '', amount: '', day_of_month: '', category: 'Bills & Utilities' };
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

    const deleteSubscription = async (id) => {
      if (!confirm("Are you sure you want to delete this subscription?")) return;
      try {
        await axios.delete(`/api/subscriptions/${id}`);
        await fetchSubscriptions();
      } catch (error) {
        console.error("Error deleting subscription:", error);
        alert("Failed to delete subscription.");
      }
    };

    onMounted(() => {
      fetchSubscriptions();
      fetchCategories();
    });

    return {
      subscriptions,
      categories,
      isModalVisible,
      isEditing,
      form,
      totalMonthly,
      openAddModal,
      openEditModal,
      closeModal,
      saveSubscription,
      deleteSubscription
    };
  }
}
</script>

<style scoped>
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
}

.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.add-btn {
  background-color: var(--primary-color);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: bold;
  cursor: pointer;
  transition: background-color 0.2s;
}

.add-btn:hover {
  background-color: var(--secondary-color);
}

.subscriptions-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.subscription-card {
  background-color: var(--card-background);
  border-radius: 12px;
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 4px 6px rgba(0,0,0,0.05);
  border: 1px solid var(--border-color);
}

.sub-info h3 {
  margin: 0 0 0.5rem 0;
  color: var(--text-color);
}

.sub-details {
  margin: 0;
  display: flex;
  gap: 1rem;
  align-items: center;
  font-size: 0.9rem;
  color: var(--subtle-text-color);
}

.category-pill {
  background-color: #e0e7ff;
  color: var(--primary-color);
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 0.8rem;
  font-weight: 600;
}

.sub-amount {
  font-size: 1.2rem;
  font-weight: bold;
  color: var(--text-color);
}

.sub-actions {
  display: flex;
  gap: 0.5rem;
}

.icon-btn {
  background: none;
  border: none;
  font-size: 1.2rem;
  cursor: pointer;
  padding: 0.5rem;
  border-radius: 50%;
  transition: background-color 0.2s;
}

.icon-btn.edit { color: var(--primary-color); }
.icon-btn.delete { color: #ef4444; }

.icon-btn:hover {
  background-color: var(--background-color);
}

.total-summary {
  margin-top: 2rem;
  text-align: right;
  font-size: 1.2rem;
  color: var(--primary-color);
}

.no-subscriptions {
  text-align: center;
  color: var(--subtle-text-color);
  margin-top: 3rem;
}

/* Modal Styles */
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
  background-color: var(--card-background);
  padding: 2rem;
  border-radius: 12px;
  width: 90%;
  max-width: 500px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.2);
}

.modal-content h2 {
  margin-top: 0;
  margin-bottom: 1.5rem;
  color: var(--primary-color);
}

.form-group {
  margin-bottom: 1.2rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 600;
}

.form-group input, .form-group select {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  font-size: 1rem;
  background-color: var(--background-color);
  box-sizing: border-box; /* Ensure padding doesn't affect width */
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 2rem;
}

.save-btn {
  background-color: var(--primary-color);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: bold;
  cursor: pointer;
}

.cancel-btn {
  background-color: transparent;
  color: var(--text-color);
  border: 1px solid var(--border-color);
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: bold;
  cursor: pointer;
}

/* Dark Mode Input Fix */
html.dark .form-group input,
html.dark .form-group select {
  background-color: #374151; /* Darker gray */
  color: #ffffff; /* Bright white text */
  border-color: #4b5563;
}

html.dark .form-group input::placeholder {
  color: #9ca3af;
}

/* Mobile Responsive Styles */
@media (max-width: 600px) {
  .header-actions {
    flex-direction: column;
    align-items: flex-start;
    gap: 1rem;
  }

  .subscription-card {
    flex-direction: column;
    align-items: flex-start;
    gap: 1rem;
  }

  .sub-info {
    width: 100%;
  }

  .sub-details {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .sub-amount {
    align-self: flex-end;
    font-size: 1.4rem;
  }

  .sub-actions {
    width: 100%;
    justify-content: flex-end;
    border-top: 1px solid var(--border-color);
    padding-top: 0.5rem;
    margin-top: 0.5rem;
  }
}
</style>
