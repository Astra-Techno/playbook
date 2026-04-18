<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { ArrowLeft, TrendingUp, TrendingDown, Wallet, IndianRupee, ArrowDownToLine, CalendarDays, Filter } from 'lucide-vue-next'

const router = useRouter()
const auth   = useAuthStore()

const loading  = ref(true)
const data     = ref(null)
const filter   = ref('all')       // all | booking | subscription | payout
const fromDate = ref('')
const toDate   = ref('')
const showFilters = ref(false)

const filterOptions = [
    { id: 'all',          label: 'All' },
    { id: 'booking',      label: 'Bookings' },
    { id: 'subscription', label: 'Memberships' },
    { id: 'payout',       label: 'Payouts' },
]

const fetchLedger = async () => {
    loading.value = true
    try {
        const params = new URLSearchParams({ owner_id: auth.user?.id, type: filter.value })
        if (fromDate.value) params.set('from', fromDate.value)
        if (toDate.value)   params.set('to',   toDate.value)
        const res = await axios.get(`/earnings/ledger?${params}`)
        data.value = res.data
    } catch {
        data.value = null
    } finally {
        loading.value = false
    }
}

onMounted(() => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    fetchLedger()
})

const applyFilters = () => {
    showFilters.value = false
    fetchLedger()
}

const resetFilters = () => {
    fromDate.value = ''
    toDate.value   = ''
    showFilters.value = false
    fetchLedger()
}

const fmt = (d) => new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
const fmtTime = (d) => new Date(d).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
const fmtAmt = (n) => Number(n).toLocaleString('en-IN')

const kindMeta = {
    booking:      { label: 'Booking',      bg: 'bg-primary-light',  text: 'text-primary',    icon: CalendarDays },
    subscription: { label: 'Membership',   bg: 'bg-violet-50',      text: 'text-violet-600', icon: Wallet },
    payout:       { label: 'Payout',       bg: 'bg-amber-50',       text: 'text-amber-600',  icon: ArrowDownToLine },
}

const hasDateFilter = computed(() => fromDate.value || toDate.value)
</script>

<template>
    <div class="min-h-full bg-slate-50">

        <!-- Header -->
        <div class="bg-white px-5 pt-5 pb-4 border-b border-slate-100 sticky top-0 z-10">
            <div class="flex items-center gap-3 mb-3">
                <button @click="router.back()"
                    class="w-9 h-9 rounded-full bg-slate-100 flex items-center justify-center shrink-0">
                    <ArrowLeft :size="20" :stroke-width="2.5" class="text-slate-600" />
                </button>
                <div class="flex-1">
                    <h1 class="text-lg font-bold text-slate-900">Ledger</h1>
                    <p class="text-xs text-slate-400">All credits & payouts</p>
                </div>
                <button @click="showFilters = !showFilters"
                    class="w-9 h-9 rounded-full flex items-center justify-center transition-colors"
                    :class="(hasDateFilter || filter !== 'all') ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'">
                    <Filter :size="16" />
                </button>
            </div>

            <!-- Filter type chips -->
            <div class="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
                <button v-for="opt in filterOptions" :key="opt.id"
                    @click="filter = opt.id; fetchLedger()"
                    :class="filter === opt.id ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'"
                    class="px-3 py-1.5 rounded-full text-xs font-bold shrink-0 transition-colors">
                    {{ opt.label }}
                </button>
            </div>
        </div>

        <!-- Date filter panel -->
        <Transition
            enter-active-class="transition duration-200 ease-out"
            enter-from-class="-translate-y-2 opacity-0"
            enter-to-class="translate-y-0 opacity-100"
            leave-active-class="transition duration-150 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="showFilters" class="bg-white px-5 py-4 border-b border-slate-100 space-y-3">
                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 mb-1">From</label>
                        <input v-model="fromDate" type="date" class="input-field text-sm" />
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 mb-1">To</label>
                        <input v-model="toDate" type="date" class="input-field text-sm" />
                    </div>
                </div>
                <div class="flex gap-2">
                    <button @click="resetFilters" class="btn-ghost flex-1 text-sm py-2">Reset</button>
                    <button @click="applyFilters" class="btn-primary flex-1 text-sm py-2">Apply</button>
                </div>
            </div>
        </Transition>

        <!-- Loading -->
        <div v-if="loading" class="px-5 pt-5 space-y-3">
            <div class="grid grid-cols-3 gap-3 mb-5">
                <div v-for="i in 3" :key="i" class="bg-white rounded-2xl p-4 animate-pulse ring-1 ring-slate-100">
                    <div class="h-3 bg-slate-200 rounded w-2/3 mb-2"></div>
                    <div class="h-5 bg-slate-200 rounded w-1/2"></div>
                </div>
            </div>
            <div v-for="i in 8" :key="i" class="bg-white rounded-xl p-4 animate-pulse ring-1 ring-slate-100 flex gap-3">
                <div class="w-10 h-10 rounded-full bg-slate-200 shrink-0"></div>
                <div class="flex-1">
                    <div class="h-3 bg-slate-200 rounded w-2/3 mb-2"></div>
                    <div class="h-3 bg-slate-200 rounded w-1/2"></div>
                </div>
                <div class="w-16 h-4 bg-slate-200 rounded self-center"></div>
            </div>
        </div>

        <template v-else-if="data">
            <!-- Summary strip -->
            <div class="grid grid-cols-3 gap-3 px-5 pt-5 mb-5">
                <div class="bg-white rounded-2xl p-3 text-center ring-1 ring-slate-100 shadow-sm">
                    <div class="flex items-center justify-center gap-1 mb-1">
                        <TrendingUp :size="12" class="text-emerald-500" />
                        <p class="text-[10px] font-semibold text-slate-400">Credits</p>
                    </div>
                    <p class="text-base font-extrabold text-emerald-600">₹{{ fmtAmt(data.totals.credits) }}</p>
                </div>
                <div class="bg-white rounded-2xl p-3 text-center ring-1 ring-slate-100 shadow-sm">
                    <div class="flex items-center justify-center gap-1 mb-1">
                        <TrendingDown :size="12" class="text-amber-500" />
                        <p class="text-[10px] font-semibold text-slate-400">Paid Out</p>
                    </div>
                    <p class="text-base font-extrabold text-amber-600">₹{{ fmtAmt(data.totals.debits) }}</p>
                </div>
                <div class="bg-primary rounded-2xl p-3 text-center shadow-sm">
                    <div class="flex items-center justify-center gap-1 mb-1">
                        <IndianRupee :size="12" class="text-white/70" />
                        <p class="text-[10px] font-semibold text-white/70">Balance</p>
                    </div>
                    <p class="text-base font-extrabold text-white">₹{{ fmtAmt(data.totals.balance) }}</p>
                </div>
            </div>

            <!-- Entry count -->
            <p class="px-5 text-xs text-slate-400 font-medium mb-3">
                {{ data.entries.length }} {{ data.entries.length === 1 ? 'entry' : 'entries' }}
                <span v-if="hasDateFilter"> · filtered</span>
            </p>

            <!-- Ledger entries -->
            <div v-if="data.entries.length === 0"
                class="mx-5 text-center py-16 bg-white rounded-2xl ring-1 ring-slate-100">
                <IndianRupee :size="36" class="text-slate-200 mx-auto mb-3" />
                <p class="font-semibold text-slate-500">No entries found</p>
                <p class="text-xs text-slate-400 mt-1">Try changing the filter or date range</p>
            </div>

            <div v-else class="px-5 space-y-2">
                <div v-for="entry in data.entries" :key="entry.kind + entry.id"
                    class="bg-white rounded-xl ring-1 ring-slate-100 shadow-sm overflow-hidden">
                    <div class="flex items-center gap-3 p-4">
                        <!-- Icon -->
                        <div class="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                            :class="kindMeta[entry.kind]?.bg || 'bg-slate-100'">
                            <component :is="kindMeta[entry.kind]?.icon || IndianRupee"
                                :size="16"
                                :class="kindMeta[entry.kind]?.text || 'text-slate-600'" />
                        </div>

                        <!-- Details -->
                        <div class="flex-1 min-w-0">
                            <div class="flex items-center gap-2">
                                <p class="font-semibold text-sm text-slate-800 truncate">{{ entry.party }}</p>
                                <span class="text-[10px] font-bold px-1.5 py-0.5 rounded-full shrink-0"
                                    :class="(kindMeta[entry.kind]?.bg || 'bg-slate-100') + ' ' + (kindMeta[entry.kind]?.text || 'text-slate-600')">
                                    {{ kindMeta[entry.kind]?.label }}
                                </span>
                            </div>
                            <p class="text-xs text-slate-400 truncate">{{ entry.label }}</p>
                            <p class="text-[10px] text-slate-300 mt-0.5">{{ fmt(entry.dated) }} · {{ fmtTime(entry.dated) }}</p>
                        </div>

                        <!-- Amount + balance -->
                        <div class="text-right shrink-0">
                            <p class="font-bold text-sm"
                                :class="entry.direction === 'credit' ? 'text-emerald-600' : 'text-amber-600'">
                                {{ entry.direction === 'credit' ? '+' : '−' }}₹{{ fmtAmt(entry.amount) }}
                            </p>
                            <p class="text-[10px] text-slate-400 mt-0.5">bal ₹{{ fmtAmt(entry.balance) }}</p>
                        </div>
                    </div>
                </div>
            </div>
        </template>

        <!-- Error -->
        <div v-else class="px-5 pt-10 text-center text-slate-400 text-sm">
            Failed to load ledger.
            <button @click="fetchLedger" class="block mx-auto mt-3 text-primary font-bold">Retry</button>
        </div>

    </div>
</template>
