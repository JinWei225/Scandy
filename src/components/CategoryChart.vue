<template>
  <div class="chart-container">
    <Doughnut :data="chartData" :options="chartOptions" />
  </div>
</template>

<script>
import { Chart as ChartJS, ArcElement, Tooltip, Legend } from 'chart.js'
import { Doughnut } from 'vue-chartjs'
import { computed } from 'vue'

ChartJS.register(ArcElement, Tooltip, Legend)

export default {
  name: 'CategoryChart',
  components: {
    Doughnut
  },
  props: {
    categoryData: {
      type: Array,
      required: true
    }
  },
  setup(props) {
    const chartData = computed(() => {
      return {
        labels: props.categoryData.map(item => item.name),
        datasets: [
          {
            backgroundColor: [
              '#41B883', '#E46651', '#00D8FF', '#DD1B16', '#F7C600', '#8E44AD', '#3498DB', '#2ECC71', '#F39C12', '#D35400'
            ],
            data: props.categoryData.map(item => item.total)
          }
        ]
      }
    })

    const chartOptions = {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'right',
          labels: {
            boxWidth: 15
          }
        }
      }
    }

    return {
      chartData,
      chartOptions
    }
  }
}
</script>

<style scoped>
.chart-container {
  position: relative;
  height: 300px;
  width: 100%;
  margin-bottom: 2rem;
}
</style>
