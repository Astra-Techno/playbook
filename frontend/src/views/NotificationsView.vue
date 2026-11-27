<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Bell, CheckCheck, Loader2 } from 'lucide-vue-next'
import KoCard from '../components/KoCard.vue'

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

// Matchday: group per venue and day, same rules as the app (notification_groups.dart).
const groups = computed(() => {
    const byKey = new Map()
    for (const n of notifications.value) {
        const day = String(n.created_at || '').slice(0, 10)
        const key = n.court_id && day ? `court:${n.court_id}|${day}` : `one:${n.id}`
        if (!byKey.has(key)) byKey.set(key, { key, courtName: n.court_name, day, items: [] })
        byKey.get(key).items.push(n)
    }
    return [...byKey.values()]
})
const dayLabel = (day) => {
    const d = new Date(`${day}T00:00:00`)
    if (Number.isNaN(d.getTime())) return ''
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const diff = Math.round((today - d) / 86400000)
    if (diff === 0) return 'Today'
    if (diff === 1) return 'Yesterday'
    return d.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })
}

const markRead = async (n) => {
    if (!n.is_read && !n.read_at) {
        try {
            await axios.put(`/notifications/${n.id}/read`)
            n.read_at = new Date().toISOString()
            n.is_read = 1
            unreadCount.value = Math.max(0, unreadCount.value - 1)
        } catch { /* silent */ }
    }
    if (n.court_id) router.push(`/courts/${n.court_id}`)
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
    const utc = dt && !dt.endsWith('Z') && !dt.includes('+') ? dt.replace(' ', 'T') + 'Z' : dt
    const diff = (Date.now() - new Date(utc).getTime()) / 1000
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
    <div class="min-h-full bg-white">
        <Teleport to="#header-subject">Notifications</Teleport>

        <!-- Actions bar -->
        <div v-if="notifications.length" class="sticky top-0 z-10 bg-white/95 backdrop-blur border-b border-gray-100 px-5 py-3 flex items-center justify-between">
            <p class="text-xs font-bold text-on-surface-variant">
                <span v-if="unreadCount > 0" class="text-on-surface">{{ unreadCount }} unread</span>
                <span v-else class="text-free">All caught up</span>
            </p>
            <button v-if="unreadCount > 0"
                @click="markAllRead"
                :disabled="markingAll"
                class="flex items-center gap-1.5 text-xs font-bold text-on-surface bg-gray-100 px-3 py-1.5 rounded-full active:scale-95 transition-transform disabled:opacity-50">
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
            <div class="w-20 h-20 rounded-full bg-gray-100 flex items-center justify-center mb-5">
                <Bell :size="36" class="text-gray-300" />
            </div>
            <p class="font-black text-on-surface-variant text-lg mb-2">No notifications</p>
            <p class="text-sm text-outline">You're all caught up! Check back later.</p>
        </div>

        <!-- Notifications list -->
        <div v-else class="px-4 py-4 space-y-2">
            <template v-for="g in groups" :key="g.key">
            <KoCard v-if="g.items.length > 1"
                :kicker="dayLabel(g.day)"
                :title="g.courtName || 'Updates'"
                :meta="`${g.items.length} updates`"
                :badge="g.items.filter(isUnread).length ? `${g.items.filter(isUnread).length} new` : null">
                <div class="space-y-1.5">
                    <button v-for="n in g.items" :key="n.id" type="button" @click="markRead(n)"
                        class="flex w-full items-start gap-2 rounded-xl border bg-white px-3 py-2 text-left"
                        :class="isUnread(n) ? 'border-primary/30' : 'border-outline-variant'">
                        <span class="min-w-0 flex-1">
                            <span class="block text-[13.5px] text-on-surface" :class="isUnread(n) ? 'font-extrabold' : 'font-semibold'">{{ n.title }}</span>
                            <span v-if="n.body" class="block text-xs text-on-surface-variant">{{ n.body }}</span>
                        </span>
                        <span class="shrink-0 font-score text-xs font-semibold text-outline">{{ timeAgo(n.created_at) }}</span>
                    </button>
                </div>
            </KoCard>
            <template v-else>
            <div v-for="n in g.items" :key="n.id"
                @click="markRead(n)"
                class="bg-white rounded-2xl p-4 shadow-sm ring-1 transition-all cursor-pointer active:scale-[0.99]"
                :class="isUnread(n) ? 'border border-gray-200 border-l-4 border-l-black' : 'ring-slate-100'">
                <div class="flex items-start gap-3">
                    <!-- Unread dot -->
                    <div class="w-2.5 h-2.5 rounded-full shrink-0 mt-1.5"
                        :class="isUnread(n) ? 'bg-primary' : 'bg-transparent'"></div>
                    <div class="flex-1 min-w-0">
                        <div class="flex items-start justify-between gap-2">
                            <p class="text-sm font-bold text-on-surface leading-snug"
                                :class="isUnread(n) ? 'font-black' : ''">
                                {{ n.title }}
                            </p>
                            <span class="text-[10px] font-semibold text-outline shrink-0 mt-0.5">{{ timeAgo(n.created_at) }}</span>
                        </div>
                        <p v-if="n.body" class="text-xs text-on-surface-variant mt-1 leading-relaxed">{{ n.body }}</p>
                        <p v-if="n.court_name" class="text-[11px] font-bold text-on-surface mt-1.5">{{ n.court_name }}</p>
                    </div>
                </div>
            </div>
            </template>
            </template>
        </div>

    </div>
</template>
