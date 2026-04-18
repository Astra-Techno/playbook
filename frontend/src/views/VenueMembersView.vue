<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import { UserCheck, Loader2, Phone, Calendar, Award, X, Search } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const toast  = useToastStore()

const venueId  = route.params.id
const members  = ref([])
const loading  = ref(true)
const search   = ref('')
const cancellingId = ref(null)

onMounted(async () => {
    try {
        const res = await axios.get(`/subscriptions/members?court_id=${venueId}`)
        members.value = res.data.members || []
    } catch {
        toast.error('Failed to load members')
    } finally {
        loading.value = false
    }
})

const filtered = computed(() => {
    if (!search.value.trim()) return members.value
    const q = search.value.toLowerCase()
    return members.value.filter(m =>
        m.user_name?.toLowerCase().includes(q) ||
        m.plan_name?.toLowerCase().includes(q) ||
        m.user_phone?.includes(q)
    )
})

const daysLeft = (endDate) => Math.ceil((new Date(endDate) - new Date()) / (1000 * 60 * 60 * 24))
const fmtDate  = (d) => new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })

const cancelSub = async (sub) => {
    if (!confirm(`Cancel ${sub.user_name}'s membership?`)) return
    cancellingId.value = sub.id
    try {
        await axios.put(`/subscriptions/${sub.id}/cancel`)
        members.value = members.value.filter(m => m.id !== sub.id)
        toast.success('Membership cancelled')
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to cancel')
    } finally {
        cancellingId.value = null
    }
}
</script>

<template>
    <Teleport to="#header-subject">Members</Teleport>
    <Teleport to="#header-subtitle">Members</Teleport>

    <div class="min-h-full bg-slate-50">
        <!-- Header -->
        <div class="bg-white px-5 pt-5 pb-4 border-b border-slate-100">
            <div class="flex items-center justify-between mb-3">
                <div>
                    <h1 class="text-lg font-bold text-slate-900">All Members</h1>
                    <p class="text-xs text-slate-500">Active subscribers across all spaces</p>
                </div>
                <div v-if="!loading" class="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center">
                    <span class="text-primary font-extrabold text-sm">{{ members.length }}</span>
                </div>
            </div>
            <!-- Search -->
            <div class="relative">
                <Search :size="14" class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input v-model="search" type="text" placeholder="Search by name, plan or phone…"
                    class="w-full bg-slate-50 border border-slate-200 rounded-xl pl-8 pr-3 py-2.5 text-sm placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-primary/30" />
            </div>
        </div>

        <div class="px-4 py-4 pb-8">
            <div v-if="loading" class="space-y-2">
                <div v-for="i in 5" :key="i" class="h-20 bg-white rounded-2xl animate-pulse ring-1 ring-slate-100"></div>
            </div>

            <div v-else-if="!filtered.length" class="flex flex-col items-center justify-center py-16 text-center">
                <div class="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mb-3">
                    <UserCheck :size="26" class="text-slate-300" />
                </div>
                <p class="font-semibold text-slate-700">{{ search ? 'No matching members' : 'No active members' }}</p>
                <p class="text-xs text-slate-400 mt-1">{{ search ? 'Try a different search' : 'Members who subscribe to space plans will appear here' }}</p>
            </div>

            <div v-else class="space-y-2">
                <div v-for="m in filtered" :key="m.id"
                    class="bg-white rounded-2xl px-4 py-3.5 shadow-sm ring-1 ring-slate-100">
                    <div class="flex items-start gap-3">
                        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0 font-extrabold text-primary text-sm">
                            {{ (m.user_name || '?').charAt(0).toUpperCase() }}
                        </div>
                        <div class="flex-1 min-w-0">
                            <p class="text-sm font-bold text-slate-800 truncate">{{ m.user_name }}</p>
                            <div class="flex items-center gap-1 text-[11px] text-slate-400 mt-0.5">
                                <Award :size="10" />
                                <span>{{ m.plan_name }}</span>
                                <span class="text-slate-300">·</span>
                                <span class="font-semibold text-primary">₹{{ m.plan_price }}</span>
                            </div>
                            <div class="flex items-center gap-3 mt-1.5 flex-wrap">
                                <div class="flex items-center gap-1 text-[10px] text-slate-400">
                                    <Calendar :size="10" />
                                    <span>Expires {{ fmtDate(m.end_date) }}</span>
                                </div>
                                <span class="text-[10px] font-bold px-2 py-0.5 rounded-full"
                                    :class="daysLeft(m.end_date) <= 7  ? 'bg-red-50 text-red-500' :
                                            daysLeft(m.end_date) <= 30 ? 'bg-amber-50 text-amber-600' :
                                            'bg-emerald-50 text-emerald-600'">
                                    {{ daysLeft(m.end_date) > 0 ? daysLeft(m.end_date) + 'd left' : 'Expired' }}
                                </span>
                            </div>
                        </div>
                        <div class="shrink-0 flex flex-col items-end gap-2">
                            <a v-if="m.user_phone" :href="`tel:${m.user_phone}`"
                                class="w-8 h-8 rounded-xl bg-slate-50 flex items-center justify-center">
                                <Phone :size="13" class="text-slate-400" />
                            </a>
                            <button @click="cancelSub(m)" :disabled="cancellingId === m.id"
                                class="w-8 h-8 rounded-xl bg-red-50 flex items-center justify-center active:scale-90 transition">
                                <Loader2 v-if="cancellingId === m.id" :size="13" class="animate-spin text-red-400" />
                                <X v-else :size="13" class="text-red-400" />
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>
