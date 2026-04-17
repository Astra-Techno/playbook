<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    Pencil, LayoutGrid, Users, Ban, Trash2, TrendingUp,
    MapPin, ChevronRight, Star, Flame, Loader2, X, IndianRupee, UserCheck, ShieldCheck
} from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const court         = ref(null)
const loading       = ref(true)
const deleteLoading = ref(false)
const earnings      = ref(null)

onMounted(async () => {
    try {
        const res = await axios.get(`/courts/${route.params.id}`)
        court.value = res.data.court ?? res.data
        // Load earnings in background
        axios.get(`/earnings/venue?court_id=${route.params.id}&owner_id=${auth.user?.id}`)
            .then(r => { earnings.value = r.data.summary })
            .catch(() => {})
    } catch {
        toast.error('Failed to load venue')
        router.replace('/my-venues')
    } finally {
        loading.value = false
    }
})

// Is the logged-in user the owner of this venue?
const isVenueOwner = computed(() => court.value && String(court.value.owner_id) === String(auth.user?.id))

const deleteCourt = async () => {
    if (!confirm(`Delete "${court.value.name}"? This cannot be undone.`)) return
    deleteLoading.value = true
    try {
        await axios.delete(`/courts/${court.value.id}`)
        toast.success('Venue deleted')
        router.replace('/my-venues')
    } catch {
        toast.error('Delete failed')
    } finally {
        deleteLoading.value = false
    }
}

const menuGroups = computed(() => {
    const vid = route.params.id
    const manage = []
    const ops = []

    if (isVenueOwner.value) manage.push({ label: 'Edit Venue', desc: 'Update name, location, rate & amenities', icon: Pencil, to: `/my-venues/${vid}/edit` })
    manage.push({ label: 'Spaces', desc: 'Manage courts, lanes, tables, rooms', icon: LayoutGrid, to: `/my-venues/${vid}/spaces` })

    if (isVenueOwner.value) ops.push({ label: 'Staff', desc: 'Manage staff and permissions', icon: Users, to: `/my-venues/${vid}/staff` })
    ops.push({ label: 'Members', desc: 'All active subscribers for this venue', icon: UserCheck, to: `/my-venues/${vid}/members` })
    ops.push({ label: 'Block Slots', desc: 'Block the entire venue for a period', icon: Ban, to: `/my-venues/${vid}/block` })
    ops.push({ label: 'Earnings', desc: 'Revenue, reports & transaction history', icon: TrendingUp, to: `/my-venues/${vid}/earnings` })

    return [
        { group: 'Manage', items: manage },
        { group: 'Operations', items: ops },
    ]
})
</script>

<template>
    <div class="min-h-screen bg-slate-50">

        <!-- Loading -->
        <div v-if="loading" class="flex items-center justify-center h-64">
            <Loader2 :size="28" class="text-primary animate-spin" />
        </div>

        <template v-else-if="court">
            <!-- Hero image -->
            <div class="relative h-56 w-full bg-slate-200">
                <img v-if="court.image_url" :src="court.image_url"
                    class="w-full h-full object-cover"
                    onerror="this.style.display='none'" />
                <div v-else class="w-full h-full flex items-center justify-center bg-slate-100">
                    <LayoutGrid :size="56" :stroke-width="1.5" class="text-slate-300" />
                </div>
                <button @click="router.back()"
                    class="absolute top-5 left-4 w-9 h-9 rounded-full bg-white/90 backdrop-blur flex items-center justify-center shadow-sm">
                    <ChevronRight :size="18" class="text-slate-700 rotate-180" />
                </button>
                <div class="absolute bottom-3 left-4 bg-primary text-white text-[10px] font-bold px-2.5 py-1.5 rounded-lg flex items-center gap-1 shadow-lg shadow-primary/30 tracking-wider">
                    <Flame :size="10" :stroke-width="3" />
                    POPULAR
                </div>
            </div>

            <!-- Venue info card -->
            <div class="mx-4 -mt-4 relative z-10 bg-white rounded-2xl p-4 shadow-sm ring-1 ring-slate-100 mb-5">
                <div v-if="court.claim_status === 'pending'" class="mb-3 flex items-center gap-2 bg-amber-50 border border-amber-100 rounded-xl px-3 py-2">
                    <Loader2 :size="12" class="text-amber-500 animate-spin shrink-0" />
                    <p class="text-xs font-bold text-amber-700">Pending admin verification · not visible to players yet</p>
                </div>
                <div v-else-if="court.claim_status === 'rejected'" class="mb-3 flex items-center gap-2 bg-red-50 border border-red-100 rounded-xl px-3 py-2">
                    <X :size="12" class="text-red-500 shrink-0" />
                    <p class="text-xs font-bold text-red-600">Claim rejected · please contact support</p>
                </div>

                <div class="flex items-start justify-between mb-1">
                    <h1 class="text-xl font-bold text-slate-900">{{ court.name }}</h1>
                    <div class="flex items-center gap-1 bg-amber-50 px-2 py-1 rounded-lg text-amber-700 font-bold text-[11px] border border-amber-100/50">
                        <Star :size="11" :stroke-width="2.5" class="fill-amber-500 text-amber-500" />
                        4.8
                    </div>
                </div>
                <div class="flex items-center gap-1.5 text-slate-500 text-sm mb-3">
                    <MapPin :size="12" :stroke-width="2.5" class="text-slate-400" />
                    <span>{{ court.location || 'Location not set' }}</span>
                </div>
                <div class="flex items-end justify-between">
                    <div>
                        <span class="text-xs text-slate-400 font-medium block">Starting at</span>
                        <span class="text-primary font-bold text-xl">₹{{ court.hourly_rate }}<span class="text-sm font-normal text-slate-500">/hr</span></span>
                    </div>
                    <div class="flex items-center gap-2">
                        <div v-if="!isVenueOwner" class="flex items-center gap-1 bg-amber-50 border border-amber-100 text-amber-700 text-[10px] font-bold px-2.5 py-1.5 rounded-full">
                            <ShieldCheck :size="11" />
                            Staff Access
                        </div>
                        <button v-if="isVenueOwner" @click="router.push(`/my-venues/${court.id}/edit`)"
                            class="text-xs font-bold text-primary bg-primary-light px-3 py-1.5 rounded-full">
                            Edit
                        </button>
                    </div>
                </div>
            </div>

            <!-- Earnings summary card -->
            <div v-if="earnings" class="mx-4 mb-5 cursor-pointer"
                @click="router.push(`/my-venues/${court.id}/earnings`)">
                <div class="bg-gradient-to-r from-primary to-blue-600 rounded-2xl p-4 text-white shadow-lg shadow-primary/30">
                    <div class="flex items-center justify-between mb-3">
                        <div class="flex items-center gap-2">
                            <TrendingUp :size="16" />
                            <span class="text-sm font-bold opacity-90">Earnings</span>
                        </div>
                        <div class="flex items-center gap-1 text-xs font-bold opacity-75">
                            View Report <ChevronRight :size="13" />
                        </div>
                    </div>
                    <div class="grid grid-cols-3 gap-3">
                        <div>
                            <p class="text-[10px] opacity-70 mb-0.5">Today</p>
                            <p class="text-base font-extrabold">₹{{ Number(earnings.today).toLocaleString('en-IN') }}</p>
                        </div>
                        <div>
                            <p class="text-[10px] opacity-70 mb-0.5">This Month</p>
                            <p class="text-base font-extrabold">₹{{ Number(earnings.this_month).toLocaleString('en-IN') }}</p>
                        </div>
                        <div>
                            <p class="text-[10px] opacity-70 mb-0.5">All Time</p>
                            <p class="text-base font-extrabold">₹{{ Number(earnings.total).toLocaleString('en-IN') }}</p>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Menu groups -->
            <div class="px-4 pb-8 space-y-5">
                <div v-for="group in menuGroups" :key="group.group">
                    <p class="text-[11px] font-bold text-slate-400 uppercase tracking-widest mb-2 px-1">{{ group.group }}</p>
                    <div class="bg-white rounded-2xl overflow-hidden divide-y divide-slate-50" style="box-shadow:0 1px 6px rgba(0,0,0,0.06)">
                        <button
                            v-for="item in group.items"
                            :key="item.label"
                            @click="router.push(item.to)"
                            class="w-full flex items-center gap-3 px-4 py-3.5 hover:bg-slate-50 active:bg-slate-100 transition-colors">
                            <div class="w-9 h-9 bg-slate-100 rounded-xl flex items-center justify-center shrink-0">
                                <component :is="item.icon" :size="17" class="text-slate-600" />
                            </div>
                            <div class="flex-1 text-left">
                                <p class="text-sm font-semibold text-slate-800">{{ item.label }}</p>
                                <p class="text-xs text-slate-400">{{ item.desc }}</p>
                            </div>
                            <ChevronRight :size="15" class="text-slate-300" />
                        </button>
                    </div>
                </div>

                <!-- Delete — owner only -->
                <div v-if="isVenueOwner" class="bg-white rounded-2xl overflow-hidden" style="box-shadow:0 1px 6px rgba(0,0,0,0.06)">
                    <button @click="deleteCourt" :disabled="deleteLoading"
                        class="w-full flex items-center gap-3 px-4 py-4 hover:bg-red-50 active:bg-red-100 transition-colors disabled:opacity-50">
                        <div class="w-9 h-9 bg-red-100 rounded-xl flex items-center justify-center shrink-0">
                            <Trash2 v-if="!deleteLoading" :size="17" class="text-red-500" />
                            <Loader2 v-else :size="17" class="text-red-400 animate-spin" />
                        </div>
                        <span class="flex-1 text-sm font-bold text-red-600 text-left">Delete Venue</span>
                    </button>
                </div>
            </div>
        </template>
    </div>
</template>
