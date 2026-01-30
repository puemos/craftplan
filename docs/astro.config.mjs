import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import react from "@astrojs/react";

export default defineConfig({
  site: "https://puemos.github.io",
  base: "/craftplan/",
  integrations: [react()],

  vite: {
    plugins: [tailwindcss()],
    worker: {
      format: "es",
    },
  },
});
