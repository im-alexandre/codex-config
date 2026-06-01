---
name: react-vite
description: React + Vite SPA development patterns including project setup, configuration, and optimization. Use for building single-page applications with Vite bundler.
---

# React Vite Development

> Fast React SPA development with Vite.

## Instructions

### 1. Project Structure

```
src/
├── main.tsx           # Entry point
├── App.tsx            # Root component
├── components/
│   ├── ui/            # Reusable UI
│   └── features/      # Feature components
├── hooks/             # Custom hooks
├── lib/               # Utilities
├── pages/             # Page components
├── store/             # State management
├── types/             # TypeScript types
└── styles/            # Global CSS
```

### 2. Vite Configuration

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 3000,
    proxy: {
      '/api': 'http://localhost:8000',
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
        },
      },
    },
  },
});
```

### 3. Environment Variables

```bash
# .env
VITE_API_URL=http://api.example.com
VITE_APP_NAME=My App

# Usage
const apiUrl = import.meta.env.VITE_API_URL;
```

### 4. Path Aliases

```json
// tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

### 5. React Router Setup

```tsx
// src/main.tsx
import { BrowserRouter } from 'react-router-dom';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <BrowserRouter>
    <App />
  </BrowserRouter>
);

// src/App.tsx
import { Routes, Route } from 'react-router-dom';

function App() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/about" element={<About />} />
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}
```

### 6. Lazy Loading Routes

```tsx
import { lazy, Suspense } from 'react';

const Dashboard = lazy(() => import('./pages/Dashboard'));

function App() {
  return (
    <Suspense fallback={<Loading />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
      </Routes>
    </Suspense>
  );
}
```

### 7. Development Scripts

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint src --ext ts,tsx"
  }
}
```

## References

- [Vite Documentation](https://vitejs.dev/)
- [React Router](https://reactrouter.com/)
