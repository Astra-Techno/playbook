<script setup>
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Clock, CalendarDays, MapPin, Loader2, Trash2, BellRing } from 'lucide-vue-next'

const auth  = useAuthStore()
const toast = useToastStore()

const entries    = ref([])
const loading    = ref(true)
const removingId = ref(null)

const fmtDate = (d) => new Date(d).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })
const fmtTime = (t) => {
    const [h, m] = t.split(':')
    const d = new Date(); d.setHours(+h, +m)
    return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
}

const load = async () => {
    loading.value = true
    try {
        const res = await axios.get(`/waitlist?user_id=${auth.user.id}`)
        entries.value = res.data.entries || []
    } catch { toast.error('Failed to load waitlist') }
    finally { loading.value = false }
}

const remove = async (entry) => {
    if (!confirm('Leave the waitlist for this slot?')) return
    removingId.value = entry.id
    try {
        await axios.delete(`/waitlist/${entry.id}`, { data: { user_id: auth.user.id } })
        entries.value = entries.value.filter(e => e.id !== entry.id)
        toast.success('Removed from waitlist')
    } catch { toast.error('Failed to remove') }
    finally { removingId.value = null }
}

onMounted(load)
</script>

<template>
    <Teleport to="#header-subject">Waitlist</Teleport>
    <Teleport to="#header-subtitle">My Waitlist</Teleport>

    <div class="min-h-screen bg-slate-50 pb-28">

        <div v-if="loading" class="p-4 space-y-3">
            <div v-for="i in 3" :key="i" class="bg-white rounded-2xl h-24 animate-pulse ring-1 ring-slate-100"></div>
        </div>

        <div v-else-if="!entries.length" class="flex flex-col items-center justify-center py-28 px-8 text-center">
            <div class="w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center mb-5">
                <BellRing :size="34" class="text-primary" />
            </div>
            <p class="font-black text-slate-800 text-lg mb-2">No waitlist entries</p>
            <p class="text-sm text-slate-400">When a slot you want is taken, join the waitlist and we'll notify you if it opens up.</p>
        </div>

        <div v-else class="p-4 space-y-3">
            <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">
                {{ entries.length }} slot{{ entries.length !== 1 ? 's' : '' }} on your waitlist
            </p>

            <div v-for="e in entries" :key="e.id"
                class="bg-white rounded-2xl px-4 py-3.5 shadow-sm ring-1 ring-slate-100">
                <div class="flex items-start gap-3">
                    <!-- Status dot -->
                    <div class="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                        :class="e.status === 'notified' ? 'bg-emerald-100' : 'bg-amber-100'">
                        <BellRing :size="18" :class="e.status === 'notified' ? 'text-emerald-600' : 'text-amber-500'" />
                    </div>

                    <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2 mb-0.5">
                            <p class="text-sm font-bold text-slate-800 truncate">{{ e.court_name }}</p>
                            <span v-if="e.space_name" class="text-[10px] font-bold text-primary bg-primary/10 px-2 py-0.5 rounded-full shrink-0">{{ e.space_name }}</span>
                        </div>
                        <div class="flex items-center gap-3 flex-wrap">
                            <div class="flex items-center gap-1 text-[11px] text-slate-500">
                                <CalendarDays :size="11" />
                                <span>{{ fmtDate(e.booking_date) }}</span>
                            </div>
                            <div class="flex items-center gap-1 text-[11px] text-slate-500">
                                <Clock :size="11" />
                                <span>{{ fmtTime(e.start_time) }} – {{ fmtTime(e.end_time) }}</span>
                            </div>
                        </div>
                        <span class="mt-1.5 inline-block text-[10px] font-bold px-2 py-0.5 rounded-full"
                            :class="e.status === 'notified' ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'">
                            {{ e.status === 'notified' ? 'Slot opened — book now!' : 'Waiting' }}
                        </span>
                    </div>

                    <button @click="remove(e)" :disabled="removingId === e.id"
                        class="w-8 h-8 rounded-xl bg-red-50 flex items-center justify-center active:scale-90 transition shrink-0">
                        <Loader2 v-if="removingId === e.id" :size="13" class="animate-spin text-red-400" />
                        <Trash2 v-else :size="13" class="text-red-400" />
                    </button>
                </div>
            </div>
        </div>
    </div>
</template>
