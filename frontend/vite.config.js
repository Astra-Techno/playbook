import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  const apiTarget = env.VITE_API_TARGET || 'http://localhost/playbook/backend'

  return {
    plugins: [
      vue(),
      // Android WebView has a bug with <script type="module" crossorigin> on
      // same-origin scripts — the CORS-mode fetch silently fails in some WebView
      // versions, so Vue never mounts (blank white screen).
      // Strip crossorigin from all tags in the built index.html.
      {
        name: 'strip-crossorigin',
        transformIndexHtml(html) {
          return html.replace(/ crossorigin/g, '')
        }
      }
    ],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      }
    },
    server: {
      proxy: {
        '/api': {
          target: apiTarget,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api/, '')
        }
      }
    }
  }
})
