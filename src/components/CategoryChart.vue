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
              '#7C3AED', '#6366F1', '#A78BFA', '#4F46E5', 
              '#C4B5FD', '#4338CA', '#8B5CF6', '#5B21B6', 
              '#818CF8', '#A5B4FC'
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
