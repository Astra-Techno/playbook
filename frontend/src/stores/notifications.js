import { defineStore } from 'pinia'
import { ref } from 'vue'
import axios from 'axios'

export const useNotificationsStore = defineStore('notifications', () => {
    const expiringSoon = ref([])   // subscriptions expiring within 7 days
    const count        = ref(0)

    const fetch = async (userId) => {
        if (!userId) return
        try {
            const res = await axios.get(`/notifications?user_id=${userId}`)
            expiringSoon.value = res.data.expiring_soon || []
            count.value        = res.data.count || 0
        } catch {
            expiringSoon.value = []
            count.value        = 0
        }
    }

    const clear = () => { expiringSoon.value = []; count.value = 0 }

    return { expiringSoon, count, fetch, clear }
})
