import { defineConfig } from 'astro/config';

export default defineConfig({
  base: '/me_blog',
  site: 'https://miaowu123.github.io',
  vite: {
    ssr: {
      noExternal: ['gsap']
    }
  }
});
