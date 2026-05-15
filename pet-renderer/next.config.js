/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // pixi-spine is CommonJS; transpile it so Next.js can import it
  transpilePackages: ['pixi-spine'],
  turbopack: {},   // empty = silence the turbopack warning while keeping webpack config
  webpack(config) {
    config.resolve.fallback = {
      ...config.resolve.fallback,
      fs: false,
      path: false,
      crypto: false,
    }
    return config
  },
}

module.exports = nextConfig
