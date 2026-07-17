import { createApp } from 'vue'
import App from './App.vue'
import router from './router'

// Self-hosted fonts and icons: no CDN dependency, so the native app renders
// correctly offline. Latin subsets only — the UI is English.
import '@fontsource/space-grotesk/latin-300.css'
import '@fontsource/space-grotesk/latin-400.css'
import '@fontsource/space-grotesk/latin-500.css'
import '@fontsource/space-grotesk/latin-600.css'
import '@fontsource/space-grotesk/latin-700.css'
import '@fontsource/inter/latin-400.css'
import '@fontsource/inter/latin-500.css'
import '@fontsource/inter/latin-600.css'
import '@fontsource/inter/latin-700.css'
import 'material-symbols/outlined.css'

import './assets/main.css'

createApp(App).use(router).mount('#app')
