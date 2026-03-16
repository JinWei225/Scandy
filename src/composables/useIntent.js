// src/composables/useIntent.js
import { ref } from 'vue';

const sharedIntentData = ref(null);
// Persists across component remounts to prevent re-processing the same intent
const intentConsumed = ref(false);

export function useIntent() {
    const setIntentData = (data) => {
        sharedIntentData.value = data;
        intentConsumed.value = false; // New intent arriving, reset consumed state
    };

    const clearIntentData = () => {
        sharedIntentData.value = null;
    };

    // Call this after the intent has been fully handled (save or cancel)
    // to prevent re-triggering when Home.vue remounts
    const consumeIntent = () => {
        sharedIntentData.value = null;
        intentConsumed.value = true;
    };

    return {
        sharedIntentData,
        intentConsumed,
        setIntentData,
        clearIntentData,
        consumeIntent,
    };
}
