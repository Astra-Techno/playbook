import js from '@eslint/js'
import pluginVue from 'eslint-plugin-vue'

export default [
    js.configs.recommended,
    ...pluginVue.configs['flat/recommended'],
    {
        languageOptions: {
            globals: {
                // Browser globals
                window:                 'readonly',
                document:               'readonly',
                navigator:              'readonly',
                localStorage:           'readonly',
                fetch:                  'readonly',
                URL:                    'readonly',
                URLSearchParams:        'readonly',
                FormData:               'readonly',
                setTimeout:             'readonly',
                clearTimeout:           'readonly',
                setInterval:            'readonly',
                clearInterval:          'readonly',
                requestAnimationFrame:  'readonly',
                cancelAnimationFrame:   'readonly',
                console:                'readonly',
                confirm:                'readonly',
                alert:                  'readonly',
                Image:                  'readonly',
                Blob:                   'readonly',
                File:                   'readonly',
                FileReader:             'readonly',
                Event:                  'readonly',
                CustomEvent:            'readonly',
                MutationObserver:       'readonly',
                IntersectionObserver:   'readonly',
                ResizeObserver:         'readonly',
                // Vue script setup compiler macros
                defineProps:   'readonly',
                defineEmits:   'readonly',
                defineExpose:  'readonly',
                withDefaults:  'readonly',
            },
        },
        rules: {
            // ── Real bugs — these WILL fail CI ────────────────────────
            'no-undef':       'error',
            'vue/no-unused-vars': 'error',

            // ── Warnings — logged but do NOT fail CI ──────────────────
            'no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
            'no-console':     'warn',
            'no-empty':                    ['warn', { allowEmptyCatch: true }],
            'no-shadow-restricted-names':  'warn',   // Infinity icon from lucide shadows global
            'no-useless-assignment':       'warn',

            // ── Style rules — all OFF (we don't enforce formatting via lint) ──
            'vue/multi-word-component-names':              'off',
            'vue/html-self-closing':                       'off',
            'vue/max-attributes-per-line':                 'off',
            'vue/singleline-html-element-content-newline': 'off',
            'vue/multiline-html-element-content-newline':  'off',
            'vue/html-indent':                             'off',
            'vue/html-closing-bracket-newline':            'off',
            'vue/first-attribute-linebreak':               'off',
            'vue/attributes-order':                        'off',
            'vue/no-multi-spaces':                         'off',
            'vue/no-undef-components':                     'off',
        },
    },
]
