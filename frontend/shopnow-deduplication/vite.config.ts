import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tailwind from '@tailwindcss/vite'
import path from "path";

// Evita process.cwd(): usa path '.' recomendado
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '')
  const target = env.VITE_SF_BASE_URL

  return {
    plugins: [react(), tailwind()],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "src"),
      },
    },
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
