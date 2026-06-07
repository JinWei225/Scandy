module.exports = {
    publicPath: '/',
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
