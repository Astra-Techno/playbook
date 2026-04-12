import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useToastStore = defineStore('toast', () => {
    const toasts = ref([])

    function show(message, type = 'success', duration = 3500) {
        const id = Date.now() + Math.random()
        toasts.value.push({ id, message, type })
        setTimeout(() => {
            toasts.value = toasts.value.filter(t => t.id !== id)
        }, duration)
    }

    const success = (msg) => show(msg, 'success')
    const error = (msg) => show(msg, 'error')
    const info = (msg) => show(msg, 'info')

    return { toasts, success, error, info }
})
