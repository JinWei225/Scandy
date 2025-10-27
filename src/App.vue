<template>
  <div id="app">
    <TransactionManager />
  </div>
</template>

<script>
import TransactionManager from './components/TransactionManager.vue'

export default {
  name: 'App',
  components: {
    TransactionManager
  }
}
</script>

<style>
body {
  margin: 0;
  background-color: #f0f5fa; /* A light blue-gray background */
}
</style>