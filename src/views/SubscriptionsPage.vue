<template>
  <div class="container">
    <div class="header-actions" data-aos="fade-down">
      <h1>Subscriptions</h1>
      <button class="add-btn" @click="openAddModal">
        <span>+</span> Add Subscription
      </button>
    </div>

    <div v-if="subscriptions.length > 0" class="subscriptions-list">
      <div v-for="(sub, index) in subscriptions" :key="sub.id" 
           class="subscription-card" 
           data-aos="fade-up" 
           :data-aos-delay="index * 50">
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
          <button @click="openEditModal(sub)" class="icon-btn edit" title="Edit">✎</button>
          <button @click="deleteSubscription(sub.id)" class="icon-btn delete" title="Delete">🗑</button>
        </div>
      </div>
      
      <div class="total-summary" data-aos="fade-up" data-aos-delay="100">
        <h3>Total Monthly: RM {{ totalMonthly.toFixed(2) }}</h3>
      </div>
    </div>
    <div v-else class="no-subscriptions" data-aos="fade-in">
      <p>No subscriptions added yet.</p>
    </div>

    <!-- Modal for Add/Edit -->
    <div v-if="isModalVisible" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content" data-aos="zoom-in" data-aos-duration="300">
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
  margin-bottom: 2.5rem;
}

.header-actions h1 {
  font-size: 2rem;
  font-weight: 800;
  color: var(--text-color);
  margin: 0;
  letter-spacing: -0.03em;
}

.add-btn {
  background-color: var(--primary-color);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  box-shadow: 0 4px 6px rgba(79, 70, 229, 0.2);
}

.add-btn span {
  font-size: 1.2rem;
  line-height: 1;
}

.add-btn:hover {
  background-color: var(--secondary-color);
  transform: translateY(-2px);
  box-shadow: 0 6px 12px rgba(79, 70, 229, 0.3);
}

.subscriptions-list {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.subscription-card {
  background: var(--card-background);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: var(--glass-border);
  border-radius: 16px;
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: var(--glass-shadow);
  transition: all 0.3s ease;
}

.subscription-card:hover {
  transform: translateY(-4px) scale(1.01);
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.1);
  border-color: var(--primary-color);
}

.sub-info h3 {
  margin: 0 0 0.5rem 0;
  color: var(--text-color);
  font-size: 1.1rem;
  font-weight: 700;
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
  background-color: rgba(79, 70, 229, 0.1);
  color: var(--primary-color);
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.due-date {
  font-weight: 500;
}

.sub-amount {
  font-size: 1.25rem;
  font-weight: 800;
  color: var(--text-color);
  letter-spacing: -0.02em;
}

.sub-actions {
  display: flex;
  gap: 0.5rem;
}



.total-summary {
  margin-top: 2rem;
  text-align: right;
  font-size: 1.25rem;
  color: var(--primary-color);
  font-weight: 700;
  padding: 1rem;
  background: rgba(79, 70, 229, 0.05);
  border-radius: 12px;
  display: inline-block;
  align-self: flex-end;
}

.no-subscriptions {
  text-align: center;
  color: var(--subtle-text-color);
  margin-top: 4rem;
  font-size: 1.1rem;
}

/* Modal Styles */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(4px);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.modal-content {
  background-color: var(--card-background);
  padding: 2.5rem;
  border-radius: 20px;
  width: 90%;
  max-width: 500px;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.modal-content h2 {
  margin-top: 0;
  margin-bottom: 2rem;
  color: var(--text-color);
  font-size: 1.5rem;
  font-weight: 800;
  text-align: center;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 600;
  font-size: 0.9rem;
  color: var(--text-color);
}

.form-group input, .form-group select {
  width: 100%;
  padding: 0.875rem;
  border: 1px solid var(--border-color);
  border-radius: 10px;
  font-size: 1rem;
  background-color: rgba(255, 255, 255, 0.5);
  box-sizing: border-box;
  transition: all 0.2s;
}

.form-group input:focus, .form-group select:focus {
  outline: none;
  border-color: var(--primary-color);
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
  background-color: white;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 2.5rem;
}

.save-btn {
  background-color: var(--primary-color);
  color: white;
  border: none;
  padding: 0.75rem 2rem;
  border-radius: 10px;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 0.2s;
}

.save-btn:hover {
  background-color: var(--secondary-color);
}

.cancel-btn {
  background-color: transparent;
  color: var(--subtle-text-color);
  border: 1px solid transparent;
  padding: 0.75rem 1.5rem;
  border-radius: 10px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.cancel-btn:hover {
  background-color: rgba(0, 0, 0, 0.05);
  color: var(--text-color);
}

/* Dark Mode Input Fix */
html.dark .form-group input,
html.dark .form-group select {
  background-color: rgba(30, 41, 59, 0.5);
  color: white;
  border-color: rgba(255, 255, 255, 0.1);
}

html.dark .form-group input:focus,
html.dark .form-group select:focus {
  background-color: rgba(30, 41, 59, 0.8);
}

html.dark .icon-btn {
  background: rgba(255, 255, 255, 0.1);
}

html.dark .icon-btn:hover {
  background: rgba(255, 255, 255, 0.2);
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
    padding-top: 1rem;
    margin-top: 0.5rem;
  }
}
</style>
