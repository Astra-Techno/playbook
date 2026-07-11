<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Users, MapPin, Clock, UserPlus, UserMinus, Loader2, Plus, Wind, Flag, Dumbbell, Target, Activity, CircleDot, Waves, Swords, Layers3 } from 'lucide-vue-next'

const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const requests     = ref([])
const loading      = ref(true)
const joiningId    = ref(null)
const leavingId    = ref(null)
const activeFilter = ref('All')

const SPORTS = [
    { id: 'All',     label: 'All',        icon: Layers3 },
    { id: 'shuttle', label: 'Badminton',  icon: Wind },
    { id: 'turf',    label: 'Football',   icon: Flag },
    { id: 'cricket', label: 'Cricket',    icon: Target },
    { id: 'tennis',  label: 'Tennis',     icon: Activity },
    { id: 'basket',  label: 'Basketball', icon: CircleDot },
    { id: 'gym',     label: 'Gym',        icon: Dumbbell },
    { id: 'swimming',label: 'Swimming',   icon: Waves },
    { id: 'boxing',  label: 'Boxing',     icon: Swords },
]

const filtered = computed(() =>
    activeFilter.value === 'All'
        ? requests.value
        : requests.value.filter(r => r.sport === activeFilter.value)
)

const fetchRequests = async () => {
    loading.value = true
    try {
        const res = await axios.get('/match-requests')
        requests.value = res.data.requests || []
    } catch { requests.value = [] }
    finally { loading.value = false }
}

onMounted(fetchRequests)

const isMember = (req) => req.participants?.some(p => p.user_id === auth.user?.id)
const isOwner  = (req) => req.created_by === auth.user?.id
const spotsLeft = (req) => Math.max(0, req.slots_needed - (req.participants?.length || 0))

const joinRequest = async (req) => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    joiningId.value = req.id
    try {
        await axios.post(`/match-requests/${req.id}/join`, { user_id: auth.user.id })
        toast.success('Joined the match!')
        await fetchRequests()
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to join')
    } finally { joiningId.value = null }
}

const leaveRequest = async (req) => {
    leavingId.value = req.id
    try {
        await axios.delete(`/match-requests/${req.id}/leave`, { data: { user_id: auth.user.id } })
        toast.success('Left the match')
        await fetchRequests()
    } catch { toast.error('Failed to leave') }
    finally { leavingId.value = null }
}

const formatPlayTime = (r) => {
    if (!r.play_time) return ''
    // Parse as local time (DB stores local datetime, not UTC)
    const d = new Date(r.play_time.includes('T') ? r.play_time : r.play_time.replace(' ', 'T'))
    const date = d.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })
    const time = d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
    return `${date} · ${time}`
}

const sportLabel = (id) => SPORTS.find(s => s.id === id)?.label || id
</script>

<template>
    <div class="min-h-full bg-[#f2f2f7]">

        <!-- Sport filter chips -->
        <div class="bg-white border-b border-gray-100 px-4 py-3 overflow-x-auto scrollbar-hide">
            <div class="flex gap-2">
                <button v-for="sport in SPORTS" :key="sport.id"
                    @click="activeFilter = sport.id"
                    class="flex items-center gap-1.5 shrink-0 px-3.5 py-2 rounded-full text-xs font-bold border-2 transition-all"
                    :class="activeFilter === sport.id
                        ? 'bg-black border-black text-white'
                        : 'bg-white border-gray-200 text-gray-500'">
                    <component :is="sport.icon" :size="12" />
                    {{ sport.label }}
                </button>
            </div>
        </div>

        <!-- Post a request CTA -->
        <div v-if="auth.isLoggedIn" class="px-4 pt-4">
            <button @click="router.push('/')"
                class="w-full bg-black text-white font-bold py-3.5 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all">
                <Plus :size="16" />
                Post a Match Request at a Court
            </button>
        </div>
        <div v-else class="px-4 pt-4">
            <button @click="router.push('/login')"
                class="w-full bg-black text-white font-bold py-3.5 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all">
                Sign in to post &amp; join matches
            </button>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="space-y-3 px-4 pt-4">
            <div v-for="i in 4" :key="i" class="h-32 bg-white rounded-2xl animate-pulse"></div>
        </div>

        <!-- Empty -->
        <div v-else-if="!filtered.length" class="flex flex-col items-center justify-center py-20 px-8 text-center">
            <div class="w-16 h-16 rounded-2xl bg-gray-100 flex items-center justify-center mb-4">
                <Users :size="28" class="text-gray-300" />
            </div>
            <p class="font-extrabold text-black text-lg mb-1">No open matches</p>
            <p class="text-sm text-gray-400">
                {{ activeFilter === 'All' ? 'No match requests posted yet. Be the first!' : `No open ${sportLabel(activeFilter)} matches right now.` }}
            </p>
        </div>

        <!-- Request cards -->
        <div v-else class="px-4 pt-4 pb-8 space-y-3">
            <div v-for="req in filtered" :key="req.id"
                class="bg-white rounded-2xl p-4 shadow-soft">

                <!-- Header row -->
                <div class="flex items-start justify-between mb-3">
                    <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2 mb-1">
                            <span class="text-sm font-extrabold text-black truncate">{{ req.creator_name || 'Player' }}</span>
                            <span class="shrink-0 text-[10px] font-bold px-2 py-0.5 rounded-full"
                                :class="req.status === 'full'
                                    ? 'bg-green-100 text-green-600'
                                    : 'bg-gray-100 text-black'">
                                {{ req.status === 'full' ? 'Full' : `${spotsLeft(req)} spot${spotsLeft(req) !== 1 ? 's' : ''} left` }}
                            </span>
                        </div>

                        <!-- Court name + location -->
                        <button v-if="req.court_id" @click="router.push(`/courts/${req.court_id}`)"
                            class="flex items-center gap-1 text-xs text-black font-semibold active:opacity-70">
                            <MapPin :size="11" class="text-gray-400 shrink-0" />
                            <span class="truncate">{{ req.court_name || 'Court' }}</span>
                            <span v-if="req.court_location" class="text-gray-400 font-normal">· {{ req.court_location }}</span>
                        </button>

                        <!-- Date + time -->
                        <div class="flex items-center gap-1 mt-1 text-xs text-gray-400">
                            <Clock :size="11" class="shrink-0" />
                            <span>{{ formatPlayTime(req) }}</span>
                        </div>

                        <!-- Notes -->
                        <p v-if="req.notes" class="text-xs text-gray-500 mt-1.5 italic">{{ req.notes }}</p>
                    </div>

                    <!-- Sport badge -->
                    <span class="shrink-0 ml-2 text-[10px] font-bold bg-gray-50 border border-gray-200 rounded-xl px-2 py-1 text-gray-500 capitalize">
                        {{ sportLabel(req.sport) }}
                    </span>
                </div>

                <!-- Participants -->
                <div v-if="req.participants?.length" class="flex items-center gap-2 mb-3">
                    <div class="flex -space-x-1.5">
                        <div v-for="(p, i) in req.participants.slice(0, 5)" :key="p.user_id"
                            class="w-6 h-6 rounded-full bg-black flex items-center justify-center text-[9px] font-bold text-white border-2 border-white">
                            {{ (p.name || '?')[0].toUpperCase() }}
                        </div>
                        <div v-if="req.participants.length > 5"
                            class="w-6 h-6 rounded-full bg-gray-200 flex items-center justify-center text-[9px] font-bold text-gray-500 border-2 border-white">
                            +{{ req.participants.length - 5 }}
                        </div>
                    </div>
                    <span class="text-xs text-gray-400">
                        {{ req.participants.map(p => p.name?.split(' ')[0]).join(', ') }}
                    </span>
                </div>

                <!-- Join / Leave button (non-owners) -->
                <template v-if="!isOwner(req)">
                    <button v-if="!isMember(req)"
                        @click="joinRequest(req)"
                        :disabled="req.status === 'full' || joiningId === req.id"
                        class="w-full py-2.5 rounded-xl text-sm font-bold bg-black text-white flex items-center justify-center gap-1.5 disabled:opacity-40 transition active:scale-[0.98]">
                        <Loader2 v-if="joiningId === req.id" :size="13" class="animate-spin" />
                        <UserPlus v-else :size="13" />
                        {{ req.status === 'full' ? 'Match Full' : 'Join Match' }}
                    </button>
                    <button v-else
                        @click="leaveRequest(req)"
                        :disabled="leavingId === req.id"
                        class="w-full py-2.5 rounded-xl text-sm font-bold bg-red-50 text-red-500 flex items-center justify-center gap-1.5 transition active:scale-[0.98]">
                        <Loader2 v-if="leavingId === req.id" :size="13" class="animate-spin" />
                        <UserMinus v-else :size="13" />
                        Leave Match
                    </button>
                </template>
                <p v-else class="text-center text-xs text-gray-400 font-semibold">Your request</p>
            </div>
        </div>

    </div>
</template>
