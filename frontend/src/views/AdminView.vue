<script setup>
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    MapPin, Users, Star, ChevronDown, ChevronUp, ChevronRight, ChevronLeft,
    Phone, Globe, CheckCircle2, Loader2, TrendingUp,
    Building2, Filter, X, ShieldCheck, UserCheck, BarChart2
} from 'lucide-vue-next'

const auth  = useAuthStore()
const toast = useToastStore()

// ── Section navigation ────────────────────────────────────────────
const section = ref('home')   // 'home' | 'demand' | 'users' | 'verification'

// ── Demand Signals ────────────────────────────────────────────────
const places       = ref([])
const placesLoaded = ref(false)
const loading      = ref(false)
const expandedId   = ref(null)
const contactingId = ref(null)

const filterStatus = ref('all')
const filterType   = ref('all')
const filterCity   = ref('all')

const typeOptions = [
    { value: 'all',     label: 'All types' },
    { value: 'shuttle', label: 'Badminton' },
    { value: 'turf',    label: 'Football'  },
    { value: 'gym',     label: 'Gym'       },
    { value: 'cricket', label: 'Cricket'   },
    { value: 'tennis',  label: 'Tennis'    },
    { value: 'swimming',label: 'Swimming'  },
    { value: 'basket',  label: 'Basketball'},
    { value: 'boxing',  label: 'Boxing'    },
    { value: 'dance',   label: 'Dance'     },
    { value: 'yoga',    label: 'Yoga'      },
    { value: 'martial', label: 'Martial'   },
    { value: 'golf',    label: 'Golf'      },
    { value: 'bowling', label: 'Bowling'   },
    { value: 'other',   label: 'Other'     },
]

const extractCity = (address) => {
    if (!address) return ''
    const parts = address.split(',').map(s => s.trim()).filter(s => s && s.toLowerCase() !== 'india')
    for (let i = parts.length - 1; i >= 0; i--) {
        const p = parts[i]
        if (!/\d/.test(p) && p.length > 2) return p
    }
    return parts[0] || ''
}

const cityOptions = computed(() =>
    [...new Set(places.value.map(p => extractCity(p.address)).filter(Boolean))].sort()
)

const filtered = computed(() => places.value.filter(p => {
    if (filterStatus.value !== 'all' && p.status !== filterStatus.value) return false
    if (filterType.value   !== 'all' && p.type   !== filterType.value)   return false
    if (filterCity.value   !== 'all' && extractCity(p.address) !== filterCity.value) return false
    return true
}))

const totalPlaces    = computed(() => places.value.length)
const totalRequests  = computed(() => places.value.reduce((s, p) => s + (parseInt(p.request_count) || 0), 0))
const contactedCount = computed(() => places.value.filter(p => p.status === 'contacted').length)
const activeFilters  = computed(() =>
    (filterStatus.value !== 'all' ? 1 : 0) +
    (filterType.value   !== 'all' ? 1 : 0) +
    (filterCity.value   !== 'all' ? 1 : 0)
)

const typeLabel = (t) => typeOptions.find(o => o.value === t)?.label || 'Other'

const fetchDemand = async () => {
    if (placesLoaded.value) return
    loading.value = true
    try {
        const res = await axios.get(`/admin/demand?admin_id=${auth.user.id}`)
        places.value = res.data.places || []
        placesLoaded.value = true
    } catch {
        toast.error('Failed to load demand data')
    } finally {
        loading.value = false
    }
}

const markContacted = async (place) => {
    if (contactingId.value === place.id) return
    contactingId.value = place.id
    try {
        await axios.put(`/admin/places/${place.id}/contact`, { admin_id: auth.user.id })
        place.status = 'contacted'
        toast.success(`${place.name} marked as contacted`)
    } catch {
        toast.error('Could not update status')
    } finally {
        contactingId.value = null
    }
}

// ── Users ─────────────────────────────────────────────────────────
const users        = ref([])
const usersLoaded  = ref(false)
const usersLoading = ref(false)
const userSearch   = ref('')

const filteredUsers = computed(() => {
    const q = userSearch.value.toLowerCase()
    if (!q) return users.value
    return users.value.filter(u =>
        u.name?.toLowerCase().includes(q) ||
        u.phone?.includes(q) ||
        u.role?.includes(q)
    )
})

const fetchUsers = async () => {
    if (usersLoaded.value) return
    usersLoading.value = true
    try {
        const res = await axios.get(`/admin/users?admin_id=${auth.user.id}`)
        users.value = res.data.users || []
        usersLoaded.value = true
    } catch {
        toast.error('Failed to load users')
    } finally {
        usersLoading.value = false
    }
}

// ── Court verification ────────────────────────────────────────────
const allCourts     = ref([])
const courtsLoaded  = ref(false)
const courtsLoading = ref(false)
const verifyingId   = ref(null)

const fetchAllCourts = async () => {
    if (courtsLoaded.value) return
    courtsLoading.value = true
    try {
        const res = await axios.get('/courts')
        allCourts.value = res.data.records || []
        courtsLoaded.value = true
    } catch { allCourts.value = [] }
    finally { courtsLoading.value = false }
}

const toggleVerify = async (court) => {
    verifyingId.value = court.id
    const newVal = court.is_verified ? 0 : 1
    try {
        await axios.put(`/courts/${court.id}/verify`, { admin_id: auth.user.id, is_verified: newVal })
        court.is_verified = !!newVal
        toast.success(newVal ? 'Court verified!' : 'Verification removed')
    } catch { toast.error('Could not update verification') }
    finally { verifyingId.value = null }
}

// ── Navigate to section ───────────────────────────────────────────
const goTo = (s) => {
    section.value = s
    if (s === 'demand')       fetchDemand()
    if (s === 'users')        fetchUsers()
    if (s === 'verification') fetchAllCourts()
}

const roleBadge = { admin: 'bg-primary-light text-primary', owner: 'bg-amber-50 text-amber-700', player: 'bg-slate-100 text-slate-600' }

onMounted(() => fetchDemand()) // pre-load demand for stats
</script>

<template>
    <div class="min-h-screen bg-slate-50 pb-32">

        <!-- ── HOME ── -->
        <template v-if="section === 'home'">
            <!-- Admin card -->
            <div class="mx-4 mt-4 bg-white rounded-2xl p-5 shadow-sm ring-1 ring-slate-100">
                <div class="flex items-center gap-4">
                    <div class="w-14 h-14 rounded-2xl bg-primary flex items-center justify-center shrink-0">
                        <ShieldCheck :size="26" class="text-white" />
                    </div>
                    <div>
                        <h2 class="text-base font-extrabold text-slate-900">{{ auth.user?.name }}</h2>
                        <p class="text-sm text-slate-400">{{ auth.user?.phone }}</p>
                        <span class="mt-1 inline-block text-[10px] font-black bg-primary text-white px-2.5 py-0.5 rounded-full uppercase tracking-wider">Admin</span>
                    </div>
                </div>
            </div>

            <!-- Stats row -->
            <div class="px-4 pt-3 pb-1 grid grid-cols-3 gap-2">
                <div class="bg-white rounded-2xl p-3 text-center ring-1 ring-slate-100 shadow-sm">
                    <p class="text-2xl font-black text-slate-800">{{ totalPlaces }}</p>
                    <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-0.5">Venues</p>
                </div>
                <div class="bg-white rounded-2xl p-3 text-center ring-1 ring-slate-100 shadow-sm">
                    <p class="text-2xl font-black text-primary">{{ totalRequests }}</p>
                    <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-0.5">Requests</p>
                </div>
                <div class="bg-white rounded-2xl p-3 text-center ring-1 ring-slate-100 shadow-sm">
                    <p class="text-2xl font-black text-amber-500">{{ contactedCount }}</p>
                    <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-0.5">Contacted</p>
                </div>
            </div>

            <!-- Menu -->
            <div class="px-4 pt-3 space-y-3">
                <p class="text-[11px] font-bold text-slate-400 uppercase tracking-widest px-1">Manage</p>
                <div class="bg-white rounded-2xl overflow-hidden ring-1 ring-slate-100 shadow-sm divide-y divide-slate-50">
                    <button @click="goTo('demand')"
                        class="w-full flex items-center gap-3 px-4 py-4 hover:bg-slate-50 active:bg-slate-100 transition-colors">
                        <div class="w-9 h-9 bg-primary-light rounded-xl flex items-center justify-center shrink-0">
                            <TrendingUp :size="17" class="text-primary" />
                        </div>
                        <div class="flex-1 text-left">
                            <p class="text-sm font-semibold text-slate-800">Demand Signals</p>
                            <p class="text-[11px] text-slate-400">{{ totalPlaces }} venues · {{ contactedCount }} contacted</p>
                        </div>
                        <ChevronRight :size="16" class="text-slate-300" />
                    </button>
                    <button @click="goTo('users')"
                        class="w-full flex items-center gap-3 px-4 py-4 hover:bg-slate-50 active:bg-slate-100 transition-colors">
                        <div class="w-9 h-9 bg-amber-50 rounded-xl flex items-center justify-center shrink-0">
                            <Users :size="17" class="text-amber-600" />
                        </div>
                        <div class="flex-1 text-left">
                            <p class="text-sm font-semibold text-slate-800">Users</p>
                            <p class="text-[11px] text-slate-400">All registered users</p>
                        </div>
                        <ChevronRight :size="16" class="text-slate-300" />
                    </button>
                    <button @click="goTo('verification')"
                        class="w-full flex items-center gap-3 px-4 py-4 hover:bg-slate-50 active:bg-slate-100 transition-colors">
                        <div class="w-9 h-9 bg-emerald-50 rounded-xl flex items-center justify-center shrink-0">
                            <CheckCircle2 :size="17" class="text-emerald-600" />
                        </div>
                        <div class="flex-1 text-left">
                            <p class="text-sm font-semibold text-slate-800">Court Verification</p>
                            <p class="text-[11px] text-slate-400">Verify listed courts</p>
                        </div>
                        <ChevronRight :size="16" class="text-slate-300" />
                    </button>
                </div>
            </div>
        </template>

        <!-- ── Sub-section header (shared) ── -->
        <template v-if="section !== 'home'">
            <div class="sticky top-0 z-30 bg-white border-b border-slate-100 px-4 py-3.5 flex items-center gap-3"
                style="box-shadow:0 1px 6px rgba(0,0,0,0.06)">
                <button @click="section = 'home'"
                    class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center active:scale-90 transition-transform shrink-0">
                    <ChevronLeft :size="20" class="text-slate-600" />
                </button>
                <h1 class="flex-1 font-extrabold text-slate-900 text-base">
                    {{ section === 'demand' ? 'Demand Signals' : section === 'users' ? 'Users' : 'Court Verification' }}
                </h1>
            </div>
        </template>

        <!-- ── DEMAND SIGNALS ── -->
        <template v-if="section === 'demand'">
            <!-- Filter bar -->
            <div class="px-4 pt-3 pb-1 space-y-2">
                <div class="flex items-center gap-2">
                    <span v-if="activeFilters" class="text-[10px] font-black bg-primary text-white px-1.5 py-0.5 rounded-full">{{ activeFilters }}</span>
                    <span class="text-[10px] text-slate-400 font-medium ml-auto">{{ filtered.length }} venues</span>
                </div>
                <div class="flex gap-2">
                    <button v-for="s in [['all','All'],['pending','Pending'],['contacted','Contacted']]" :key="s[0]"
                        @click="filterStatus = s[0]"
                        class="text-[11px] font-bold px-3 py-1.5 rounded-full border transition-all"
                        :class="filterStatus === s[0] ? 'bg-primary text-white border-primary' : 'bg-white text-slate-500 border-slate-200'">
                        {{ s[1] }}
                    </button>
                    <div class="ml-auto relative">
                        <select v-model="filterType"
                            class="text-[11px] font-bold pl-7 pr-3 py-1.5 rounded-full border border-slate-200 bg-white text-slate-600 appearance-none cursor-pointer focus:outline-none focus:border-primary">
                            <option v-for="o in typeOptions" :key="o.value" :value="o.value">{{ o.label }}</option>
                        </select>
                        <Filter :size="11" class="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
                    </div>
                </div>
                <!-- City chips -->
                <div v-if="cityOptions.length > 1" class="flex gap-2 overflow-x-auto scrollbar-hide pb-0.5">
                    <button @click="filterCity = 'all'"
                        class="shrink-0 text-[11px] font-bold px-3 py-1.5 rounded-full border transition-all"
                        :class="filterCity === 'all' ? 'bg-primary text-white border-primary' : 'bg-white text-slate-500 border-slate-200'">
                        All Cities
                    </button>
                    <button v-for="city in cityOptions" :key="city" @click="filterCity = city"
                        class="shrink-0 flex items-center gap-1 text-[11px] font-bold px-3 py-1.5 rounded-full border transition-all"
                        :class="filterCity === city ? 'bg-primary text-white border-primary' : 'bg-white text-slate-500 border-slate-200'">
                        <MapPin :size="9" />{{ city }}
                    </button>
                </div>
            </div>

            <div v-if="loading" class="space-y-3 px-4 pt-2">
                <div v-for="i in 4" :key="i" class="bg-white rounded-2xl p-4 animate-pulse ring-1 ring-slate-100">
                    <div class="flex gap-3">
                        <div class="w-16 h-16 rounded-xl bg-slate-200 shrink-0"></div>
                        <div class="flex-1 space-y-2">
                            <div class="h-4 bg-slate-200 rounded w-3/5"></div>
                            <div class="h-3 bg-slate-200 rounded w-4/5"></div>
                        </div>
                    </div>
                </div>
            </div>

            <div v-else-if="filtered.length === 0" class="flex flex-col items-center py-20 text-center px-8">
                <Building2 :size="28" class="text-slate-300 mb-3" />
                <p class="font-bold text-slate-600">No venues found</p>
                <button v-if="activeFilters" @click="filterStatus='all'; filterType='all'; filterCity='all'"
                    class="mt-3 text-xs font-bold text-primary flex items-center gap-1">
                    <X :size="12" /> Clear filters
                </button>
            </div>

            <div v-else class="px-4 pt-2 space-y-3">
                <div v-for="place in filtered" :key="place.id"
                    class="bg-white rounded-2xl ring-1 ring-slate-100 shadow-sm overflow-hidden">
                    <div class="flex gap-3 p-4 pb-3">
                        <div class="w-16 h-16 rounded-xl overflow-hidden shrink-0 bg-slate-100">
                            <img :src="place.image_url" class="w-full h-full object-cover" loading="lazy"
                                onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=200&q=60'" />
                        </div>
                        <div class="flex-1 min-w-0">
                            <div class="flex items-start justify-between gap-2">
                                <h3 class="font-extrabold text-slate-900 text-sm leading-tight flex-1">{{ place.name }}</h3>
                                <span class="shrink-0 text-[9px] font-black px-2 py-1 rounded-full uppercase tracking-wider"
                                    :class="place.status === 'contacted' ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-500'">
                                    {{ place.status === 'contacted' ? 'Contacted' : 'Pending' }}
                                </span>
                            </div>
                            <div class="flex items-center gap-1 text-slate-400 text-[11px] mt-0.5">
                                <MapPin :size="10" class="shrink-0" />
                                <span class="truncate">{{ place.address }}</span>
                            </div>
                            <div class="flex items-center gap-2 mt-1.5">
                                <span v-if="extractCity(place.address)"
                                    class="text-[10px] font-bold bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full flex items-center gap-1">
                                    <MapPin :size="9" class="text-primary" />{{ extractCity(place.address) }}
                                </span>
                            </div>
                            <div class="flex items-center gap-3 mt-1.5">
                                <span class="text-[10px] font-bold bg-primary/5 text-primary px-2 py-0.5 rounded-full">{{ typeLabel(place.type) }}</span>
                                <span v-if="place.rating" class="flex items-center gap-1 text-[10px] font-bold text-amber-600">
                                    <Star :size="10" class="fill-amber-400 text-amber-400" />{{ place.rating }}
                                </span>
                                <span class="flex items-center gap-1 text-[10px] font-bold text-primary ml-auto">
                                    <Users :size="10" />{{ parseInt(place.request_count) || 0 }} interested
                                </span>
                            </div>
                        </div>
                    </div>
                    <div class="mx-4 mb-3 rounded-xl bg-slate-50 px-3 py-2.5 space-y-1.5">
                        <p class="text-[9px] font-black text-slate-400 uppercase tracking-widest">Venue Contact</p>
                        <div v-if="place.phone" class="flex items-center gap-2">
                            <Phone :size="11" class="text-green-500 shrink-0" />
                            <a :href="`tel:${place.phone}`" class="text-[12px] font-bold text-slate-700">{{ place.phone }}</a>
                            <a :href="`tel:${place.phone}`" class="ml-auto text-[10px] font-bold bg-green-500 text-white px-2.5 py-1 rounded-lg">Call</a>
                        </div>
                        <p v-else class="text-[11px] text-slate-400 italic">No phone on Google Maps</p>
                        <div v-if="place.website" class="flex items-center gap-2">
                            <Globe :size="11" class="text-blue-500 shrink-0" />
                            <a :href="place.website" target="_blank" rel="noopener" class="text-[11px] font-semibold text-blue-600 truncate hover:underline">
                                {{ place.website.replace(/^https?:\/\/(www\.)?/, '') }}
                            </a>
                        </div>
                    </div>
                    <div class="flex items-center gap-2 px-4 pb-3">
                        <button v-if="place.status !== 'contacted'"
                            @click="markContacted(place)" :disabled="contactingId === place.id"
                            class="flex items-center gap-1.5 text-xs font-bold bg-primary text-white px-4 py-2 rounded-xl active:scale-95 disabled:opacity-60 transition-all">
                            <Loader2 v-if="contactingId === place.id" :size="12" class="animate-spin" />
                            <Phone v-else :size="12" />
                            Mark Contacted
                        </button>
                        <div v-else class="flex items-center gap-1.5 text-xs font-bold text-amber-600 bg-amber-50 px-4 py-2 rounded-xl">
                            <CheckCircle2 :size="12" />Contacted
                        </div>
                        <button v-if="place.requesters?.length"
                            @click="expandedId = expandedId === place.id ? null : place.id"
                            class="flex items-center gap-1 text-xs font-bold text-slate-500 ml-auto px-3 py-2 rounded-xl hover:bg-slate-50">
                            <Users :size="12" />{{ place.requesters.length }} {{ place.requesters.length === 1 ? 'person' : 'people' }}
                            <ChevronDown v-if="expandedId !== place.id" :size="14" />
                            <ChevronUp   v-else                          :size="14" />
                        </button>
                    </div>
                    <Transition enter-active-class="transition duration-200 ease-out" enter-from-class="opacity-0 -translate-y-1" enter-to-class="opacity-100 translate-y-0" leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
                        <div v-if="expandedId === place.id && place.requesters?.length" class="border-t border-slate-50 px-4 pb-3 pt-2 space-y-2">
                            <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">Interested Users</p>
                            <div v-for="(user, i) in place.requesters" :key="i" class="flex items-center gap-3 py-2 border-b border-slate-50 last:border-0">
                                <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                    <span class="text-[10px] font-extrabold text-primary">{{ user.name ? user.name[0].toUpperCase() : '?' }}</span>
                                </div>
                                <div class="flex-1 min-w-0">
                                    <p class="text-sm font-bold text-slate-800 truncate">{{ user.name || 'Unknown' }}</p>
                                    <p class="text-[11px] text-slate-400">{{ user.phone || 'No phone' }}</p>
                                </div>
                                <a v-if="user.phone" :href="`tel:${user.phone}`" class="w-8 h-8 rounded-full bg-green-50 flex items-center justify-center text-green-600">
                                    <Phone :size="14" />
                                </a>
                            </div>
                        </div>
                    </Transition>
                </div>
            </div>
        </template>

        <!-- ── USERS ── -->
        <template v-if="section === 'users'">
            <div class="px-4 pt-3">
                <input v-model="userSearch" type="search" placeholder="Search by name or phone..."
                    class="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 mb-3" />

                <div v-if="usersLoading" class="space-y-2">
                    <div v-for="i in 5" :key="i" class="bg-white rounded-xl p-4 animate-pulse ring-1 ring-slate-100">
                        <div class="flex gap-3 items-center">
                            <div class="w-10 h-10 rounded-full bg-slate-200 shrink-0"></div>
                            <div class="flex-1 space-y-1.5">
                                <div class="h-3.5 bg-slate-200 rounded w-2/5"></div>
                                <div class="h-3 bg-slate-200 rounded w-1/3"></div>
                            </div>
                        </div>
                    </div>
                </div>

                <div v-else-if="filteredUsers.length === 0" class="text-center py-16 text-slate-400">
                    <Users :size="32" class="mx-auto mb-3 text-slate-200" />
                    <p class="text-sm font-semibold">No users found</p>
                </div>

                <div v-else class="space-y-2">
                    <div v-for="user in filteredUsers" :key="user.id"
                        class="bg-white rounded-xl px-4 py-3 ring-1 ring-slate-100 flex items-center gap-3">
                        <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                            <img v-if="user.avatar_url" :src="user.avatar_url" class="w-full h-full object-cover rounded-full" />
                            <span v-else class="text-sm font-extrabold text-primary">{{ user.name?.[0]?.toUpperCase() || '?' }}</span>
                        </div>
                        <div class="flex-1 min-w-0">
                            <p class="font-bold text-sm text-slate-800 truncate">{{ user.name || 'No name' }}</p>
                            <p class="text-[11px] text-slate-400">{{ user.phone }}</p>
                        </div>
                        <span class="text-[10px] font-bold px-2.5 py-1 rounded-full capitalize shrink-0"
                            :class="roleBadge[user.role] || 'bg-slate-100 text-slate-500'">
                            {{ user.role }}
                        </span>
                    </div>
                </div>
            </div>
        </template>

        <!-- ── COURT VERIFICATION ── -->
        <template v-if="section === 'verification'">
            <div class="px-4 pt-3">
                <div v-if="courtsLoading" class="text-center py-10 text-slate-400 text-sm">Loading courts…</div>
                <div v-else class="space-y-2">
                    <div v-for="court in allCourts" :key="court.id"
                        class="bg-white rounded-xl p-4 ring-1 ring-slate-100 flex items-center gap-3">
                        <div class="flex-1 min-w-0">
                            <p class="font-bold text-sm text-slate-800 truncate">{{ court.name }}</p>
                            <p class="text-xs text-slate-400 truncate">{{ court.location || 'No location' }}</p>
                        </div>
                        <button @click="toggleVerify(court)" :disabled="verifyingId === court.id"
                            class="shrink-0 flex items-center gap-1.5 text-xs font-bold px-3 py-2 rounded-xl transition-all"
                            :class="court.is_verified ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'">
                            <Loader2 v-if="verifyingId === court.id" :size="12" class="animate-spin" />
                            <CheckCircle2 v-else :size="12" />
                            {{ court.is_verified ? 'Verified' : 'Verify' }}
                        </button>
                    </div>
                </div>
            </div>
        </template>

    </div>
</template>
