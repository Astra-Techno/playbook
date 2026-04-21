<script setup>
import { computed, ref } from 'vue'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import { X, User, Phone, Clock, IndianRupee, FileText, CalendarDays, Loader2, MapPin } from 'lucide-vue-next'

const props = defineProps({
    modelValue: { type: Boolean, default: false },
    booking:    { type: Object, default: null },
    spaceName:  { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue', 'cancelled'])
const toast = useToastStore()

const close = () => emit('update:modelValue', false)

const cancelLoading = ref(false)

const playerName = computed(() => props.booking?.guest_name || props.booking?.user_name || 'Player')
const playerPhone = computed(() => props.booking?.guest_phone || props.booking?.user_phone || null)

const formatTime = (dt) => {
    if (!dt) return ''
    const t = dt.includes(' ') ? dt.split(' ')[1] : dt
    const [h, m] = t.split(':').map(Number)
    const suffix = h >= 12 ? 'PM' : 'AM'
    const hr = h % 12 || 12
    return `${hr}:${String(m).padStart(2,'0')} ${suffix}`
}

const formatDate = (dt) => {
    if (!dt) return ''
    const d = dt.includes(' ') ? dt.split(' ')[0] : dt
    return new Date(d + 'T00:00:00').toLocaleDateString('en-IN', {
        weekday: 'short', day: 'numeric', month: 'short', year: 'numeric'
    })
}

const statusMeta = computed(() => ({
    confirmed: { label: 'Confirmed',  cls: 'bg-emerald-100 text-emerald-700' },
    pending:   { label: 'Pending',    cls: 'bg-amber-100 text-amber-700' },
    cancelled: { label: 'Cancelled',  cls: 'bg-slate-100 text-slate-500' },
}[props.booking?.status] ?? { label: props.booking?.status, cls: 'bg-slate-100 text-slate-500' }))

const canCancel = computed(() => {
    if (!props.booking) return false
    if (props.booking.status === 'cancelled') return false
    const dt = props.booking.start_time
    if (!dt) return false
    return new Date(dt.replace(' ', 'T')) > new Date()
})

const cancelBooking = async () => {
    if (!confirm('Cancel this booking?')) return
    cancelLoading.value = true
    try {
        await axios.delete(`/bookings/${props.booking.id}`)
        toast.success('Booking cancelled')
        emit('cancelled', props.booking.id)
        close()
    } catch {
        toast.error('Could not cancel booking')
    } finally {
        cancelLoading.value = false
    }
}
</script>

<template>
    <Teleport to="#app-root">
        <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="modelValue && booking" class="absolute inset-0 bg-black/40 z-[200]" @click.self="close">
                <Transition
                    enter-active-class="transition duration-300 ease-out"
                    enter-from-class="translate-y-full"
                    enter-to-class="translate-y-0"
                    leave-active-class="transition duration-200 ease-in"
                    leave-from-class="translate-y-0"
                    leave-to-class="translate-y-full">
                    <div v-if="modelValue && booking"
                         class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl pb-10">

                        <!-- Handle + header -->
                        <div class="pt-3 pb-4 px-5 border-b border-slate-100">
                            <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-4"></div>
                            <div class="flex items-center justify-between">
                                <h3 class="text-base font-extrabold text-slate-900">Booking Details</h3>
                                <button @click="close"
                                    class="w-8 h-8 flex items-center justify-center rounded-full bg-slate-100 active:scale-90 transition-transform">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <!-- Content -->
                        <div class="px-5 pt-4 space-y-4">

                            <!-- Status badge -->
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold px-3 py-1.5 rounded-full" :class="statusMeta.cls">
                                    {{ statusMeta.label }}
                                </span>
                                <span v-if="booking.total_price"
                                    class="text-lg font-extrabold text-primary flex items-center gap-0.5">
                                    <IndianRupee :size="14" :stroke-width="2.5" />{{ booking.total_price }}
                                </span>
                            </div>

                            <!-- Player -->
                            <div class="flex items-center gap-3 bg-slate-50 rounded-2xl px-4 py-3">
                                <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                    <User :size="18" class="text-primary" />
                                </div>
                                <div class="flex-1 min-w-0">
                                    <p class="font-bold text-slate-900 text-sm truncate">{{ playerName }}</p>
                                    <p v-if="playerPhone" class="text-xs text-slate-500 flex items-center gap-1 mt-0.5">
                                        <Phone :size="10" /> {{ playerPhone }}
                                    </p>
                                    <p v-else class="text-xs text-slate-400">Member</p>
                                </div>
                            </div>

                            <!-- Space + Date/Time row -->
                            <div class="grid grid-cols-2 gap-3">
                                <div v-if="spaceName" class="bg-slate-50 rounded-2xl px-4 py-3">
                                    <div class="flex items-center gap-1.5 mb-1">
                                        <MapPin :size="12" class="text-slate-400" />
                                        <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Space</span>
                                    </div>
                                    <p class="text-sm font-bold text-slate-800 truncate">{{ spaceName }}</p>
                                </div>
                                <div class="bg-slate-50 rounded-2xl px-4 py-3" :class="spaceName ? '' : 'col-span-2'">
                                    <div class="flex items-center gap-1.5 mb-1">
                                        <CalendarDays :size="12" class="text-slate-400" />
                                        <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Date</span>
                                    </div>
                                    <p class="text-sm font-bold text-slate-800">{{ formatDate(booking.start_time) }}</p>
                                </div>
                            </div>

                            <!-- Time -->
                            <div class="bg-slate-50 rounded-2xl px-4 py-3 flex items-center gap-3">
                                <Clock :size="18" class="text-primary shrink-0" />
                                <div>
                                    <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-0.5">Time</p>
                                    <p class="text-sm font-extrabold text-slate-900">
                                        {{ formatTime(booking.start_time) }} – {{ formatTime(booking.end_time) }}
                                    </p>
                                </div>
                            </div>

                            <!-- Notes -->
                            <div v-if="booking.notes" class="bg-slate-50 rounded-2xl px-4 py-3 flex items-start gap-3">
                                <FileText :size="16" class="text-slate-400 mt-0.5 shrink-0" />
                                <p class="text-sm text-slate-600 leading-relaxed">{{ booking.notes }}</p>
                            </div>

                            <!-- Cancel button -->
                            <button v-if="canCancel"
                                @click="cancelBooking"
                                :disabled="cancelLoading"
                                class="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl
                                       bg-red-50 text-red-600 font-bold text-sm
                                       active:bg-red-100 active:scale-[0.98] transition-all
                                       disabled:opacity-50">
                                <Loader2 v-if="cancelLoading" :size="16" class="animate-spin" />
                                <span v-else>Cancel Booking</span>
                            </button>
                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
