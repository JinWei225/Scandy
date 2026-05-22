import axios from 'axios';

export const logger = {
    log(message, context = '', level = 'info') {
        const payload = {
            level,
            message: typeof message === 'object' ? JSON.stringify(message, null, 2) : message,
            context
        };

        // Print to local console too
        console[level === 'error' ? 'error' : 'log'](`[${context}] ${message}`);

        // Send to remote server
        if (!axios.defaults.baseURL) {
            console.warn('Remote log attempted before baseURL was set.');
        }

        axios.post('/api/logs', payload).catch(err => {
            console.error('Failed to send remote log:', err);
        });
    },
    info(message, context) { this.log(message, context, 'info'); },
    warn(message, context) { this.log(message, context, 'warn'); },
    error(message, context) { this.log(message, context, 'error'); }
};
