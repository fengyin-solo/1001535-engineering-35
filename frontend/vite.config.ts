import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 后端地址、监听端口统一从环境变量读取（由根目录 dev.sh 按 dev.config 注入），
// 单独执行 npm run dev 时回落到与 dev.config 相同的默认值，手工启动方式不受影响。
const proxyTarget = process.env.VITE_PROXY_TARGET ?? 'http://127.0.0.1:8000'
const host = process.env.FRONTEND_HOST ?? '127.0.0.1'
const port = Number(process.env.FRONTEND_PORT ?? 5173)

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    host,
    port,
    // 关掉自动打开页面：起服务时只打印地址，不拉起浏览器
    open: false,
    // 端口被占用时直接报错退出，避免静默换端口导致代理目标对不上
    strictPort: true,
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
})
