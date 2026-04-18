<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { CheckCircle2, CalendarDays, Clock, MapPin, Hash, Loader2 } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()

const booking  = ref(null)
const loading  = ref(true)
const notFound = ref(false)

const parseLocal = (dt) => { const [d, t] = String(dt).split(' '); return new Date(`${d}T${t || '00:00:00'}`) }
const fmtDate = (dt) => parseLocal(dt).toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const fmtTime = (dt) => parseLocal(dt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })

onMounted(async () => {
    try {
        const res = await axios.get(`/bookings/${route.params.bookingId}`)
        booking.value = res.data.booking
    } catch {
        notFound.value = true
    } finally {
        loading.value = false
    }
})
</script>

<template>
    <div class="min-h-screen bg-slate-50 flex flex-col items-center justify-start pt-10 px-5 pb-28">

        <!-- Loading -->
        <div v-if="loading" class="flex flex-col items-center justify-center py-32">
            <Loader2 :size="32" class="text-primary animate-spin" />
        </div>

        <!-- Not Found -->
        <div v-else-if="notFound" class="text-center py-16">
            <p class="font-bold text-slate-600 mb-3">Booking not found</p>
            <button @click="router.replace('/')" class="btn-primary text-sm px-6 py-2.5">Back to Home</button>
        </div>

        <template v-else-if="booking">
            <!-- Success icon with animation -->
            <div class="flex flex-col items-center mb-8">
                <div class="w-24 h-24 bg-emerald-100 rounded-full flex items-center justify-center mb-5 animate-bounce-once">
                    <CheckCircle2 :size="52" class="text-emerald-500" stroke-width="1.5" />
                </div>
                <h1 class="text-2xl font-black text-slate-900">Booking Confirmed!</h1>
                <p class="text-slate-500 text-sm mt-1 text-center">Your slot has been successfully reserved.</p>
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
                        <div class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center shrink-0">
                            <Hash :size="16" class="text-slate-500" />
                        </div>
                        <div>
                            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Booking ID</p>
                            <p class="text-sm font-black text-slate-800">#{{ booking.id }}</p>
                        </div>
                    </div>

                    <!-- Date -->
                    <div class="flex items-center gap-3">
                        <div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                            <CalendarDays :size="16" class="text-primary" />
                        </div>
                        <div>
                            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Date</p>
                            <p class="text-sm font-black text-slate-800">{{ fmtDate(booking.start_time) }}</p>
                        </div>
                    </div>

                    <!-- Time -->
                    <div class="flex items-center gap-3">
                        <div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                            <Clock :size="16" class="text-primary" />
                        </div>
                        <div>
                            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Time</p>
                            <p class="text-sm font-black text-slate-800">{{ fmtTime(booking.start_time) }} – {{ fmtTime(booking.end_time) }}</p>
                        </div>
                    </div>

                    <!-- Location -->
                    <div v-if="booking.court_location" class="flex items-center gap-3">
                        <div class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center shrink-0">
                            <MapPin :size="16" class="text-slate-500" />
                        </div>
                        <div>
                            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Location</p>
                            <p class="text-sm font-semibold text-slate-700">{{ booking.court_location }}</p>
                        </div>
                    </div>

                    <!-- Total price -->
                    <div class="border-t border-slate-100 pt-4 flex items-center justify-between">
                        <p class="text-sm font-bold text-slate-500">Total Paid</p>
                        <p class="text-xl font-black text-emerald-600">₹{{ Number(booking.total_price).toLocaleString('en-IN') }}</p>
                    </div>
                </div>
            </div>

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
