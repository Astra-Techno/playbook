<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Ban, Loader2, Trash2, CalendarOff, Repeat } from 'lucide-vue-next'

const route = useRoute()
const auth  = useAuthStore()
const toast = useToastStore()

const courtId   = route.params.id
const spaceId   = route.params.spaceId || null
const spaceName = ref('')
const courtName = ref('')
const blocks    = ref([])
const loading   = ref(true)
const saving    = ref(false)
const removingId = ref(null)
const spaceById = ref({})

const today          = new Date().toISOString().slice(0, 10)
const selectedDate   = ref(today)
const selectedHours  = ref([])
const reason         = ref('')
const blockKind      = ref('maintenance')
const repeatAnnual   = ref(false)

const BLOCK_KIND_LABELS = {
    maintenance: 'Maintenance',
    holiday: 'Holiday',
    private_event: 'Private event',
    tournament: 'Tournament',
    coaching: 'Coaching / academy',
    other: 'Other',
}

const HOURS = Array.from({ length: 18 }, (_, i) => {
    const h = i + 5
    const h12 = h > 12 ? h - 12 : (h === 0 ? 12 : h)
    const ampm = h >= 12 ? 'PM' : 'AM'
    return { hour: h, label: `${h12}:00 ${ampm}` }
})

const dateOptions = computed(() =>
    Array.from({ length: 30 }, (_, i) => {
        const d = new Date(); d.setDate(d.getDate() + i)
        return d.toISOString().slice(0, 10)
    })
)

const blocksUrl = () => spaceId
    ? `/blocked-slots?court_id=${courtId}&sub_court_id=${spaceId}`
    : `/blocked-slots?court_id=${courtId}`

onMounted(async () => {
    try {
        const reqs = [axios.get(`/courts/${courtId}`), axios.get(blocksUrl())]
        if (spaceId) reqs.push(axios.get(`/sub-courts/${spaceId}`))
        else reqs.push(axios.get(`/sub-courts?court_id=${courtId}`))
        const [courtRes, blocksRes, spaceRes] = await Promise.all(reqs)
        courtName.value = courtRes.data.court?.name ?? ''
        if (spaceId) {
            spaceName.value = spaceRes?.data?.space?.name ?? ''
        } else {
            const list = spaceRes?.data?.sub_courts || []
            const map = {}
            list.forEach((s) => { map[s.id] = s.name })
            spaceById.value = map
        }
        blocks.value = blocksRes.data.blocks || []
    } catch { toast.error('Failed to load') }
    finally { loading.value = false }
})

const toggleHour = (h) => {
    const idx = selectedHours.value.indexOf(h)
    idx === -1 ? selectedHours.value.push(h) : selectedHours.value.splice(idx, 1)
}

const rowInScope = (b) => {
    if (spaceId) return !b.sub_court_id || String(b.sub_court_id) === String(spaceId)
    return !b.sub_court_id
}

const hourMatchesBlock = (b, h) => {
    const bHour = parseInt(b.start_time.slice(11, 13), 10)
    if (bHour !== h) return false
    if (Number(b.repeat_annually) === 1) {
        return b.start_time.slice(5, 10) === selectedDate.value.slice(5, 10)
    }
    return b.start_time.slice(0, 10) === selectedDate.value
}

const isBlockedHour = (h) => blocks.value.some((b) => rowInScope(b) && hourMatchesBlock(b, h))

const save = async () => {
    if (!selectedDate.value || !selectedHours.value.length) {
        toast.error('Select a date and at least one hour'); return
    }
    saving.value = true
    try {
        await axios.post('/blocked-slots', {
            court_id:         courtId,
            sub_court_id:       spaceId || undefined,
            blocked_by:       auth.user.id,
            date:             selectedDate.value,
            hours:            selectedHours.value,
            reason:           reason.value.trim(),
            block_kind:       blockKind.value,
            repeat_annually:  repeatAnnual.value,
        })
        toast.success(`${selectedHours.value.length} slot(s) blocked`)
        selectedHours.value = []
        reason.value = ''
        repeatAnnual.value = false
        const res = await axios.get(blocksUrl())
        blocks.value = res.data.blocks || []
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to block slots')
    } finally { saving.value = false }
}

const removeBlock = async (block) => {
    removingId.value = block.id
    try {
        await axios.delete(`/blocked-slots/${block.id}`, { data: { blocked_by: auth.user.id } })
        blocks.value = blocks.value.filter(b => b.id !== block.id)
    } catch { toast.error('Failed to remove block') }
    finally { removingId.value = null }
}

const blockKindLabel = (k) => BLOCK_KIND_LABELS[k] || BLOCK_KIND_LABELS.other

const spaceLabel = (b) => {
    if (!b.sub_court_id) return 'All spaces'
    return spaceById.value[b.sub_court_id] || `Space #${b.sub_court_id}`
}

const formatBlockTime = (b) => {
    if (Number(b.repeat_annually) === 1) {
        const d = new Date(b.start_time.replace(' ', 'T'))
        const md = d.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' })
        const t = d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
        return `Every year · ${md} · ${t}`
    }
    const date = new Date(b.start_time.replace(' ', 'T'))
    return date.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' }) +
           ' · ' + date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
}
</script>

<template>
    <Teleport to="#header-subject">{{ spaceName || courtName || 'Block Slots' }}</Teleport>
    <Teleport to="#header-subtitle">{{ spaceId ? spaceName + ' · Block Slots' : 'Block Slots' }}</Teleport>

    <div class="min-h-full bg-slate-50">
        <!-- Header -->
        <div class="bg-white px-5 pt-5 pb-5 border-b border-slate-100">
            <h1 class="text-lg font-bold text-slate-900">Block Slots</h1>
            <p class="text-xs text-slate-500">{{ spaceId ? `Block slots for ${spaceName || 'this space'}` : 'Mark time slots as unavailable' }}</p>
        </div>

        <div class="px-5 py-5 pb-8 space-y-5">

            <!-- Date picker -->
            <div>
                <p class="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-2">Select Date</p>
                <div class="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
                    <button v-for="d in dateOptions" :key="d" @click="selectedDate = d; selectedHours = []"
                        class="shrink-0 flex flex-col items-center px-3 py-2 rounded-xl text-xs font-bold transition-all"
                        :class="selectedDate === d ? 'bg-primary text-white' : 'bg-white text-slate-600 ring-1 ring-slate-200'">
                        <span class="text-[9px] uppercase">{{ new Date(d+'T00:00').toLocaleDateString('en-IN',{weekday:'short'}) }}</span>
                        <span class="text-sm font-extrabold">{{ new Date(d+'T00:00').getDate() }}</span>
                    </button>
                </div>
            </div>

            <!-- Hour grid -->
            <div>
                <p class="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-2">
                    Select Hours to Block
                    <span v-if="selectedHours.length" class="ml-1 bg-red-100 text-red-600 px-1.5 rounded-full text-[10px]">
                        {{ selectedHours.length }} selected
                    </span>
                </p>
                <div class="grid grid-cols-4 gap-2">
                    <button v-for="s in HOURS" :key="s.hour" @click="toggleHour(s.hour)"
                        :disabled="isBlockedHour(s.hour)"
                        class="py-2.5 rounded-xl text-xs font-bold border-2 transition-all"
                        :class="isBlockedHour(s.hour) ? 'bg-red-50 border-red-200 text-red-300 cursor-not-allowed' :
                                selectedHours.includes(s.hour) ? 'bg-red-500 border-red-500 text-white' :
                                'bg-white border-slate-200 text-slate-700 hover:border-red-300'">
                        {{ s.label }}
                    </button>
                </div>
            </div>

            <!-- Category -->
            <div>
                <p class="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-2">Why are you blocking?</p>
                <select v-model="blockKind"
                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm font-semibold text-slate-700 focus:ring-primary focus:outline-none bg-white">
                    <option value="maintenance">Maintenance / repairs</option>
                    <option value="holiday">Holiday / closed day</option>
                    <option value="private_event">Private event</option>
                    <option value="tournament">Tournament / league</option>
                    <option value="coaching">Coaching / academy</option>
                    <option value="other">Other</option>
                </select>
            </div>

            <label class="flex items-center gap-3 cursor-pointer select-none bg-violet-50 rounded-xl px-4 py-3 ring-1 ring-violet-100">
                <input v-model="repeatAnnual" type="checkbox" class="w-4 h-4 rounded border-violet-300 text-violet-600 focus:ring-violet-500" />
                <div class="flex-1 min-w-0">
                    <p class="text-xs font-bold text-violet-900 flex items-center gap-1.5">
                        <Repeat :size="14" class="shrink-0" />
                        Repeat every year on this date
                    </p>
                    <p class="text-[10px] text-violet-700/90 mt-0.5">Great for fixed holidays. Uses month &amp; day from the date you picked.</p>
                </div>
            </label>

            <!-- Reason -->
            <div>
                <p class="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-2">
                    Note <span class="font-normal normal-case text-slate-300">(optional)</span>
                </p>
                <input v-model="reason" type="text" placeholder="e.g. Deep clean, Diwali, team booking…"
                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm focus:ring-primary focus:outline-none bg-white" />
            </div>

            <!-- Save -->
            <button @click="save" :disabled="saving || !selectedHours.length"
                class="w-full bg-red-500 text-white font-extrabold py-3.5 rounded-2xl text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition disabled:opacity-50">
                <Loader2 v-if="saving" :size="15" class="animate-spin" />
                <Ban v-else :size="15" />
                Block {{ selectedHours.length || '' }} Slot{{ selectedHours.length !== 1 ? 's' : '' }}
            </button>

            <!-- Existing blocks -->
            <div v-if="!loading && blocks.length">
                <p class="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-2">
                    Active Blocks
                    <span class="ml-1 bg-slate-100 text-slate-500 px-1.5 py-0.5 rounded-full text-[10px]">{{ blocks.length }}</span>
                </p>
                <div class="space-y-2">
                    <div v-for="block in blocks" :key="block.id"
                        class="flex items-center gap-3 bg-red-50 rounded-xl px-4 py-3">
                        <CalendarOff :size="14" class="text-red-400 shrink-0" />
                        <div class="flex-1 min-w-0">
                            <div class="flex flex-wrap items-center gap-1.5 mb-0.5">
                                <span class="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded bg-white text-slate-600 ring-1 ring-slate-200">
                                    {{ blockKindLabel(block.block_kind) }}
                                </span>
                                <span v-if="Number(block.repeat_annually) === 1" class="text-[9px] font-bold text-violet-700 bg-violet-100 px-1.5 py-0.5 rounded">
                                    Annual
                                </span>
                                <span v-if="!spaceId && block.sub_court_id" class="text-[9px] font-semibold text-slate-500 truncate max-w-[9rem]">
                                    {{ spaceLabel(block) }}
                                </span>
                            </div>
                            <p class="text-xs font-bold text-slate-700 truncate">{{ formatBlockTime(block) }}</p>
                            <p v-if="block.reason" class="text-[11px] text-slate-400 truncate">{{ block.reason }}</p>
                        </div>
                        <button @click="removeBlock(block)" :disabled="removingId === block.id"
                            class="w-7 h-7 rounded-full bg-white flex items-center justify-center active:scale-90 transition">
                            <Loader2 v-if="removingId === block.id" :size="12" class="animate-spin text-red-400" />
                            <Trash2 v-else :size="12" class="text-red-400" />
                        </button>
                    </div>
                </div>
            </div>

        </div>
    </div>
</template>
