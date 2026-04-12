<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    MapPin, Users, Star, ChevronDown, ChevronUp,
    Phone, CheckCircle2, Clock, Loader2, TrendingUp, Building2
} from 'lucide-vue-next'

const auth   = useAuthStore()
const toast  = useToastStore()
const router = useRouter()

const places       = ref([])
const loading      = ref(true)
const expandedId   = ref(null)
const contactingId = ref(null)

// Stats
const totalPlaces    = computed(() => places.value.length)
const totalRequests  = computed(() => places.value.reduce((s, p) => s + (p.request_count || 0), 0))
const contactedCount = computed(() => places.value.filter(p => p.status === 'contacted').length)

const typeLabel = (t) => ({
    shuttle: 'Badminton', turf: 'Football', gym: 'Gym', cricket: 'Cricket',
    tennis: 'Tennis', swimming: 'Swimming', basket: 'Basketball', boxing: 'Boxing',
}[t] || 'Other')

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
        <div class="px-4 pt-4 pb-2 grid grid-cols-3 gap-3">
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

        <!-- Section header -->
        <div class="px-4 pt-3 pb-2 flex items-center gap-2">
            <TrendingUp :size="16" class="text-primary" />
            <h2 class="text-sm font-black text-slate-700 uppercase tracking-wide">Demand Signals</h2>
            <span class="text-[10px] text-slate-400 font-medium ml-auto">Sorted by interest</span>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="space-y-3 px-4">
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
        <div v-else-if="places.length === 0" class="flex flex-col items-center py-20 text-center px-8">
            <div class="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mb-4">
                <Building2 :size="28" class="text-slate-400" />
            </div>
            <p class="font-bold text-slate-600">No demand signals yet</p>
            <p class="text-sm text-slate-400 mt-1">Players haven't requested any ghost venues near registered courts yet.</p>
        </div>

        <!-- Place cards -->
        <div v-else class="px-4 space-y-3">
            <div v-for="place in places" :key="place.id"
                class="bg-white rounded-2xl ring-1 ring-slate-100 shadow-sm overflow-hidden">

                <!-- Card header -->
                <div class="flex gap-3 p-4">
                    <!-- Thumbnail -->
                    <div class="w-16 h-16 rounded-xl overflow-hidden shrink-0 bg-slate-100">
                        <img :src="place.image_url" class="w-full h-full object-cover" loading="lazy"
                            onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=200&q=60'" />
                    </div>

                    <!-- Info -->
                    <div class="flex-1 min-w-0">
                        <div class="flex items-start justify-between gap-2">
                            <h3 class="font-extrabold text-slate-900 text-sm leading-tight truncate flex-1">{{ place.name }}</h3>
                            <!-- Status badge -->
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
                            <!-- Type -->
                            <span class="text-[10px] font-bold bg-primary/5 text-primary px-2 py-0.5 rounded-full">
                                {{ typeLabel(place.type) }}
                            </span>
                            <!-- Rating -->
                            <span v-if="place.rating" class="flex items-center gap-1 text-[10px] font-bold text-amber-600">
                                <Star :size="10" class="fill-amber-400 text-amber-400" />
                                {{ place.rating }}
                            </span>
                            <!-- Request count -->
                            <span class="flex items-center gap-1 text-[10px] font-bold text-primary ml-auto">
                                <Users :size="10" />
                                {{ place.request_count || 0 }} interested
                            </span>
                        </div>
                    </div>
                </div>

                <!-- Action row -->
                <div class="flex items-center gap-2 px-4 pb-3">
                    <!-- Mark contacted -->
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

                    <!-- Expand interested users -->
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

                <!-- Expanded user list -->
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
