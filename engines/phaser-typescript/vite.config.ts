import { defineConfig } from "vite";

export default defineConfig({
  // Relative URLs let the same build run at /play/ on GitHub Pages and from
  // any local static server without knowing the repository name in advance.
  base: "./",
  build: {
    chunkSizeWarningLimit: 1400,
  },
});
