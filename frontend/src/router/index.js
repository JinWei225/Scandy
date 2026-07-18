import { createRouter, createWebHashHistory } from 'vue-router';
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
  {
    path: '/accounts',
    name: 'Accounts',
    component: () => import('../views/AccountsPage.vue')
  },
  {
    path: '/accounts/:id',
    name: 'AccountTransactions',
    component: () => import('../views/AccountTransactions.vue')
  },
  {
    path: '/settings',
    name: 'Settings',
    component: () => import('../views/SettingsPage.vue')
  }
];

const router = createRouter({
  history: createWebHashHistory(process.env.BASE_URL),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition;
    } else {
      return { top: 0 };
    }
  },
});

export default router;