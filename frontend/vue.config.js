module.exports = {
    publicPath: '/',
    chainWebpack: (config) => {
        // Emit fonts as files instead of inlining them as base64 in the CSS;
        // with unicode-range subsets the browser then only downloads what it uses.
        config.module.rule('fonts').set('parser', { dataUrlCondition: { maxSize: 1024 } });
    },
    devServer: {
        allowedHosts: 'all',
        proxy: {
            '/api': {
                target: 'http://localhost:5001',
                changeOrigin: true
            }
        }
    }
}
