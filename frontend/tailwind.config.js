/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  // TailwindCSS 4.x uses CSS-based configuration
  // Most theme configuration is now in src/styles/tailwind.css
  plugins: [require("tailwindcss-animate")],
}
