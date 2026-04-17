<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { CalendarCheck, Loader2, ChevronRight, X } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const venueId = route.params.id
const spaceId = route.params.spaceId

const space    = ref(null)
const bookings = ref([])
const loading  = ref(true)
const tab      = ref('upcoming')  // 'upcoming' | 'past'

onMounted(async () => {
    try {
        const [spaceRes, bookingsRes] = await Promise.all([
            axios.get(`/sub-courts/${spaceId}`),
            axios.get(`/bookings?owner_id=${auth.user.id}&sub_court_id=${spaceId}`)
        ])
        space.value    = spaceRes.data.space
        bookings.value = bookingsRes.data.records || []
    } catch {
        toast.error('Failed to load bookings')
    } finally {
        loading.value = false
    }
})

const now = new Date()

const upcoming = computed(() =>
    bookings.value.filter(b => new Date(b.start_time) >= now && b.status !== 'cancelled')
)
const past = computed(() =>
    bookings.value.filter(b => new Date(b.start_time) < now || b.status === 'cancelled')
)
const displayed = computed(() => tab.value === 'upcoming' ? upcoming.value : past.value)

const formatTime = (dt) => {
    const d = new Date(dt.replace(' ', 'T'))
    return d.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' }) +
           ' · ' + d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
}

const cancelBooking = async (id) => {
    if (!confirm('Cancel this booking?')) return
    try {
        await axios.delete(`/bookings/${id}`, { data: { user_id: auth.user.id } })
        toast.success('Booking cancelled')
        const res = await axios.get(`/bookings?owner_id=${auth.user.id}&sub_court_id=${spaceId}`)
        bookings.value = res.data.records || []
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to cancel')
    }
}
</script>

<template>
    <Teleport to="#header-subject">{{ space?.name || 'Bookings' }}</Teleport>
    <Teleport to="#header-subtitle">{{ space?.name ? space.name + ' · Bookings' : 'Bookings' }}</Teleport>

    <div class="min-h-screen bg-slate-50">
        <!-- Header -->
        <div class="bg-white px-5 pt-5 pb-4 border-b border-slate-100">
            <h1 class="text-lg font-bold text-slate-900">Bookings</h1>
            <p class="text-xs text-slate-500 mb-3">{{ space?.name || 'Space' }} bookings</p>
            <!-- Tabs -->
            <div class="flex gap-1 bg-slate-100 rounded-xl p-1">
                <button @click="tab = 'upcoming'"
                    class="flex-1 py-1.5 rounded-lg text-xs font-bold transition-all"
                    :class="tab === 'upcoming' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500'">
                    Upcoming
                    <span v-if="upcoming.length" class="ml-1 bg-primary text-white px-1.5 py-0.5 rounded-full text-[10px]">
                        {{ upcoming.length }}
                    </span>
                </button>
                <button @click="tab = 'past'"
                    class="flex-1 py-1.5 rounded-lg text-xs font-bold transition-all"
                    :class="tab === 'past' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500'">
                    Past
                </button>
            </div>
        </div>

        <div class="px-4 py-4 pb-8">
            <div v-if="loading" class="space-y-2">
                <div v-for="i in 4" :key="i" class="h-16 bg-white rounded-xl animate-pulse ring-1 ring-slate-100"></div>
            </div>

            <div v-else-if="!displayed.length" class="flex flex-col items-center justify-center py-16 text-center">
                <div class="w-14 h-14 bg-slate-100 rounded-full flex items-center justify-center mb-3">
                    <CalendarCheck :size="24" class="text-slate-300" />
                </div>
                <p class="font-semibold text-slate-700">No {{ tab }} bookings</p>
                <p class="text-xs text-slate-400 mt-1">{{ tab === 'upcoming' ? 'No upcoming bookings for this space' : 'No past bookings found' }}</p>
            </div>

            <div v-else class="space-y-2">
                <div v-for="b in displayed" :key="b.id"
                    class="bg-white rounded-2xl px-4 py-3.5 shadow-sm ring-1 ring-slate-100">
                    <div class="flex items-start gap-3">
                        <div class="w-9 h-9 bg-primary/10 rounded-xl flex items-center justify-center shrink-0">
                            <CalendarCheck :size="17" class="text-primary" />
                        </div>
                        <div class="flex-1 min-w-0">
                            <p class="text-sm font-bold text-slate-800 truncate">
                                {{ b.guest_name || b.user_name || 'Player' }}
                            </p>
                            <p class="text-xs text-slate-500">{{ formatTime(b.start_time) }}</p>
                            <p v-if="b.guest_phone" class="text-[11px] text-slate-400">{{ b.guest_phone }}</p>
                        </div>
                        <div class="text-right shrink-0">
                            <p class="text-sm font-extrabold text-emerald-600">₹{{ b.total_price }}</p>
                            <span class="text-[10px] font-bold px-2 py-0.5 rounded-full"
                                :class="b.status === 'confirmed' ? 'bg-emerald-50 text-emerald-600' : 'bg-slate-100 text-slate-400'">
                                {{ b.status }}
                            </span>
                        </div>
                    </div>
                    <!-- Cancel button for upcoming confirmed -->
                    <div v-if="b.status === 'confirmed' && new Date(b.start_time) >= now"
                        class="mt-2.5 pt-2.5 border-t border-slate-50 flex justify-end">
                        <button @click="cancelBooking(b.id)"
                            class="flex items-center gap-1 text-xs font-semibold text-red-400 hover:text-red-600 transition-colors">
                            <X :size="12" /> Cancel
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>
