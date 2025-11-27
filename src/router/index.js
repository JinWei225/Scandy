import { createRouter, createWebHistory } from 'vue-router';
import Home from '../components/Home.vue';
import AllTransactions from '../components/AllTransactions.vue';
import SubscriptionsPage from '../views/SubscriptionsPage.vue';

const routes = [
  {
    path: '/',
    name: 'Home',
    component: Home,
  },
  {
    path: '/all',
    name: 'AllTransactions',
    component: AllTransactions,
  },
  {
    path: '/subscriptions',
    name: 'Subscriptions',
    component: SubscriptionsPage,
  },
];

const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes,
});

export default router;