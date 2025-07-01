/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  trailingSlash: true,
  skipTrailingSlashRedirect: true,
  distDir: 'dist',
  images: {
    unoptimized: true
  },
  // Next.js 15.x 配置更新
  experimental: {
    // esmExternals 在 Next.js 15.x 中已默认启用，移除此配置
  },
  // React 19.x 兼容性配置
  compiler: {
    // 启用 React 19.x 的编译器优化
    removeConsole: process.env.NODE_ENV === 'production'
  }
}

module.exports = nextConfig
