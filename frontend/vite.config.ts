import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

// 端口与代理目标统一从仓库根目录的 .env 读（与后端同一份配置），
// 没配 .env 时用下面的默认值；临时换端口调试也可以用环境变量覆盖，
// 例如 VITE_PROXY_TARGET=http://127.0.0.1:9000 npm run dev。
export default defineConfig(({ mode }) => {
  const rootEnv = loadEnv(mode, fileURLToPath(new URL('..', import.meta.url)), [
    'VITE_',
    'FRONTEND_',
    'BACKEND_',
  ])
  const backendPort = rootEnv.BACKEND_PORT || '8000'
  const backendHost = rootEnv.BACKEND_HOST || '127.0.0.1'
  const proxyTarget = process.env.VITE_PROXY_TARGET ?? `http://${backendHost}:${backendPort}`

  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
    server: {
      host: rootEnv.FRONTEND_HOST || '127.0.0.1',
      port: Number(rootEnv.FRONTEND_PORT || 5173),
      // 关掉自动打开页面：起服务时只打印地址，不拉起浏览器
      open: false,
      strictPort: false,
      proxy: {
        '/api': {
          target: proxyTarget,
          changeOrigin: true,
        },
      },
    },
    build: {
      outDir: 'dist',
      sourcemap: false,
    },
  }
})
