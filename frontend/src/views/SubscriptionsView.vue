<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { useNotificationsStore } from '../stores/notifications'
import { Award, AlertTriangle, RefreshCw, X } from 'lucide-vue-next'
import KoCard from '../components/KoCard.vue'

const router        = useRouter()
const auth          = useAuthStore()
const toast         = useToastStore()
const notifications = useNotificationsStore()

const subs          = ref([])
const loading       = ref(true)
const error         = ref(false)
const cancellingId  = ref(null)   // sub id being cancelled

const active    = computed(() => subs.value.filter(s => s.status === 'active' && new Date(s.end_date) >= new Date()))
const cancelled = computed(() => subs.value.filter(s => s.status === 'cancelled' && new Date(s.end_date) >= new Date()))
const past      = computed(() => subs.value.filter(s => new Date(s.end_date) < new Date()))

const slotLabel = (t) => ({ morning: 'Morning', evening: 'Evening', full_day: 'Full Day', unlimited: 'Unlimited' }[t] || t)

const daysLeft = (end) => Math.max(0, Math.ceil((new Date(end) - new Date()) / 86400000))

const fmt = (d) => new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })

const isExpiringSoon = (end) => daysLeft(end) <= 7

const fetchSubs = async () => {
    loading.value = true
    error.value   = false
    try {
        const res  = await axios.get(`/subscriptions?user_id=${auth.user?.id}`)
        subs.value = res.data.records || []
    } catch { error.value = true }
    finally  { loading.value = false }
}

const cancelSub = async (s) => {
    if (!confirm(`Cancel "${s.plan_name}"? You'll keep access until ${fmt(s.end_date)}.`)) return
    cancellingId.value = s.id
    try {
        await axios.put(`/subscriptions/${s.id}/cancel`, { user_id: auth.user.id })
        toast.success('Subscription cancelled. Access continues until expiry.')
        s.status = 'cancelled'
        // Refresh notification badge
        notifications.fetch(auth.user.id)
    } catch (e) {
        toast.error(e.response?.data?.message || 'Could not cancel')
    } finally {
        cancellingId.value = null
    }
}

onMounted(fetchSubs)
</script>

<template>
    <div class="min-h-full bg-white">

        <!-- Loading -->
        <div v-if="loading" class="p-5 space-y-3">
            <div v-for="i in 3" :key="i" class="bg-white rounded-2xl p-4 animate-pulse h-28"></div>
        </div>

        <!-- Error -->
        <div v-else-if="error" class="flex flex-col items-center justify-center py-24 px-8 text-center">
            <p class="font-bold text-on-surface-variant mb-4">Could not load memberships</p>
            <button @click="fetchSubs" class="text-sm font-bold text-on-surface">Retry</button>
        </div>

        <!-- Empty -->
        <div v-else-if="subs.length === 0" class="flex flex-col items-center justify-center py-28 px-8 text-center">
            <div class="w-20 h-20 rounded-full bg-gray-100 flex items-center justify-center mb-5">
                <Award :size="36" class="text-on-surface" />
            </div>
            <p class="font-black text-on-surface text-lg mb-2">No memberships yet</p>
            <p class="text-sm text-outline mb-6">Subscribe to a court plan to unlock member benefits.</p>
            <button @click="router.push('/')"
                class="bg-primary text-white font-bold text-sm px-6 py-3 rounded-full active:scale-95 transition-transform">
                Browse Courts
            </button>
        </div>

        <template v-else>

            <!-- ── Expiry Reminder Banner ── -->
            <div v-if="active.some(s => isExpiringSoon(s.end_date))" class="mx-4 mt-5">
                <div v-for="s in active.filter(s => isExpiringSoon(s.end_date))" :key="'banner-' + s.id"
                    class="bg-amber-50 border border-amber-200 rounded-2xl px-4 py-3 flex items-start gap-3 mb-2">
                    <AlertTriangle :size="18" class="text-ending shrink-0 mt-0.5" />
                    <div class="flex-1 min-w-0">
                        <p class="text-sm font-black text-amber-800">
                            {{ s.plan_name }} expires in {{ daysLeft(s.end_date) }} day{{ daysLeft(s.end_date) === 1 ? '' : 's' }}
                        </p>
                        <p class="text-xs text-ending mt-0.5">{{ s.court_name }} · {{ fmt(s.end_date) }}</p>
                    </div>
                    <button @click="router.push(`/courts/${s.court_id}`)"
                        class="shrink-0 flex items-center gap-1 text-[11px] font-black text-ending bg-amber-100 px-3 py-1.5 rounded-full active:scale-95 transition-transform">
                        <RefreshCw :size="11" />
                        Renew
                    </button>
                </div>
            </div>

            <!-- ── Active ── -->
            <div v-if="active.length" class="px-4 pt-5">
                <p class="font-score text-[10px] font-bold text-outline uppercase tracking-[0.08em] mb-3">Active</p>
                <div class="space-y-3">
                    <KoCard v-for="s in active" :key="s.id"
                        :kicker="isExpiringSoon(s.end_date) ? 'Expiring soon' : 'Membership'"
                        :title="s.court_name"
                        :meta="s.plan_name"
                        :badge="`${daysLeft(s.end_date)}d`"
                        :stats="[
                            { value: String(daysLeft(s.end_date)), label: 'days left' },
                            { value: slotLabel(s.slot_type), label: 'access' },
                            { value: new Date(s.end_date).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }), label: 'ends' },
                        ]"
                        :action="isExpiringSoon(s.end_date) ? 'Renew now' : 'View court'"
                        :secondary="!isExpiringSoon(s.end_date)"
                        @action="router.push(`/courts/${s.court_id}`)">
                        <button @click="cancelSub(s)" :disabled="cancellingId === s.id"
                            class="flex items-center gap-1 text-xs font-semibold px-3 py-2 rounded-xl bg-white text-due border border-outline-variant disabled:opacity-40">
                            <X :size="12" /> Cancel membership
                        </button>
                    </KoCard>
                </div>
            </div>

            <!-- ── Cancelled (still within access period) ── -->
            <div v-if="cancelled.length" class="px-4 mt-6">
                <p class="font-score text-[10px] font-bold text-outline uppercase tracking-[0.08em] mb-3">Cancelled</p>
                <div class="space-y-2">
                    <div v-for="s in cancelled" :key="s.id"
                        class="bg-white rounded-2xl p-4 ring-1 ring-slate-100">
                        <div class="flex items-center justify-between gap-3">
                            <div class="flex items-center gap-3">
                                <div class="w-9 h-9 rounded-xl bg-gray-100 flex items-center justify-center shrink-0">
                                    <Award :size="16" class="text-outline" />
                                </div>
                                <div>
                                    <p class="font-bold text-on-surface-variant text-sm">{{ s.plan_name }}</p>
                                    <p class="text-[11px] text-outline">{{ s.court_name }}</p>
                                </div>
                            </div>
                            <div class="text-right shrink-0">
                                <span class="text-[10px] font-black bg-gray-100 text-on-surface-variant px-2 py-1 rounded-full">Cancelled</span>
                                <p class="text-[11px] text-outline mt-1">Access until {{ fmt(s.end_date) }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- ── Past / Expired ── -->
            <div v-if="past.length" class="px-4 mt-6">
                <p class="font-score text-[10px] font-bold text-outline uppercase tracking-[0.08em] mb-3">Expired</p>
                <div class="space-y-2">
                    <div v-for="s in past" :key="s.id"
                        class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 opacity-60">
                        <div class="flex items-center justify-between gap-3">
                            <div class="flex items-center gap-3">
                                <div class="w-9 h-9 rounded-xl bg-gray-100 flex items-center justify-center shrink-0">
                                    <Award :size="16" class="text-outline" />
                                </div>
                                <div>
                                    <p class="font-bold text-on-surface-variant text-sm">{{ s.plan_name }}</p>
                                    <p class="text-[11px] text-outline">{{ s.court_name }}</p>
                                </div>
                            </div>
                            <div class="text-right shrink-0">
                                <p class="text-[10px] font-bold text-outline">Expired</p>
                                <p class="text-[11px] font-bold text-on-surface-variant">{{ fmt(s.end_date) }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

        </template>
    </div>
</template>
