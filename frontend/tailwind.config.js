/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{vue,js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            fontFamily: {
                sans:       ['"Plus Jakarta Sans"', 'system-ui', 'sans-serif'],
                display:    ['"Plus Jakarta Sans"', 'system-ui', 'sans-serif'],
                condensed:  ['"Barlow Condensed"', 'system-ui', 'sans-serif'],
                barlow:     ['"Barlow"', 'system-ui', 'sans-serif'],
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
                'card':     '0 2px 12px rgba(0,0,0,0.08)',
                'card-lg':  '0 4px 24px rgba(0,0,0,0.12)',
                'nav':      '0 -1px 0 rgba(0,0,0,0.06)',
                'fab':      '0 4px 16px rgba(0,0,0,0.18)',
                'premium':  '0 2px 12px rgba(0,0,0,0.08)',
                'float':    '0 4px 16px rgba(0,0,0,0.18)',
                'soft':     '0 1px 4px rgba(0,0,0,0.06)',
            },
        },
    },
    plugins: [],
}
