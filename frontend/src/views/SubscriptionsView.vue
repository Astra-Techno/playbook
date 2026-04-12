<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { useNotificationsStore } from '../stores/notifications'
import { Award, MapPin, ChevronRight, AlertTriangle, RefreshCw, X } from 'lucide-vue-next'

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
        const res  = await axios.get(`/subscriptions?user_id=${auth.user.id}`)
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
    <div class="min-h-screen bg-slate-50 pb-28">

        <!-- Loading -->
        <div v-if="loading" class="p-5 space-y-3">
            <div v-for="i in 3" :key="i" class="bg-white rounded-2xl p-4 animate-pulse h-28"></div>
        </div>

        <!-- Error -->
        <div v-else-if="error" class="flex flex-col items-center justify-center py-24 px-8 text-center">
            <p class="font-bold text-slate-500 mb-4">Could not load memberships</p>
            <button @click="fetchSubs" class="text-sm font-bold text-primary">Retry</button>
        </div>

        <!-- Empty -->
        <div v-else-if="subs.length === 0" class="flex flex-col items-center justify-center py-28 px-8 text-center">
            <div class="w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center mb-5">
                <Award :size="36" class="text-primary" />
            </div>
            <p class="font-black text-slate-800 text-lg mb-2">No memberships yet</p>
            <p class="text-sm text-slate-400 mb-6">Subscribe to a court plan to unlock member benefits.</p>
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
                    <AlertTriangle :size="18" class="text-amber-500 shrink-0 mt-0.5" />
                    <div class="flex-1 min-w-0">
                        <p class="text-sm font-black text-amber-800">
                            {{ s.plan_name }} expires in {{ daysLeft(s.end_date) }} day{{ daysLeft(s.end_date) === 1 ? '' : 's' }}
                        </p>
                        <p class="text-xs text-amber-600 mt-0.5">{{ s.court_name }} · {{ fmt(s.end_date) }}</p>
                    </div>
                    <button @click="router.push(`/courts/${s.court_id}`)"
                        class="shrink-0 flex items-center gap-1 text-[11px] font-black text-amber-700 bg-amber-100 px-3 py-1.5 rounded-full active:scale-95 transition-transform">
                        <RefreshCw :size="11" />
                        Renew
                    </button>
                </div>
            </div>

            <!-- ── Active ── -->
            <div v-if="active.length" class="px-4 pt-5">
                <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Active</p>
                <div class="space-y-3">
                    <div v-for="s in active" :key="s.id"
                        class="bg-white rounded-2xl p-4 shadow-sm"
                        :class="isExpiringSoon(s.end_date) ? 'ring-1 ring-amber-300' : 'ring-1 ring-primary/20'">

                        <div class="flex items-start justify-between gap-3">
                            <div class="flex items-center gap-3">
                                <div class="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                                    :class="isExpiringSoon(s.end_date) ? 'bg-amber-100' : 'bg-primary/10'">
                                    <Award :size="20" :class="isExpiringSoon(s.end_date) ? 'text-amber-500' : 'text-primary'" />
                                </div>
                                <div>
                                    <p class="font-black text-slate-900 text-sm leading-tight">{{ s.plan_name }}</p>
                                    <div class="flex items-center gap-1 mt-0.5">
                                        <MapPin :size="10" class="text-slate-400" />
                                        <p class="text-[11px] font-bold text-slate-500">{{ s.court_name }}</p>
                                    </div>
                                </div>
                            </div>
                            <span class="text-[10px] font-black px-2.5 py-1 rounded-full shrink-0"
                                :class="isExpiringSoon(s.end_date) ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700'">
                                {{ isExpiringSoon(s.end_date) ? 'Expiring soon' : 'Active' }}
                            </span>
                        </div>

                        <div class="mt-4 grid grid-cols-3 gap-2 text-center">
                            <div class="bg-slate-50 rounded-xl py-2.5">
                                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-0.5">Slot</p>
                                <p class="text-xs font-black text-slate-800">{{ slotLabel(s.slot_type) }}</p>
                            </div>
                            <div class="bg-slate-50 rounded-xl py-2.5">
                                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-0.5">Expires</p>
                                <p class="text-xs font-black text-slate-800">{{ fmt(s.end_date) }}</p>
                            </div>
                            <div class="rounded-xl py-2.5"
                                :class="isExpiringSoon(s.end_date) ? 'bg-amber-50' : 'bg-primary/10'">
                                <p class="text-[10px] font-bold uppercase tracking-wider mb-0.5"
                                    :class="isExpiringSoon(s.end_date) ? 'text-amber-500' : 'text-primary/60'">Days left</p>
                                <p class="text-xs font-black"
                                    :class="isExpiringSoon(s.end_date) ? 'text-amber-600' : 'text-primary'">
                                    {{ daysLeft(s.end_date) }}
                                </p>
                            </div>
                        </div>

                        <div class="mt-3 flex gap-2">
                            <button @click="router.push(`/courts/${s.court_id}`)"
                                class="flex-1 flex items-center justify-between text-xs font-bold text-primary bg-primary/5 rounded-xl px-4 py-2.5 active:scale-[0.98] transition-transform">
                                <span>{{ isExpiringSoon(s.end_date) ? 'Renew Now' : 'View Court' }}</span>
                                <ChevronRight :size="14" />
                            </button>
                            <button @click="cancelSub(s)"
                                :disabled="cancellingId === s.id"
                                class="w-10 h-10 rounded-xl bg-red-50 flex items-center justify-center text-red-400 hover:text-red-600 active:scale-95 transition-all disabled:opacity-40">
                                <X :size="16" />
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- ── Cancelled (still within access period) ── -->
            <div v-if="cancelled.length" class="px-4 mt-6">
                <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Cancelled</p>
                <div class="space-y-2">
                    <div v-for="s in cancelled" :key="s.id"
                        class="bg-white rounded-2xl p-4 ring-1 ring-slate-100">
                        <div class="flex items-center justify-between gap-3">
                            <div class="flex items-center gap-3">
                                <div class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center shrink-0">
                                    <Award :size="16" class="text-slate-400" />
                                </div>
                                <div>
                                    <p class="font-bold text-slate-700 text-sm">{{ s.plan_name }}</p>
                                    <p class="text-[11px] text-slate-400">{{ s.court_name }}</p>
                                </div>
                            </div>
                            <div class="text-right shrink-0">
                                <span class="text-[10px] font-black bg-slate-100 text-slate-500 px-2 py-1 rounded-full">Cancelled</span>
                                <p class="text-[11px] text-slate-400 mt-1">Access until {{ fmt(s.end_date) }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- ── Past / Expired ── -->
            <div v-if="past.length" class="px-4 mt-6">
                <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Expired</p>
                <div class="space-y-2">
                    <div v-for="s in past" :key="s.id"
                        class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 opacity-60">
                        <div class="flex items-center justify-between gap-3">
                            <div class="flex items-center gap-3">
                                <div class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center shrink-0">
                                    <Award :size="16" class="text-slate-400" />
                                </div>
                                <div>
                                    <p class="font-bold text-slate-700 text-sm">{{ s.plan_name }}</p>
                                    <p class="text-[11px] text-slate-400">{{ s.court_name }}</p>
                                </div>
                            </div>
                            <div class="text-right shrink-0">
                                <p class="text-[10px] font-bold text-slate-400">Expired</p>
                                <p class="text-[11px] font-bold text-slate-500">{{ fmt(s.end_date) }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

        </template>
    </div>
</template>
