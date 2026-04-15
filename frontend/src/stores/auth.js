import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import axios from 'axios'

const safeParseUser = () => {
    try {
        const str = localStorage.getItem('user')
        if (!str || str === 'undefined' || str === 'null') return null
        return JSON.parse(str)
    } catch {
        localStorage.removeItem('user')
        return null
    }
}

export const useAuthStore = defineStore('auth', () => {
    const user = ref(safeParseUser())
    const token = ref(localStorage.getItem('token') || null)

    const isLoggedIn = computed(() => !!token.value && !!user.value)
    const isAdmin    = computed(() => user.value?.role === 'admin')
    const isOwner    = computed(() => user.value?.role === 'owner')
    const isPlayer   = computed(() => user.value?.role === 'player')

    function setAuth(userData, tokenData) {
        user.value = userData
        token.value = tokenData
        localStorage.setItem('user', JSON.stringify(userData))
        localStorage.setItem('token', tokenData)
        axios.defaults.headers.common['Authorization'] = `Bearer ${tokenData}`
    }

    function logout() {
        user.value = null
        token.value = null
        localStorage.removeItem('user')
        localStorage.removeItem('token')
        delete axios.defaults.headers.common['Authorization']
    }

    function updateAvatar(url) {
        if (!user.value) return
        user.value = { ...user.value, avatar_url: url }
        localStorage.setItem('user', JSON.stringify(user.value))
    }

    async function refreshUser() {
        if (!user.value?.id) return
        try {
            const res = await axios.get(`/auth/profile?user_id=${user.value.id}`)
            const fresh = res.data.user
            if (fresh) {
                user.value = fresh
                localStorage.setItem('user', JSON.stringify(fresh))
            }
        } catch { /* silent — use cached user on failure */ }
    }

    return { user, token, isLoggedIn, isAdmin, isOwner, isPlayer, setAuth, logout, updateAvatar, refreshUser }
})
