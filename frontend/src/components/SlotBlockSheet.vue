<script setup>
import { ref, computed, watch } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { X, Ban, Loader2, Trash2, CalendarOff } from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    court: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue', 'blocked'])

const auth  = useAuthStore()
const toast = useToastStore()

const selectedDate   = ref('')
const selectedHours  = ref([])
const reason         = ref('')
const saving         = ref(false)
const blocks         = ref([])
const loadingBlocks  = ref(false)
const removingId     = ref(null)

const today = new Date().toISOString().slice(0, 10)

const HOURS = Array.from({ length: 18 }, (_, i) => {
    const h = i + 5
    const h12 = h > 12 ? h - 12 : (h === 0 ? 12 : h)
    const ampm = h >= 12 ? 'PM' : 'AM'
    return { hour: h, label: `${h12}:00 ${ampm}` }
})

const close = () => emit('update:modelValue', false)

const fetchBlocks = async () => {
    if (!props.court) return
    loadingBlocks.value = true
    try {
        const res = await axios.get(`/blocked-slots?court_id=${props.court.id}`)
        blocks.value = res.data.blocks || []
    } catch { blocks.value = [] }
    finally { loadingBlocks.value = false }
}

watch(() => props.modelValue, open => {
    if (open) { selectedDate.value = today; selectedHours.value = []; reason.value = ''; fetchBlocks() }
})

watch(selectedDate, () => { selectedHours.value = [] })

const toggleHour = (h) => {
    const idx = selectedHours.value.indexOf(h)
    idx === -1 ? selectedHours.value.push(h) : selectedHours.value.splice(idx, 1)
}

const isBlockedHour = (h) => {
    if (!selectedDate.value) return false
    return blocks.value.some(b => {
        const bDate = b.start_time.slice(0, 10)
        const bHour = parseInt(b.start_time.slice(11, 13))
        return bDate === selectedDate.value && bHour === h
    })
}

const dateOptions = computed(() =>
    Array.from({ length: 30 }, (_, i) => {
        const d = new Date(); d.setDate(d.getDate() + i)
        return d.toISOString().slice(0, 10)
    })
)

const save = async () => {
    if (!selectedDate.value || !selectedHours.value.length) {
        toast.error('Select a date and at least one hour'); return
    }
    saving.value = true
    try {
        await axios.post('/blocked-slots', {
            court_id:   props.court.id,
            blocked_by: auth.user.id,
            date:       selectedDate.value,
            hours:      selectedHours.value,
            reason:     reason.value.trim(),
        })
        toast.success(`${selectedHours.value.length} slot(s) blocked`)
        selectedHours.value = []
        reason.value = ''
        fetchBlocks()
        emit('blocked')
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to block slots')
    } finally { saving.value = false }
}

const removeBlock = async (block) => {
    removingId.value = block.id
    try {
        await axios.delete(`/blocked-slots/${block.id}`, { data: { blocked_by: auth.user.id } })
        blocks.value = blocks.value.filter(b => b.id !== block.id)
        emit('blocked')
    } catch { toast.error('Failed to remove block') }
    finally { removingId.value = null }
}

const formatBlockTime = (b) => {
    const date = new Date(b.start_time.replace(' ', 'T'))
    return date.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' }) +
           ' · ' + date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
}
</script>

<template>
    <Teleport to="#app-root">
        <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="opacity-0" enter-to-class="opacity-100"
                    leave-active-class="transition duration-200 ease-in"  leave-from-class="opacity-100" leave-to-class="opacity-0">
            <div v-if="modelValue && court" class="absolute inset-0 bg-black/50 z-[160]" @click.self="close">
                <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="translate-y-full" enter-to-class="translate-y-0"
                            leave-active-class="transition duration-200 ease-in"  leave-from-class="translate-y-0"    leave-to-class="translate-y-full">
                    <div v-if="modelValue" class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl max-h-[90vh] flex flex-col">

                        <!-- Header -->
                        <div class="pt-3 shrink-0">
                            <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-3"></div>
                            <div class="flex items-center justify-between px-5 pb-4 border-b border-slate-100">
                                <div>
                                    <p class="text-[10px] font-black text-primary uppercase tracking-wider">{{ court.name }}</p>
                                    <h3 class="text-base font-extrabold text-slate-900">Block Slots</h3>
                                </div>
                                <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <div class="flex-1 overflow-y-auto px-5 py-5 space-y-5">

                            <!-- Date picker -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-2">Select Date</p>
                                <div class="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
                                    <button v-for="d in dateOptions" :key="d" @click="selectedDate = d"
                                        class="shrink-0 flex flex-col items-center px-3 py-2 rounded-xl text-xs font-bold transition-all"
                                        :class="selectedDate === d ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'">
                                        <span class="text-[9px] uppercase">{{ new Date(d+'T00:00').toLocaleDateString('en-IN',{weekday:'short'}) }}</span>
                                        <span class="text-sm font-extrabold">{{ new Date(d+'T00:00').getDate() }}</span>
                                    </button>
                                </div>
                            </div>

                            <!-- Hour grid -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-2">
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

                            <!-- Reason -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-2">
                                    Reason <span class="font-normal normal-case text-slate-300">(optional)</span>
                                </p>
                                <input v-model="reason" type="text" placeholder="Maintenance, private event, holiday..."
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm focus:ring-primary focus:outline-none" />
                            </div>

                            <!-- Save button -->
                            <button @click="save" :disabled="saving || !selectedHours.length"
                                class="w-full bg-red-500 text-white font-extrabold py-3.5 rounded-2xl text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition disabled:opacity-50">
                                <Loader2 v-if="saving" :size="15" class="animate-spin" />
                                <Ban v-else :size="15" />
                                Block {{ selectedHours.length || '' }} Slot{{ selectedHours.length !== 1 ? 's' : '' }}
                            </button>

                            <!-- Existing blocks -->
                            <div v-if="blocks.length">
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3">
                                    Active Blocks
                                    <span class="ml-1 bg-slate-100 text-slate-500 px-1.5 py-0.5 rounded-full text-[10px]">{{ blocks.length }}</span>
                                </p>
                                <div v-if="loadingBlocks" class="space-y-2">
                                    <div v-for="i in 3" :key="i" class="h-12 bg-slate-100 rounded-xl animate-pulse"></div>
                                </div>
                                <div v-else class="space-y-2">
                                    <div v-for="block in blocks" :key="block.id"
                                        class="flex items-center gap-3 bg-red-50 rounded-xl px-4 py-3">
                                        <CalendarOff :size="14" class="text-red-400 shrink-0" />
                                        <div class="flex-1 min-w-0">
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
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
