import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    allowedHosts: ['frontend-abdo-islam-dev.apps.rm1.0a51.p1.openshiftapps.com'],
    proxy: {
      '/api': {
        target: 'http://api-gateway:8080',
        changeOrigin: true,
      },
    },
  },
});
