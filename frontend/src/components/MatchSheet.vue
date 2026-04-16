<script setup>
import { ref, computed, watch } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { X, Users, Plus, Loader2, UserPlus, UserMinus, Trash2, CalendarDays } from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    court: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue'])

const auth  = useAuthStore()
const toast = useToastStore()

const requests   = ref([])
const loading    = ref(false)
const creating   = ref(false)
const joiningId  = ref(null)
const leavingId  = ref(null)
const cancelId   = ref(null)
const showForm   = ref(false)

// New request form
const sport      = ref('')
const playDate   = ref('')
const playHour   = ref(6)
const slots      = ref(2)
const notes      = ref('')

const today = new Date().toISOString().slice(0, 10)
const HOURS = Array.from({ length: 18 }, (_, i) => {
    const h = i + 5
    const h12 = h > 12 ? h - 12 : h
    const ampm = h >= 12 ? 'PM' : 'AM'
    return { value: h, label: `${h12}:00 ${ampm}` }
})
const dateOptions = computed(() =>
    Array.from({ length: 14 }, (_, i) => {
        const d = new Date(); d.setDate(d.getDate() + i)
        return d.toISOString().slice(0, 10)
    })
)

const close = () => emit('update:modelValue', false)

const fetchRequests = async () => {
    if (!props.court) return
    loading.value = true
    try {
        const res = await axios.get(`/match-requests?court_id=${props.court.id}`)
        requests.value = res.data.requests || []
    } catch { requests.value = [] }
    finally { loading.value = false }
}

watch(() => props.modelValue, open => {
    if (open) {
        sport.value    = props.court?.type || ''
        playDate.value = today
        playHour.value = 6
        slots.value    = 2
        notes.value    = ''
        showForm.value = false
        fetchRequests()
    }
})

const isMember = (req) => req.participants?.some(p => p.user_id === auth.user?.id)
const isOwner  = (req) => req.created_by === auth.user?.id

const createRequest = async () => {
    if (!playDate.value) { toast.error('Select a date'); return }
    creating.value = true
    try {
        const startDt = `${playDate.value} ${String(playHour.value).padStart(2,'0')}:00:00`
        await axios.post('/match-requests', {
            court_id:   props.court.id,
            user_id:    auth.user.id,
            sport:      sport.value,
            play_time:  startDt,
            slots_needed: slots.value,
            notes:      notes.value.trim() || null,
        })
        toast.success('Match request created!')
        showForm.value = false
        await fetchRequests()
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to create request')
    } finally { creating.value = false }
}

const joinRequest = async (req) => {
    joiningId.value = req.id
    try {
        await axios.post(`/match-requests/${req.id}/join`, { user_id: auth.user.id })
        toast.success('Joined!')
        await fetchRequests()
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to join')
    } finally { joiningId.value = null }
}

const leaveRequest = async (req) => {
    leavingId.value = req.id
    try {
        await axios.delete(`/match-requests/${req.id}/leave`, { data: { user_id: auth.user.id } })
        toast.success('Left match')
        await fetchRequests()
    } catch { toast.error('Failed to leave') }
    finally { leavingId.value = null }
}

const cancelRequest = async (req) => {
    cancelId.value = req.id
    try {
        await axios.delete(`/match-requests/${req.id}`, { data: { user_id: auth.user.id } })
        requests.value = requests.value.filter(r => r.id !== req.id)
        toast.success('Cancelled')
    } catch { toast.error('Failed to cancel') }
    finally { cancelId.value = null }
}

const formatPlayTime = (r) => {
    if (!r.play_time) return ''
    const d = new Date(r.play_time.replace(' ', 'T'))
    return d.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' }) +
           ' · ' + d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
}

const spotsLeft = (req) => req.slots_needed - (req.participants?.length || 0)
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
                                    <h3 class="text-base font-extrabold text-slate-900">Player Matching</h3>
                                </div>
                                <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <div class="flex-1 overflow-y-auto px-5 py-5 space-y-5">

                            <!-- Create form -->
                            <div v-if="showForm" class="bg-slate-50 rounded-2xl p-4 space-y-4">
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">New Match Request</p>

                                <!-- Date -->
                                <div>
                                    <p class="text-[10px] font-bold text-slate-400 uppercase mb-1.5 flex items-center gap-1">
                                        <CalendarDays :size="11" />Date
                                    </p>
                                    <div class="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
                                        <button v-for="d in dateOptions" :key="d" @click="playDate = d"
                                            class="shrink-0 flex flex-col items-center px-3 py-2 rounded-xl text-xs font-bold transition-all"
                                            :class="playDate === d ? 'bg-primary text-white' : 'bg-white ring-1 ring-slate-200 text-slate-600'">
                                            <span class="text-[9px] uppercase">{{ new Date(d+'T00:00').toLocaleDateString('en-IN',{weekday:'short'}) }}</span>
                                            <span class="text-sm font-extrabold">{{ new Date(d+'T00:00').getDate() }}</span>
                                        </button>
                                    </div>
                                </div>

                                <!-- Time -->
                                <div>
                                    <p class="text-[10px] font-bold text-slate-400 uppercase mb-1.5">Time</p>
                                    <div class="grid grid-cols-4 gap-1.5">
                                        <button v-for="h in HOURS" :key="h.value" @click="playHour = h.value"
                                            class="py-2 rounded-xl text-[11px] font-bold border-2 transition-all"
                                            :class="playHour === h.value ? 'bg-primary border-primary text-white' : 'bg-white border-slate-200 text-slate-600'">
                                            {{ h.label }}
                                        </button>
                                    </div>
                                </div>

                                <!-- Slots needed -->
                                <div>
                                    <p class="text-[10px] font-bold text-slate-400 uppercase mb-1.5">Players needed (total including you)</p>
                                    <div class="flex gap-2">
                                        <button v-for="n in [2,3,4,6,8]" :key="n" @click="slots = n"
                                            class="flex-1 py-2 rounded-xl text-xs font-bold border-2 transition-all"
                                            :class="slots === n ? 'bg-primary border-primary text-white' : 'bg-white border-slate-200 text-slate-600'">
                                            {{ n }}
                                        </button>
                                    </div>
                                </div>

                                <!-- Notes -->
                                <input v-model="notes" type="text" placeholder="Add a note (skill level, game type...)"
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white" />

                                <div class="flex gap-2">
                                    <button @click="showForm = false"
                                        class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-white ring-1 ring-slate-200 text-slate-600">
                                        Cancel
                                    </button>
                                    <button @click="createRequest" :disabled="creating"
                                        class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-primary text-white flex items-center justify-center gap-1.5 disabled:opacity-50">
                                        <Loader2 v-if="creating" :size="13" class="animate-spin" />
                                        <span>Post Request</span>
                                    </button>
                                </div>
                            </div>

                            <button v-else @click="showForm = true"
                                class="w-full py-3 rounded-2xl text-sm font-bold border-2 border-dashed border-slate-200 text-slate-500 flex items-center justify-center gap-2 hover:border-primary hover:text-primary transition-all">
                                <Plus :size="14" />
                                Looking for players? Post a request
                            </button>

                            <!-- Match requests list -->
                            <div v-if="loading" class="space-y-3">
                                <div v-for="i in 3" :key="i" class="h-20 bg-slate-100 rounded-2xl animate-pulse"></div>
                            </div>
                            <div v-else-if="requests.length" class="space-y-3">
                                <div v-for="req in requests" :key="req.id"
                                    class="bg-slate-50 rounded-2xl p-4 space-y-3">
                                    <div class="flex items-start justify-between">
                                        <div>
                                            <div class="flex items-center gap-2">
                                                <span class="text-sm font-extrabold text-slate-800">{{ req.creator_name || 'Player' }}</span>
                                                <span v-if="req.status === 'full'"
                                                    class="text-[10px] bg-green-100 text-green-600 px-2 py-0.5 rounded-full font-bold">Full</span>
                                                <span v-else
                                                    class="text-[10px] bg-primary/10 text-primary px-2 py-0.5 rounded-full font-bold">
                                                    {{ spotsLeft(req) }} spot{{ spotsLeft(req) !== 1 ? 's' : '' }} left
                                                </span>
                                            </div>
                                            <p class="text-xs text-slate-400 mt-0.5">{{ formatPlayTime(req) }}</p>
                                            <p v-if="req.notes" class="text-xs text-slate-500 mt-1 italic">{{ req.notes }}</p>
                                        </div>
                                        <!-- Cancel (owner) -->
                                        <button v-if="isOwner(req)" @click="cancelRequest(req)" :disabled="cancelId === req.id"
                                            class="w-7 h-7 rounded-full bg-white flex items-center justify-center active:scale-90">
                                            <Loader2 v-if="cancelId === req.id" :size="12" class="animate-spin text-red-400" />
                                            <Trash2 v-else :size="12" class="text-red-400" />
                                        </button>
                                    </div>

                                    <!-- Participants -->
                                    <div v-if="req.participants?.length" class="flex items-center gap-1.5">
                                        <Users :size="11" class="text-slate-400" />
                                        <div class="flex gap-1 flex-wrap">
                                            <span v-for="p in req.participants" :key="p.user_id"
                                                class="text-[10px] bg-white ring-1 ring-slate-200 rounded-full px-2 py-0.5 font-medium text-slate-600">
                                                {{ p.name || 'Player' }}
                                            </span>
                                        </div>
                                    </div>

                                    <!-- Join/Leave -->
                                    <div v-if="!isOwner(req)">
                                        <button v-if="!isMember(req)" @click="joinRequest(req)"
                                            :disabled="req.status === 'full' || joiningId === req.id"
                                            class="w-full py-2.5 rounded-xl text-sm font-bold bg-primary text-white flex items-center justify-center gap-1.5 disabled:opacity-40 transition">
                                            <Loader2 v-if="joiningId === req.id" :size="13" class="animate-spin" />
                                            <UserPlus v-else :size="13" />
                                            {{ req.status === 'full' ? 'Match Full' : 'Join Match' }}
                                        </button>
                                        <button v-else @click="leaveRequest(req)" :disabled="leavingId === req.id"
                                            class="w-full py-2.5 rounded-xl text-sm font-bold bg-red-50 text-red-500 flex items-center justify-center gap-1.5 transition">
                                            <Loader2 v-if="leavingId === req.id" :size="13" class="animate-spin" />
                                            <UserMinus v-else :size="13" />
                                            Leave Match
                                        </button>
                                    </div>
                                </div>
                            </div>
                            <p v-else class="text-center text-slate-400 text-sm py-6">
                                No open match requests at this venue yet.
                            </p>

                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
