<script setup>
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    MapPin, Users, Star, ChevronDown, ChevronUp,
    Phone, Globe, CheckCircle2, Loader2, TrendingUp,
    Building2, Filter, X
} from 'lucide-vue-next'

const auth  = useAuthStore()
const toast = useToastStore()

const places       = ref([])
const loading      = ref(true)
const expandedId   = ref(null)
const contactingId = ref(null)

// Filters
const filterStatus = ref('all')   // all | pending | contacted
const filterType   = ref('all')

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

const filtered = computed(() => places.value.filter(p => {
    if (filterStatus.value !== 'all' && p.status !== filterStatus.value) return false
    if (filterType.value   !== 'all' && p.type   !== filterType.value)   return false
    return true
}))

// Stats — parseInt to avoid PHP string + JS number concat bug
const totalPlaces    = computed(() => places.value.length)
const totalRequests  = computed(() => places.value.reduce((s, p) => s + (parseInt(p.request_count) || 0), 0))
const contactedCount = computed(() => places.value.filter(p => p.status === 'contacted').length)

const activeFilters = computed(() => (filterStatus.value !== 'all' ? 1 : 0) + (filterType.value !== 'all' ? 1 : 0))

const typeLabel = (t) => typeOptions.find(o => o.value === t)?.label || 'Other'

const fetchDemand = async () => {
    loading.value = true
    try {
        const res = await axios.get(`/admin/demand?admin_id=${auth.user.id}`)
        places.value = res.data.places || []
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

onMounted(fetchDemand)
</script>

<template>
    <div class="min-h-screen bg-slate-50 pb-28">

        <!-- Stats row -->
        <div class="px-4 pt-4 pb-2 grid grid-cols-3 gap-2">
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

        <!-- Filter bar -->
        <div class="px-4 pt-3 pb-1 space-y-2">
            <!-- Row 1: header + active filter count -->
            <div class="flex items-center gap-2">
                <TrendingUp :size="16" class="text-primary" />
                <h2 class="text-sm font-black text-slate-700 uppercase tracking-wide">Demand Signals</h2>
                <span v-if="activeFilters" class="ml-1 text-[10px] font-black bg-primary text-white px-1.5 py-0.5 rounded-full">
                    {{ activeFilters }}
                </span>
                <span class="text-[10px] text-slate-400 font-medium ml-auto">{{ filtered.length }} venues</span>
            </div>

            <!-- Row 2: status pills -->
            <div class="flex gap-2">
                <button v-for="s in [['all','All'],['pending','Pending'],['contacted','Contacted']]"
                    :key="s[0]"
                    @click="filterStatus = s[0]"
                    class="text-[11px] font-bold px-3 py-1.5 rounded-full border transition-all"
                    :class="filterStatus === s[0]
                        ? 'bg-primary text-white border-primary'
                        : 'bg-white text-slate-500 border-slate-200'">
                    {{ s[1] }}
                </button>
                <!-- Type select -->
                <div class="ml-auto relative">
                    <select v-model="filterType"
                        class="text-[11px] font-bold pl-7 pr-3 py-1.5 rounded-full border border-slate-200 bg-white text-slate-600 appearance-none cursor-pointer focus:outline-none focus:border-primary">
                        <option v-for="o in typeOptions" :key="o.value" :value="o.value">{{ o.label }}</option>
                    </select>
                    <Filter :size="11" class="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
                </div>
            </div>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="space-y-3 px-4 pt-2">
            <div v-for="i in 4" :key="i" class="bg-white rounded-2xl p-4 animate-pulse ring-1 ring-slate-100">
                <div class="flex gap-3">
                    <div class="w-16 h-16 rounded-xl bg-slate-200 shrink-0"></div>
                    <div class="flex-1 space-y-2">
                        <div class="h-4 bg-slate-200 rounded w-3/5"></div>
                        <div class="h-3 bg-slate-200 rounded w-4/5"></div>
                        <div class="h-3 bg-slate-200 rounded w-2/5"></div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Empty -->
        <div v-else-if="filtered.length === 0" class="flex flex-col items-center py-20 text-center px-8">
            <div class="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mb-4">
                <Building2 :size="28" class="text-slate-400" />
            </div>
            <p class="font-bold text-slate-600">No venues found</p>
            <p class="text-sm text-slate-400 mt-1">Try changing the filters.</p>
            <button v-if="activeFilters" @click="filterStatus='all'; filterType='all'"
                class="mt-3 text-xs font-bold text-primary flex items-center gap-1">
                <X :size="12" /> Clear filters
            </button>
        </div>

        <!-- Place cards -->
        <div v-else class="px-4 pt-2 space-y-3">
            <div v-for="place in filtered" :key="place.id"
                class="bg-white rounded-2xl ring-1 ring-slate-100 shadow-sm overflow-hidden">

                <!-- Card header -->
                <div class="flex gap-3 p-4 pb-3">
                    <div class="w-16 h-16 rounded-xl overflow-hidden shrink-0 bg-slate-100">
                        <img :src="place.image_url" class="w-full h-full object-cover" loading="lazy"
                            onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=200&q=60'" />
                    </div>

                    <div class="flex-1 min-w-0">
                        <div class="flex items-start justify-between gap-2">
                            <h3 class="font-extrabold text-slate-900 text-sm leading-tight flex-1">{{ place.name }}</h3>
                            <span class="shrink-0 text-[9px] font-black px-2 py-1 rounded-full uppercase tracking-wider"
                                :class="place.status === 'contacted'
                                    ? 'bg-amber-100 text-amber-700'
                                    : 'bg-slate-100 text-slate-500'">
                                {{ place.status === 'contacted' ? 'Contacted' : 'Pending' }}
                            </span>
                        </div>

                        <div class="flex items-center gap-1 text-slate-400 text-[11px] mt-1">
                            <MapPin :size="10" class="shrink-0" />
                            <span class="truncate">{{ place.address }}</span>
                        </div>

                        <div class="flex items-center gap-3 mt-2">
                            <span class="text-[10px] font-bold bg-primary/5 text-primary px-2 py-0.5 rounded-full">
                                {{ typeLabel(place.type) }}
                            </span>
                            <span v-if="place.rating" class="flex items-center gap-1 text-[10px] font-bold text-amber-600">
                                <Star :size="10" class="fill-amber-400 text-amber-400" />
                                {{ place.rating }}
                            </span>
                            <span class="flex items-center gap-1 text-[10px] font-bold text-primary ml-auto">
                                <Users :size="10" />
                                {{ parseInt(place.request_count) || 0 }} interested
                            </span>
                        </div>
                    </div>
                </div>

                <!-- Venue contact details -->
                <div class="mx-4 mb-3 rounded-xl bg-slate-50 px-3 py-2.5 space-y-1.5">
                    <p class="text-[9px] font-black text-slate-400 uppercase tracking-widest">Venue Contact</p>
                    <div v-if="place.phone" class="flex items-center gap-2">
                        <Phone :size="11" class="text-green-500 shrink-0" />
                        <a :href="`tel:${place.phone}`"
                            class="text-[12px] font-bold text-slate-700 hover:text-primary transition-colors">
                            {{ place.phone }}
                        </a>
                        <a :href="`tel:${place.phone}`"
                            class="ml-auto text-[10px] font-bold bg-green-500 text-white px-2.5 py-1 rounded-lg active:scale-95 transition-transform">
                            Call
                        </a>
                    </div>
                    <p v-else class="text-[11px] text-slate-400 italic">No phone on Google Maps</p>

                    <div v-if="place.website" class="flex items-center gap-2">
                        <Globe :size="11" class="text-blue-500 shrink-0" />
                        <a :href="place.website" target="_blank" rel="noopener"
                            class="text-[11px] font-semibold text-blue-600 truncate hover:underline">
                            {{ place.website.replace(/^https?:\/\/(www\.)?/, '') }}
                        </a>
                    </div>
                </div>

                <!-- Action row -->
                <div class="flex items-center gap-2 px-4 pb-3">
                    <button v-if="place.status !== 'contacted'"
                        @click="markContacted(place)"
                        :disabled="contactingId === place.id"
                        class="flex items-center gap-1.5 text-xs font-bold bg-primary text-white px-4 py-2 rounded-xl active:scale-95 disabled:opacity-60 transition-all">
                        <Loader2 v-if="contactingId === place.id" :size="12" class="animate-spin" />
                        <Phone v-else :size="12" />
                        Mark Contacted
                    </button>
                    <div v-else class="flex items-center gap-1.5 text-xs font-bold text-amber-600 bg-amber-50 px-4 py-2 rounded-xl">
                        <CheckCircle2 :size="12" />
                        Contacted
                    </div>

                    <button v-if="place.requesters?.length"
                        @click="expandedId = expandedId === place.id ? null : place.id"
                        class="flex items-center gap-1 text-xs font-bold text-slate-500 hover:text-primary ml-auto active:scale-95 transition-all px-3 py-2 rounded-xl hover:bg-slate-50">
                        <Users :size="12" />
                        {{ place.requesters.length }} {{ place.requesters.length === 1 ? 'person' : 'people' }}
                        <ChevronDown v-if="expandedId !== place.id" :size="14" />
                        <ChevronUp   v-else                          :size="14" />
                    </button>
                    <span v-else class="text-xs text-slate-300 ml-auto px-3 py-2">No requests yet</span>
                </div>

                <!-- Expanded interested users -->
                <Transition
                    enter-active-class="transition duration-200 ease-out"
                    enter-from-class="opacity-0 -translate-y-1"
                    enter-to-class="opacity-100 translate-y-0"
                    leave-active-class="transition duration-150"
                    leave-from-class="opacity-100"
                    leave-to-class="opacity-0">
                    <div v-if="expandedId === place.id && place.requesters?.length"
                        class="border-t border-slate-50 px-4 pb-3 pt-2 space-y-2">
                        <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">Interested Users</p>
                        <div v-for="(user, i) in place.requesters" :key="i"
                            class="flex items-center gap-3 py-2 border-b border-slate-50 last:border-0">
                            <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                <span class="text-[10px] font-extrabold text-primary">
                                    {{ user.name ? user.name[0].toUpperCase() : '?' }}
                                </span>
                            </div>
                            <div class="flex-1 min-w-0">
                                <p class="text-sm font-bold text-slate-800 truncate">{{ user.name || 'Unknown' }}</p>
                                <p class="text-[11px] text-slate-400">{{ user.phone || 'No phone' }}</p>
                            </div>
                            <a v-if="user.phone" :href="`tel:${user.phone}`"
                                class="w-8 h-8 rounded-full bg-green-50 flex items-center justify-center text-green-600 active:scale-90 transition-transform">
                                <Phone :size="14" />
                            </a>
                        </div>
                    </div>
                </Transition>

            </div>
        </div>
    </div>
</template>
