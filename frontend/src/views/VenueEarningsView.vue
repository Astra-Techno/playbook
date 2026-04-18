<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { TrendingUp, Loader2, CalendarDays, IndianRupee, Users, LayoutGrid, Download } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const courtId  = route.params.id
const loading  = ref(true)
const data     = ref(null)
const courtName = ref('')

onMounted(async () => {
    try {
        const [earningsRes, courtRes] = await Promise.all([
            axios.get(`/earnings/venue?court_id=${courtId}&owner_id=${auth.user?.id}`),
            axios.get(`/courts/${courtId}`)
        ])
        data.value      = earningsRes.data
        courtName.value = courtRes.data.court?.name ?? ''
    } catch (err) {
        toast.error('Failed to load earnings')
        router.replace(`/my-venues/${courtId}`)
    } finally {
        loading.value = false
    }
})

const fmtDate = (dt) => {
    const d = new Date(dt.replace(' ', 'T'))
    return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) +
           ' · ' + d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
}

const exporting = ref(false)

const exportCSV = async () => {
    exporting.value = true
    try {
        const url = `/api/earnings/export?court_id=${courtId}&owner_id=${auth.user?.id}`
        const res = await fetch(url, {
            headers: { Authorization: `Bearer ${auth.token}` }
        })
        if (!res.ok) throw new Error()
        const blob = await res.blob()
        const a = document.createElement('a')
        a.href = URL.createObjectURL(blob)
        a.download = `earnings_${new Date().toISOString().slice(0,10)}.csv`
        a.click()
        URL.revokeObjectURL(a.href)
    } catch { toast.error('Export failed') }
    finally { exporting.value = false }
}

const maxMonthly = computed(() => {
    if (!data.value?.monthly?.length) return 1
    return Math.max(...data.value.monthly.map(m => m.amount), 1)
})
</script>

<template>
    <Teleport to="#header-subject">{{ courtName || 'Earnings' }}</Teleport>
    <Teleport to="#header-subtitle">Earnings & Reports</Teleport>

    <div class="min-h-screen bg-slate-50 pb-10">

        <div v-if="loading" class="flex items-center justify-center h-64">
            <Loader2 :size="28" class="text-primary animate-spin" />
        </div>

        <template v-else-if="data">

            <!-- Summary cards -->
            <div class="bg-gradient-to-br from-primary to-blue-600 px-5 pt-5 pb-8">
                <p class="text-white/70 text-xs font-bold uppercase tracking-wider mb-3">Revenue Overview</p>
                <div class="grid grid-cols-2 gap-3">
                    <div class="bg-white/15 rounded-2xl px-4 py-3">
                        <p class="text-white/70 text-[10px] mb-1">Today</p>
                        <p class="text-white font-extrabold text-xl">₹{{ Number(data.summary.today).toLocaleString('en-IN') }}</p>
                    </div>
                    <div class="bg-white/15 rounded-2xl px-4 py-3">
                        <p class="text-white/70 text-[10px] mb-1">This Week</p>
                        <p class="text-white font-extrabold text-xl">₹{{ Number(data.summary.this_week).toLocaleString('en-IN') }}</p>
                    </div>
                    <div class="bg-white/15 rounded-2xl px-4 py-3">
                        <p class="text-white/70 text-[10px] mb-1">This Month</p>
                        <p class="text-white font-extrabold text-xl">₹{{ Number(data.summary.this_month).toLocaleString('en-IN') }}</p>
                    </div>
                    <div class="bg-white/20 rounded-2xl px-4 py-3 ring-1 ring-white/30">
                        <p class="text-white/70 text-[10px] mb-1">All Time</p>
                        <p class="text-white font-extrabold text-xl">₹{{ Number(data.summary.total).toLocaleString('en-IN') }}</p>
                    </div>
                </div>
            </div>

            <div class="-mt-4 px-4 space-y-4">

                <!-- Monthly bar chart -->
                <div class="bg-white rounded-2xl p-4 shadow-sm ring-1 ring-slate-100">
                    <p class="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-4">Monthly Breakdown</p>
                    <div class="flex items-end gap-2 h-28">
                        <div v-for="m in data.monthly" :key="m.month" class="flex-1 flex flex-col items-center gap-1">
                            <p class="text-[9px] font-bold text-slate-500">₹{{ m.amount >= 1000 ? (m.amount/1000).toFixed(1)+'k' : m.amount }}</p>
                            <div class="w-full rounded-t-md bg-primary/20 relative overflow-hidden"
                                :style="{ height: Math.max(4, (m.amount / maxMonthly) * 80) + 'px' }">
                                <div class="absolute inset-0 bg-primary"
                                    :style="{ opacity: m.amount > 0 ? 0.8 : 0 }"></div>
                            </div>
                            <p class="text-[9px] text-slate-400 text-center leading-tight">{{ m.month.slice(0, 3) }}</p>
                        </div>
                    </div>
                </div>

                <!-- Transactions list -->
                <div class="bg-white rounded-2xl shadow-sm ring-1 ring-slate-100 overflow-hidden">
                    <div class="px-4 pt-4 pb-2 flex items-center justify-between">
                        <div>
                            <p class="text-[11px] font-black text-slate-400 uppercase tracking-widest">Transactions</p>
                            <p class="text-xs text-slate-400 mt-0.5">Recent confirmed bookings</p>
                        </div>
                        <button @click="exportCSV" :disabled="exporting"
                            class="flex items-center gap-1.5 text-[11px] font-bold text-primary bg-primary/10 px-3 py-1.5 rounded-xl active:scale-95 transition-all disabled:opacity-50">
                            <Loader2 v-if="exporting" :size="12" class="animate-spin" />
                            <Download v-else :size="12" />
                            Export CSV
                        </button>
                    </div>

                    <div v-if="!data.transactions.length" class="px-4 pb-6 text-center py-8">
                        <IndianRupee :size="24" class="text-slate-200 mx-auto mb-2" />
                        <p class="text-sm text-slate-400">No transactions yet</p>
                    </div>

                    <div v-else class="divide-y divide-slate-50">
                        <div v-for="tx in data.transactions" :key="tx.id"
                            class="flex items-center gap-3 px-4 py-3">
                            <!-- Icon -->
                            <div class="w-9 h-9 rounded-xl shrink-0 flex items-center justify-center"
                                :class="tx.space_name ? 'bg-blue-50' : 'bg-primary/10'">
                                <LayoutGrid v-if="tx.space_name" :size="15" class="text-blue-500" />
                                <CalendarDays v-else :size="15" class="text-primary" />
                            </div>
                            <!-- Info -->
                            <div class="flex-1 min-w-0">
                                <p class="text-sm font-semibold text-slate-800 truncate">
                                    {{ tx.guest_name || tx.user_name || 'Walk-in' }}
                                </p>
                                <p class="text-[11px] text-slate-400 truncate">
                                    {{ tx.space_name ? tx.space_name + ' · ' : '' }}{{ fmtDate(tx.start_time) }}
                                </p>
                            </div>
                            <!-- Amount -->
                            <div class="shrink-0 text-right">
                                <p class="text-sm font-extrabold text-emerald-600">+₹{{ Number(tx.total_price).toLocaleString('en-IN') }}</p>
                            </div>
                        </div>
                    </div>
                </div>

            </div>
        </template>

    </div>
</template>
