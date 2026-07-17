import { ref, computed, watch } from 'vue';

export const MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

// Shared year/month filtering and category summary math for the Summary and
// Account pages. `source` is a computed/ref holding the transactions to filter.
export function useMonthlyFilter(source) {
  const selectedYear = ref(null);
  const selectedMonth = ref(null);

  const availableYears = computed(() => {
    const years = new Set(
      source.value
        .map(tx => String(tx.date || '').split('/')[2])
        .filter(Boolean)
    );
    return Array.from(years).sort((a, b) => b - a);
  });

  const availableMonths = computed(() => {
    if (!selectedYear.value) return [];
    const months = new Set(
      source.value
        .filter(tx => String(tx.date || '').endsWith(`/${selectedYear.value}`))
        .map(tx => MONTH_NAMES[parseInt(String(tx.date).split('/')[1], 10) - 1])
        .filter(Boolean)
    );
    return Array.from(months).sort((a, b) => MONTH_NAMES.indexOf(a) - MONTH_NAMES.indexOf(b));
  });

  const filteredTransactions = computed(() => {
    if (!selectedYear.value || !selectedMonth.value) return [];
    const monthString = String(MONTH_NAMES.indexOf(selectedMonth.value) + 1).padStart(2, '0');
    return source.value.filter(tx => {
      const parts = String(tx.date || '').split('/');
      return parts[1] === monthString && parts[2] === selectedYear.value;
    });
  });

  const monthlyStats = computed(() => {
    let expense = 0;
    let income = 0;
    filteredTransactions.value.forEach(tx => {
      // Exclude transfers from calculations
      if (tx.category === 'Transfer' || tx.type === 'transfer') return;
      const amount = (tx.amount_cents || 0) / 100;
      if (tx.type === 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    });
    return { expense, income };
  });

  const buildSummary = (predicate, fallbackCategory, total) => {
    if (!total) return [];
    const summary = filteredTransactions.value.reduce((acc, tx) => {
      if (!predicate(tx)) return acc;
      const category = tx.category || fallbackCategory;
      if (!acc[category]) acc[category] = { total: 0, count: 0 };
      acc[category].total += (tx.amount_cents || 0) / 100;
      acc[category].count += 1;
      return acc;
    }, {});
    return Object.keys(summary).map(name => ({
      name,
      ...summary[name],
      percentage: (summary[name].total / total) * 100
    })).sort((a, b) => b.total - a.total);
  };

  const categorySummary = computed(() => buildSummary(
    tx => tx.category !== 'Transfer' && tx.type !== 'transfer' && tx.type !== 'income',
    'Uncategorized',
    monthlyStats.value.expense
  ));

  const incomeCategorySummary = computed(() => buildSummary(
    tx => tx.type === 'income' && tx.category !== 'Transfer',
    'Other',
    monthlyStats.value.income
  ));

  watch(selectedYear, () => {
    selectedMonth.value = availableMonths.value.length
      ? availableMonths.value[availableMonths.value.length - 1]
      : null;
  });

  // Call after the source data has loaded to select the newest year/month
  const selectLatestPeriod = () => {
    if (availableYears.value.length > 0) {
      selectedYear.value = availableYears.value[0];
      if (!selectedMonth.value && availableMonths.value.length > 0) {
        selectedMonth.value = availableMonths.value[availableMonths.value.length - 1];
      }
    }
  };

  return {
    selectedYear,
    selectedMonth,
    availableYears,
    availableMonths,
    filteredTransactions,
    monthlyStats,
    categorySummary,
    incomeCategorySummary,
    selectLatestPeriod
  };
}
