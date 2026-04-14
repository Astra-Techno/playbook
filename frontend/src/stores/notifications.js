import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import axios from 'axios'

export const useNotificationsStore = defineStore('notifications', () => {
    const expiringSoon    = ref([])   // subscriptions expiring within 7 days
    const venueAlerts     = ref([])   // requested venues that went live
    const count = computed(() =>
        expiringSoon.value.length + venueAlerts.value.filter(n => !n.read_at).length
    )
    const bookingInvites = computed(() =>
        venueAlerts.value.filter(n => n.type === 'booking_invite' && !n.read_at)
    )

    const fetch = async (userId) => {
        if (!userId) return
        try {
            const [subRes, notifRes] = await Promise.all([
                axios.get(`/notifications?user_id=${userId}`),
                axios.get(`/user-notifications?user_id=${userId}`),
            ])
            expiringSoon.value = subRes.data.expiring_soon   || []
            venueAlerts.value  = notifRes.data.notifications || []
        } catch {
            expiringSoon.value = []
            venueAlerts.value  = []
        }
    }

    const markRead = async (id) => {
        try {
            await axios.put(`/user-notifications/${id}/read`)
            const n = venueAlerts.value.find(n => n.id === id)
            if (n) n.read_at = new Date().toISOString()
        } catch { /* ignore */ }
    }

    const clear = () => { expiringSoon.value = []; venueAlerts.value = [] }

    return { expiringSoon, venueAlerts, bookingInvites, count, fetch, markRead, clear }
})
