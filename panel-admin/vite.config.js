import process from 'node:process'
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const apiUrl = env.VITE_API_URL || 'https://api.joblyx.com'

  // Content-Security-Policy injecté en production uniquement.
  // Le serveur de dev Vite a besoin de scripts inline (React Refresh), on ne l'applique donc pas en dev.
  const csp = [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https:",
    "font-src 'self' data:",
    `connect-src 'self' ${apiUrl}`,
    "object-src 'none'",
    "base-uri 'self'",
  ].join('; ')

  return {
    plugins: [
      react(),
      {
        name: 'inject-csp',
        apply: 'build',
        transformIndexHtml(html) {
          return html.replace(
            '</head>',
            `    <meta http-equiv="Content-Security-Policy" content="${csp}" />\n  </head>`,
          )
        },
      },
    ],
  }
})
