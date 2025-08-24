import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tailwind from '@tailwindcss/vite'

// Evita process.cwd(): usa path '.' recomendado
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '')
  const target = env.VITE_SF_BASE_URL // ex.: https://...lightning.force.com

  return {
    plugins: [react(), tailwind()],
    server: {
      port: 5173,
      proxy: target
        ? {
            [env.VITE_DEV_PROXY_PATH || '/sf']: {
              target,
              changeOrigin: true,
              secure: true,
            },
          }
        : undefined,
    },
  }
})
