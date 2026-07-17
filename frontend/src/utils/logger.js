import axios from 'axios';
import { Capacitor } from '@capacitor/core';

export const logger = {
    log(message, context = '', level = 'info') {
        const payload = {
            level,
            message: typeof message === 'object' ? JSON.stringify(message, null, 2) : message,
            context
        };

        // Print to local console too
        console[level === 'error' ? 'error' : 'log'](`[${context}] ${message}`);

        // Remote logging only matters on the device, where there is no
        // devtools console; on web it would just spam the backend.
        if (!Capacitor.isNativePlatform()) return;

        axios.post('/api/logs', payload).catch(() => {
            // Swallow: a dead backend shouldn't produce a second error per log line
        });
    },
    info(message, context) { this.log(message, context, 'info'); },
    warn(message, context) { this.log(message, context, 'warn'); },
    error(message, context) { this.log(message, context, 'error'); }
};
