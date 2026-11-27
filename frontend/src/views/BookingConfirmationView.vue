<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { CheckCircle2, CalendarDays, Clock, MapPin, Hash, Loader2 } from 'lucide-vue-next'
import KoCard from '../components/KoCard.vue'
import JerseyRow from '../components/JerseyRow.vue'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { sportTint } from '../utils/sport'

const route  = useRoute()
const router = useRouter()

const booking  = ref(null)
const loading  = ref(true)
const notFound = ref(false)
const auth  = useAuthStore()
const toast = useToastStore()

// Matchday squad (same as the app's pass): GET /booking-players → players + open_match.
const squad = ref([])
const openMatch = ref(null)
const askSpots = ref(0) // > 0 while the "Need players" stepper is open
const isBooker = computed(() => booking.value && String(booking.value.user_id) === String(auth.user?.id))
const live = computed(() => booking.value?.status === 'confirmed')
const players = computed(() => squad.value.length + 1)
const openSpots = computed(() => Number(openMatch.value?.spots_left || 0))
const perHead = computed(() => {
    const total = Number(booking.value?.total_price || 0)
    return total > 0 ? Math.ceil(total / (players.value + openSpots.value)) : null
})
const bookerName = computed(() => (isBooker.value ? (auth.user?.name || 'You') : (booking.value?.user_name || 'Booker')))
const squadNote = computed(() => [
    perHead.value != null ? `₹${perHead.value} each` : null,
    openSpots.value > 0 ? `${openSpots.value} spot${openSpots.value === 1 ? '' : 's'} open` : null,
].filter(Boolean).join(' · ') || null)

const loadSquad = async () => {
    try {
        const res = await axios.get('/booking-players', { params: { booking_id: route.params.bookingId } })
        squad.value = res.data.players || []
        openMatch.value = res.data.open_match || null
    } catch { /* the pass works without the squad */ }
}

const inviteText = () => {
    const b = booking.value
    const where = [b.court_name, b.court_location].filter(Boolean).join(', ')
    return [
        `Game on: ${b.court_name}${b.space_name ? ` (${b.space_name})` : ''}`,
        `${fmtDate(b.start_time)} · ${fmtTime(b.start_time)} – ${fmtTime(b.end_time)}`,
        [`${players.value} in${openSpots.value > 0 ? `, ${openSpots.value} spot${openSpots.value === 1 ? '' : 's'} open` : ''}`, perHead.value != null ? `₹${perHead.value} each` : null].filter(Boolean).join(' · '),
        `Map: https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(where)}`,
        `Join on KoCourt: https://www.kocourt.com/court/${b.court_id}`,
    ].join('\n')
}
const whatsappUrl = computed(() => (booking.value ? `https://wa.me/?text=${encodeURIComponent(inviteText())}` : '#'))

const postOpenSpots = async () => {
    try {
        await axios.post('/match-requests', { booking_id: booking.value.id, players_needed: askSpots.value })
        toast.success('Posted to Matches')
        askSpots.value = 0
        loadSquad()
    } catch (e) {
        toast.error(e.response?.data?.message || 'Could not post this game.')
    }
}

const parseLocal = (dt) => { const [d, t] = String(dt).split(' '); return new Date(`${d}T${t || '00:00:00'}`) }
const fmtDate = (dt) => parseLocal(dt).toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const fmtTime = (dt) => parseLocal(dt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })

onMounted(async () => {
    try {
        const res = await axios.get(`/bookings/${route.params.bookingId}`)
        booking.value = res.data.booking
        loadSquad()
    } catch {
        notFound.value = true
    } finally {
        loading.value = false
    }
})
</script>

<template>
    <div class="min-h-full bg-white flex flex-col items-center justify-start pt-10 px-5 pb-8">

        <!-- Loading -->
        <div v-if="loading" class="flex flex-col items-center justify-center py-32">
            <Loader2 :size="32" class="text-on-surface animate-spin" />
        </div>

        <!-- Not Found -->
        <div v-else-if="notFound" class="text-center py-16">
            <p class="font-bold text-on-surface-variant mb-3">Booking not found</p>
            <button @click="router.replace('/')" class="btn-primary text-sm px-6 py-2.5">Back to Home</button>
        </div>

        <template v-else-if="booking">
            <!-- Success icon with animation -->
            <div class="flex flex-col items-center mb-8">
                <div class="w-24 h-24 bg-emerald-100 rounded-full flex items-center justify-center mb-5 animate-bounce-once">
                    <CheckCircle2 :size="52" class="text-free" stroke-width="1.5" />
                </div>
                <h1 class="text-2xl font-black text-on-surface">Booking Confirmed!</h1>
                <p class="text-on-surface-variant text-sm mt-1 text-center">Your slot has been successfully reserved.</p>
            </div>

            <!-- Booking details card -->
            <div class="w-full bg-white rounded-2xl shadow-sm ring-1 ring-slate-100 overflow-hidden mb-6">
                <!-- Header band -->
                <div class="bg-primary px-5 py-4">
                    <p class="text-white/70 text-[11px] font-bold uppercase tracking-wider mb-0.5">Venue</p>
                    <p class="text-white font-black text-lg leading-tight">{{ booking.court_name }}</p>
                    <p v-if="booking.space_name" class="text-white/80 text-sm mt-0.5">{{ booking.space_name }}</p>
                </div>

                <div class="px-5 py-4 space-y-4">
                    <!-- Booking ID -->
                    <div class="flex items-center gap-3">
                        <div class="w-9 h-9 rounded-xl bg-gray-100 flex items-center justify-center shrink-0">
                            <Hash :size="16" class="text-on-surface-variant" />
                        </div>
                        <div>
                            <p class="text-[10px] font-bold text-outline uppercase tracking-wider">Booking ID</p>
                            <p class="text-sm font-black text-on-surface">#{{ booking.id }}</p>
                        </div>
                    </div>

                    <!-- Date -->
                    <div class="flex items-center gap-3">
                        <div class="w-9 h-9 rounded-xl bg-gray-100 flex items-center justify-center shrink-0">
                            <CalendarDays :size="16" class="text-on-surface" />
                        </div>
                        <div>
                            <p class="text-[10px] font-bold text-outline uppercase tracking-wider">Date</p>
                            <p class="text-sm font-black text-on-surface">{{ fmtDate(booking.start_time) }}</p>
                        </div>
                    </div>

                    <!-- Time -->
                    <div class="flex items-center gap-3">
                        <div class="w-9 h-9 rounded-xl bg-gray-100 flex items-center justify-center shrink-0">
                            <Clock :size="16" class="text-on-surface" />
                        </div>
                        <div>
                            <p class="text-[10px] font-bold text-outline uppercase tracking-wider">Time</p>
                            <p class="text-sm font-black text-on-surface">{{ fmtTime(booking.start_time) }} – {{ fmtTime(booking.end_time) }}</p>
                        </div>
                    </div>

                    <!-- Location -->
                    <div v-if="booking.court_location" class="flex items-center gap-3">
                        <div class="w-9 h-9 rounded-xl bg-gray-100 flex items-center justify-center shrink-0">
                            <MapPin :size="16" class="text-on-surface-variant" />
                        </div>
                        <div>
                            <p class="text-[10px] font-bold text-outline uppercase tracking-wider">Location</p>
                            <p class="text-sm font-semibold text-on-surface-variant">{{ booking.court_location }}</p>
                        </div>
                    </div>

                    <!-- Total price -->
                    <div class="border-t border-gray-100 pt-4 flex items-center justify-between">
                        <p class="text-sm font-bold text-on-surface-variant">Total Paid</p>
                        <p class="text-xl font-black text-free">₹{{ Number(booking.total_price).toLocaleString('en-IN') }}</p>
                    </div>
                </div>
            </div>

            <!-- Matchday squad card -->
            <KoCard class="w-full mb-6"
                :sport="booking.court_type"
                kicker="Squad"
                :title="`${players} player${players === 1 ? '' : 's'}${openSpots > 0 ? ` · need ${openSpots}` : ''}`"
                :meta="isBooker ? 'You booked this game' : `Booked by ${bookerName}`"
                :badge="perHead != null ? `₹${perHead}` : null">
                <JerseyRow :names="[bookerName, ...squad.map((p) => p.name)]" :open="openSpots" :tone="sportTint(booking.court_type).fg" :note="squadNote" :max="7" />
                <div v-if="isBooker && live" class="mt-3">
                    <button v-if="!askSpots" type="button" class="text-sm font-bold text-primary" @click="askSpots = openSpots || 1">
                        {{ openMatch ? 'Change open spots' : 'Need players? Post to Matches' }}
                    </button>
                    <div v-else class="flex flex-wrap items-center gap-2">
                        <button type="button" class="h-8 w-8 rounded-full border border-outline-variant font-bold disabled:opacity-30" :disabled="askSpots <= 1" aria-label="One fewer" @click="askSpots--">−</button>
                        <span class="w-6 text-center font-score text-lg font-bold">{{ askSpots }}</span>
                        <button type="button" class="h-8 w-8 rounded-full border border-primary font-bold text-primary disabled:opacity-30" :disabled="askSpots >= 20" aria-label="One more" @click="askSpots++">+</button>
                        <button type="button" class="rounded-xl bg-primary px-3 py-2 text-sm font-bold text-on-primary" @click="postOpenSpots">Post "Need {{ askSpots }}"</button>
                        <button type="button" class="text-sm text-on-surface-variant" @click="askSpots = 0">Cancel</button>
                    </div>
                </div>
                <a v-if="live" :href="whatsappUrl" target="_blank" rel="noopener"
                    class="mt-3 block w-full rounded-[14px] bg-primary py-3.5 text-center text-[15px] font-bold text-on-primary">Invite on WhatsApp</a>
            </KoCard>

            <!-- Actions -->
            <div class="w-full flex flex-col gap-3">
                <button @click="router.replace('/bookings')" class="btn-primary w-full py-3.5 text-sm font-bold">
                    View My Bookings
                </button>
                <button @click="router.replace('/')" class="btn-ghost w-full py-3.5 text-sm font-bold">
                    Back to Home
                </button>
            </div>
        </template>

    </div>
</template>

<style scoped>
@keyframes bounce-once {
    0%, 100% { transform: translateY(0); }
    40%       { transform: translateY(-12px); }
    60%       { transform: translateY(-6px); }
}
.animate-bounce-once {
    animation: bounce-once 0.7s ease-out;
}
</style>
