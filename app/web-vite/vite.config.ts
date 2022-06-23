import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@/': `${__dirname}/src/`
    }
  },
  server: {
    port: 8080,
    proxy: {
      "/api": {
        // for minikube
        target: "http://task.minikube.local",
        // for docker-desktop
        // target: "http://localhost",
        changeOrigin: true,
      },
    }
  }
})
