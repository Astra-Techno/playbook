<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Bell, CheckCheck, Loader2 } from 'lucide-vue-next'

const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const notifications = ref([])
const loading       = ref(true)
const unreadCount   = ref(0)
const markingAll    = ref(false)

const fetchNotifications = async () => {
    loading.value = true
    try {
        const res = await axios.get(`/notifications/list?user_id=${auth.user?.id}`)
        notifications.value = res.data.notifications || []
        unreadCount.value   = res.data.unread_count  || 0
    } catch {
        notifications.value = []
    } finally {
        loading.value = false
    }
}

const markRead = async (n) => {
    if (n.is_read || n.read_at) return
    try {
        await axios.put(`/notifications/${n.id}/read`)
        n.read_at = new Date().toISOString()
        n.is_read = 1
        unreadCount.value = Math.max(0, unreadCount.value - 1)
    } catch { /* silent */ }
}

const markAllRead = async () => {
    markingAll.value = true
    try {
        await axios.put('/notifications/read-all', { user_id: auth.user?.id })
        notifications.value.forEach(n => { n.read_at = new Date().toISOString(); n.is_read = 1 })
        unreadCount.value = 0
        toast.success('All notifications marked as read')
    } catch {
        toast.error('Could not mark all as read')
    } finally {
        markingAll.value = false
    }
}

const timeAgo = (dt) => {
    const diff = (Date.now() - new Date(dt).getTime()) / 1000
    if (diff < 60)   return 'just now'
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
    if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`
    return new Date(dt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })
}

const isUnread = (n) => !n.read_at && !n.is_read

onMounted(() => {
    if (!auth.isLoggedIn) { router.replace('/login'); return }
    fetchNotifications()
})
</script>

<template>
    <div class="min-h-screen bg-slate-50">
        <Teleport to="#header-subject">Notifications</Teleport>

        <!-- Actions bar -->
        <div v-if="notifications.length" class="sticky top-0 z-10 bg-white/95 backdrop-blur border-b border-slate-100 px-5 py-3 flex items-center justify-between">
            <p class="text-xs font-bold text-slate-500">
                <span v-if="unreadCount > 0" class="text-primary">{{ unreadCount }} unread</span>
                <span v-else class="text-emerald-600">All caught up</span>
            </p>
            <button v-if="unreadCount > 0"
                @click="markAllRead"
                :disabled="markingAll"
                class="flex items-center gap-1.5 text-xs font-bold text-primary bg-primary/10 px-3 py-1.5 rounded-full active:scale-95 transition-transform disabled:opacity-50">
                <Loader2 v-if="markingAll" :size="12" class="animate-spin" />
                <CheckCheck v-else :size="12" />
                Mark all read
            </button>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="p-5 space-y-3">
            <div v-for="i in 5" :key="i" class="bg-white rounded-2xl p-4 animate-pulse h-20"></div>
        </div>

        <!-- Empty state -->
        <div v-else-if="notifications.length === 0" class="flex flex-col items-center justify-center py-32 px-8 text-center">
            <div class="w-20 h-20 rounded-full bg-slate-100 flex items-center justify-center mb-5">
                <Bell :size="36" class="text-slate-300" />
            </div>
            <p class="font-black text-slate-700 text-lg mb-2">No notifications</p>
            <p class="text-sm text-slate-400">You're all caught up! Check back later.</p>
        </div>

        <!-- Notifications list -->
        <div v-else class="px-4 py-4 space-y-2">
            <div v-for="n in notifications" :key="n.id"
                @click="markRead(n)"
                class="bg-white rounded-2xl p-4 shadow-sm ring-1 transition-all cursor-pointer active:scale-[0.99]"
                :class="isUnread(n) ? 'ring-primary/20 border-l-4 border-l-primary' : 'ring-slate-100'">
                <div class="flex items-start gap-3">
                    <!-- Unread dot -->
                    <div class="w-2.5 h-2.5 rounded-full shrink-0 mt-1.5"
                        :class="isUnread(n) ? 'bg-primary' : 'bg-transparent'"></div>
                    <div class="flex-1 min-w-0">
                        <div class="flex items-start justify-between gap-2">
                            <p class="text-sm font-bold text-slate-900 leading-snug"
                                :class="isUnread(n) ? 'font-black' : ''">
                                {{ n.title }}
                            </p>
                            <span class="text-[10px] font-semibold text-slate-400 shrink-0 mt-0.5">{{ timeAgo(n.created_at) }}</span>
                        </div>
                        <p v-if="n.body" class="text-xs text-slate-500 mt-1 leading-relaxed">{{ n.body }}</p>
                        <p v-if="n.court_name" class="text-[11px] font-bold text-primary mt-1.5">{{ n.court_name }}</p>
                    </div>
                </div>
            </div>
        </div>

    </div>
</template>
