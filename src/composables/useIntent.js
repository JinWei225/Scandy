// src/composables/useIntent.js
import { ref } from 'vue';

const sharedIntentData = ref(null);

export function useIntent() {
    const setIntentData = (data) => {
        sharedIntentData.value = data;
    };

    const clearIntentData = () => {
        sharedIntentData.value = null;
    };

    return {
        sharedIntentData,
        setIntentData,
        clearIntentData
    };
}
