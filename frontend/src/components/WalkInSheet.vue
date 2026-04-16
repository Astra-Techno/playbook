<script setup>
import { ref, computed, watch } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { X, UserPlus, Loader2, Phone, User, CalendarDays, Clock } from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    court: { type: Object, default: null },
    subCourts: { type: Array, default: () => [] },
})
const emit = defineEmits(['update:modelValue', 'booked'])

const auth  = useAuthStore()
const toast = useToastStore()

const guestName    = ref('')
const guestPhone   = ref('')
const notes        = ref('')
const selectedDate = ref('')
const selectedHour = ref(null)
const duration     = ref(1)
const subCourtId   = ref(null)
const saving       = ref(false)
const price        = ref(null)
const loadingPrice = ref(false)

const today = new Date().toISOString().slice(0, 10)

const HOURS = Array.from({ length: 18 }, (_, i) => {
    const h = i + 5
    const h12 = h > 12 ? h - 12 : (h === 0 ? 12 : h)
    const ampm = h >= 12 ? 'PM' : 'AM'
    return { hour: h, label: `${h12}:00 ${ampm}` }
})

const dateOptions = computed(() =>
    Array.from({ length: 14 }, (_, i) => {
        const d = new Date(); d.setDate(d.getDate() + i)
        return d.toISOString().slice(0, 10)
    })
)

const close = () => emit('update:modelValue', false)

watch(() => props.modelValue, open => {
    if (open) {
        guestName.value   = ''
        guestPhone.value  = ''
        notes.value       = ''
        selectedDate.value = today
        selectedHour.value = null
        duration.value    = 1
        subCourtId.value  = props.subCourts.length ? props.subCourts[0].id : null
        price.value       = null
    }
})

watch(selectedDate, () => { selectedHour.value = null; price.value = null })

const fetchPrice = async () => {
    if (!selectedDate.value || selectedHour.value === null || !props.court) return
    loadingPrice.value = true
    try {
        const res = await axios.get(`/pricing-rules/calculate?court_id=${props.court.id}&date=${selectedDate.value}&hour=${selectedHour.value}`)
        price.value = res.data.effective_price ?? props.court.hourly_rate
    } catch {
        price.value = props.court?.hourly_rate ?? 0
    } finally { loadingPrice.value = false }
}

watch([selectedHour, selectedDate], fetchPrice)

const totalPrice = computed(() => {
    if (price.value === null) return null
    return price.value * duration.value
})

const save = async () => {
    if (!guestName.value.trim()) { toast.error('Enter guest name'); return }
    if (!selectedDate.value || selectedHour.value === null) { toast.error('Select date and time'); return }

    const startDt = `${selectedDate.value} ${String(selectedHour.value).padStart(2, '0')}:00:00`
    const endHour = selectedHour.value + duration.value
    const endDate = endHour >= 24
        ? new Date(new Date(selectedDate.value).getTime() + 86400000).toISOString().slice(0, 10)
        : selectedDate.value
    const endDt = `${endDate} ${String(endHour % 24).padStart(2, '0')}:00:00`

    saving.value = true
    try {
        const payload = {
            court_id:    props.court.id,
            guest_name:  guestName.value.trim(),
            guest_phone: guestPhone.value.trim() || null,
            notes:       notes.value.trim() || null,
            start_time:  startDt,
            end_time:    endDt,
            type:        'hourly',
            total_price: totalPrice.value ?? 0,
            staff_id:    auth.user.id,
        }
        if (subCourtId.value) payload.sub_court_id = subCourtId.value
        await axios.post('/bookings', payload)
        toast.success('Walk-in booking created')
        emit('booked')
        close()
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to create booking')
    } finally { saving.value = false }
}
</script>

<template>
    <Teleport to="#app-root">
        <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="opacity-0" enter-to-class="opacity-100"
                    leave-active-class="transition duration-200 ease-in"  leave-from-class="opacity-100" leave-to-class="opacity-0">
            <div v-if="modelValue && court" class="absolute inset-0 bg-black/50 z-[160]" @click.self="close">
                <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="translate-y-full" enter-to-class="translate-y-0"
                            leave-active-class="transition duration-200 ease-in"  leave-from-class="translate-y-0"    leave-to-class="translate-y-full">
                    <div v-if="modelValue" class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl max-h-[92vh] flex flex-col">

                        <!-- Header -->
                        <div class="pt-3 shrink-0">
                            <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-3"></div>
                            <div class="flex items-center justify-between px-5 pb-4 border-b border-slate-100">
                                <div>
                                    <p class="text-[10px] font-black text-primary uppercase tracking-wider">{{ court.name }}</p>
                                    <h3 class="text-base font-extrabold text-slate-900">Walk-in Booking</h3>
                                </div>
                                <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <div class="flex-1 overflow-y-auto px-5 py-5 space-y-5">

                            <!-- Guest info -->
                            <div class="space-y-3">
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">Guest Details</p>
                                <div class="relative">
                                    <User :size="14" class="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                                    <input v-model="guestName" type="text" placeholder="Customer name *"
                                        class="w-full pl-9 pr-4 py-3 ring-1 ring-slate-200 rounded-xl text-sm focus:ring-primary focus:outline-none" />
                                </div>
                                <div class="relative">
                                    <Phone :size="14" class="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                                    <input v-model="guestPhone" type="tel" placeholder="Phone number (optional)"
                                        class="w-full pl-9 pr-4 py-3 ring-1 ring-slate-200 rounded-xl text-sm focus:ring-primary focus:outline-none" />
                                </div>
                            </div>

                            <!-- Sub-court selector -->
                            <div v-if="subCourts.length">
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-2">Select Court</p>
                                <div class="flex gap-2 flex-wrap">
                                    <button v-for="sc in subCourts" :key="sc.id" @click="subCourtId = sc.id"
                                        class="px-4 py-2 rounded-xl text-xs font-bold transition-all"
                                        :class="subCourtId === sc.id ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'">
                                        {{ sc.name }}
                                    </button>
                                </div>
                            </div>

                            <!-- Date picker -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                    <CalendarDays :size="12" />Date
                                </p>
                                <div class="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
                                    <button v-for="d in dateOptions" :key="d" @click="selectedDate = d"
                                        class="shrink-0 flex flex-col items-center px-3 py-2 rounded-xl text-xs font-bold transition-all"
                                        :class="selectedDate === d ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'">
                                        <span class="text-[9px] uppercase">{{ new Date(d+'T00:00').toLocaleDateString('en-IN',{weekday:'short'}) }}</span>
                                        <span class="text-sm font-extrabold">{{ new Date(d+'T00:00').getDate() }}</span>
                                    </button>
                                </div>
                            </div>

                            <!-- Hour selector -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                    <Clock :size="12" />Start Time
                                </p>
                                <div class="grid grid-cols-4 gap-2">
                                    <button v-for="s in HOURS" :key="s.hour" @click="selectedHour = s.hour"
                                        class="py-2.5 rounded-xl text-xs font-bold border-2 transition-all"
                                        :class="selectedHour === s.hour
                                            ? 'bg-primary border-primary text-white'
                                            : 'bg-white border-slate-200 text-slate-700 hover:border-primary/40'">
                                        {{ s.label }}
                                    </button>
                                </div>
                            </div>

                            <!-- Duration -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-2">Duration</p>
                                <div class="flex gap-2">
                                    <button v-for="h in [1,2,3,4]" :key="h" @click="duration = h"
                                        class="flex-1 py-2.5 rounded-xl text-xs font-bold border-2 transition-all"
                                        :class="duration === h ? 'bg-primary border-primary text-white' : 'bg-white border-slate-200 text-slate-700'">
                                        {{ h }}h
                                    </button>
                                </div>
                            </div>

                            <!-- Notes -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-2">
                                    Notes <span class="font-normal normal-case text-slate-300">(optional)</span>
                                </p>
                                <input v-model="notes" type="text" placeholder="Any special notes..."
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm focus:ring-primary focus:outline-none" />
                            </div>

                            <!-- Price summary -->
                            <div v-if="selectedHour !== null" class="bg-slate-50 rounded-2xl px-4 py-3 flex items-center justify-between">
                                <span class="text-sm font-bold text-slate-600">Total</span>
                                <span v-if="loadingPrice" class="text-sm text-slate-400">Calculating...</span>
                                <span v-else class="text-lg font-extrabold text-primary">
                                    ₹{{ totalPrice?.toFixed(0) ?? '—' }}
                                    <span class="text-xs font-normal text-slate-400">({{ duration }}h)</span>
                                </span>
                            </div>

                            <!-- Save button -->
                            <button @click="save" :disabled="saving || !guestName.trim() || selectedHour === null"
                                class="w-full bg-primary text-white font-extrabold py-3.5 rounded-2xl text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition disabled:opacity-50">
                                <Loader2 v-if="saving" :size="15" class="animate-spin" />
                                <UserPlus v-else :size="15" />
                                Confirm Walk-in Booking
                            </button>

                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
