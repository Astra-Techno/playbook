/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{vue,js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            fontFamily: {
                sans:    ['"Plus Jakarta Sans"', 'system-ui', 'sans-serif'],
                display: ['"Plus Jakarta Sans"', 'system-ui', 'sans-serif'],
            },
            colors: {
                primary:  '#000000',
                'primary-dark': '#000000',
                'primary-light': '#f3f4f6',
                surface: '#ffffff',
                ink: {
                    base: '#000000',
                    muted: '#6b7280',
                    light: '#9ca3af',
                },
            },
            boxShadow: {
                'card':     '0 20px 40px -15px rgba(0,0,0,0.05)',
                'card-lg':  '0 30px 60px -15px rgba(0,0,0,0.1)',
                'nav':      '0 -10px 40px rgba(0,0,0,0.05)',
                'fab':      '0 10px 40px -10px rgba(0,0,0,0.15)',
                'premium':  '0 20px 40px -15px rgba(0,0,0,0.05)',
                'float':    '0 10px 40px -10px rgba(0,0,0,0.15)',
            },
        },
    },
    plugins: [],
}
