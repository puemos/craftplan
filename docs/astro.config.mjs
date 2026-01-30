import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://puemos.github.io",
  base: "/craftplan/",
  vite: {
    plugins: [tailwindcss()],
  },
});
