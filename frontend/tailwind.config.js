/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{vue,js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            fontFamily: {
                sans:    ['Lexend', 'system-ui', 'sans-serif'],
                display: ['Lexend', 'system-ui', 'sans-serif'],
            },
            colors: {
                primary:  '#7c3aed',   // violet-700 — KoCourt brand
                'primary-dark': '#6d28d9',
                'primary-light': '#ede9fe',
                surface: '#f8f7ff',
            },
            boxShadow: {
                'card':     '0 2px 12px rgba(0,0,0,0.07)',
                'card-lg':  '0 8px 24px rgba(0,0,0,0.10)',
                'nav':      '0 -2px 16px rgba(0,0,0,0.06)',
                'fab':      '0 6px 24px rgba(124,58,237,0.40)',
            },
        },
    },
    plugins: [],
}
