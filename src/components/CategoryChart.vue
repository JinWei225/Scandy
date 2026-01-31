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
              '#ea580c', // Orange 600
              '#fb923c', // Orange 400
              '#f97316', // Orange 500
              '#fed7aa', // Orange 200
              '#c2410c', // Orange 700
              '#ef4444', // Red 500
              '#fca5a5', // Red 300
              '#fbbf24', // Amber 400
              '#fde68a', // Amber 200
              '#78350f'  // Amber 900
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
