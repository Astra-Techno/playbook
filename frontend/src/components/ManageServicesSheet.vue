<script setup>
import { ref, watch } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    X, Plus, Trash2, Loader2, Pencil, ChevronLeft,
    LayoutGrid, BookOpen, Droplets, Package,
    Wind, Flag, CircleDot, Waves, Dumbbell, Activity, Target, Layers3, Swords,
} from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    venue: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue', 'changed'])

const auth  = useAuthStore()
const toast = useToastStore()

const services  = ref([])
const loading   = ref(false)
const saving    = ref(false)
const view      = ref('list')       // 'list' | 'type-select' | 'form'
const selType   = ref('court')
const editing   = ref(null)         // service being edited

const form = ref(blankForm())
function blankForm() {
    return { name: '', sport: 'shuttle', pricing_type: 'hourly', hourly_rate: '', session_rate: '', monthly_rate: '', capacity: '', schedule: { days: [], start_time: '18:00', end_time: '19:00' } }
}

const close = () => emit('update:modelValue', false)

watch(() => props.modelValue, async (open) => {
    if (open && props.venue) { view.value = 'list'; await fetchServices() }
})

const fetchServices = async () => {
    loading.value = true
    try {
        const res = await axios.get(`/sub-courts?court_id=${props.venue.id}`)
        services.value = res.data.sub_courts || []
    } catch { services.value = [] }
    finally { loading.value = false }
}

// ── Type / Sport definitions ───────────────────────────────────────────────

const SERVICE_TYPES = [
    { id: 'court', label: 'Court',  desc: 'Hourly slot booking', icon: LayoutGrid, bg: 'bg-blue-50',   ring: 'ring-blue-200',   text: 'text-blue-600'   },
    { id: 'class', label: 'Class',  desc: 'Fixed schedule, enroll', icon: BookOpen, bg: 'bg-purple-50', ring: 'ring-purple-200', text: 'text-purple-600' },
    { id: 'pool',  label: 'Pool',   desc: 'Session / lane booking', icon: Droplets, bg: 'bg-cyan-50',   ring: 'ring-cyan-200',   text: 'text-cyan-600'   },
    { id: 'other', label: 'Other',  desc: 'Custom service',         icon: Package,  bg: 'bg-slate-50',  ring: 'ring-slate-200',  text: 'text-slate-600'  },
]

const SPORTS = [
    { id: 'shuttle',  label: 'Badminton',   icon: Wind },
    { id: 'turf',     label: 'Football',    icon: Flag },
    { id: 'basket',   label: 'Basketball',  icon: CircleDot },
    { id: 'swimming', label: 'Swimming',    icon: Waves },
    { id: 'gym',      label: 'Gym',         icon: Dumbbell },
    { id: 'tennis',   label: 'Tennis',      icon: Activity },
    { id: 'cricket',  label: 'Cricket',     icon: Target },
    { id: 'boxing',   label: 'Boxing',      icon: Swords },
    { id: 'other',    label: 'Other',       icon: Layers3 },
]

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

// ── Helpers ───────────────────────────────────────────────────────────────

const typeInfo  = (id) => SERVICE_TYPES.find(t => t.id === id) || SERVICE_TYPES[0]
const sportInfo = (id) => SPORTS.find(s => s.id === id) || SPORTS[SPORTS.length - 1]

const priceLabel = (svc) => {
    if (svc.service_type === 'class') {
        if (svc.monthly_rate) return `₹${svc.monthly_rate}/month`
        if (svc.session_rate) return `₹${svc.session_rate}/session`
    }
    if (svc.service_type === 'pool') {
        if (svc.session_rate) return `₹${svc.session_rate}/session`
        if (svc.hourly_rate)  return `₹${svc.hourly_rate}/hr`
    }
    return svc.hourly_rate ? `₹${svc.hourly_rate}/hr` : ''
}

const scheduleLabel = (svc) => {
    const sch = svc.schedule
    if (!sch?.days?.length) return ''
    return `${sch.days.join(' · ')} ${fmt12(sch.start_time)} – ${fmt12(sch.end_time)}`
}

const fmt12 = (t) => {
    if (!t) return ''
    const [h, m] = t.split(':').map(Number)
    const ampm = h >= 12 ? 'PM' : 'AM'
    const h12  = h > 12 ? h - 12 : (h === 0 ? 12 : h)
    return `${h12}:${String(m).padStart(2, '0')} ${ampm}`
}

const toggleDay = (day) => {
    const days = form.value.schedule.days
    const i = days.indexOf(day)
    if (i > -1) days.splice(i, 1)
    else days.push(day)
}

// ── Navigation ────────────────────────────────────────────────────────────

const goAdd = () => { editing.value = null; form.value = blankForm(); view.value = 'type-select' }

const pickType = (type) => { selType.value = type; view.value = 'form' }

const startEdit = (svc) => {
    editing.value = svc
    selType.value = svc.service_type || 'court'
    form.value = {
        name:         svc.name || '',
        sport:        svc.sport || 'shuttle',
        pricing_type: svc.pricing_type || 'hourly',
        hourly_rate:  svc.hourly_rate  || '',
        session_rate: svc.session_rate || '',
        monthly_rate: svc.monthly_rate || '',
        capacity:     svc.capacity     || '',
        schedule:     svc.schedule ? { ...svc.schedule, days: [...(svc.schedule.days || [])] }
                                   : { days: [], start_time: '18:00', end_time: '19:00' },
    }
    view.value = 'form'
}

// ── Save / Delete ─────────────────────────────────────────────────────────

const save = async () => {
    if (!form.value.name.trim()) { toast.error('Enter a name'); return }
    if (selType.value === 'court' && !form.value.hourly_rate) { toast.error('Enter hourly rate'); return }
    if (selType.value === 'class' && !form.value.schedule.days.length) { toast.error('Select at least one day'); return }
    if (selType.value === 'class' && !form.value.monthly_rate && !form.value.session_rate) { toast.error('Enter a rate'); return }
    if (selType.value === 'pool'  && !form.value.session_rate && !form.value.hourly_rate) { toast.error('Enter a rate'); return }

    saving.value = true
    try {
        const payload = {
            court_id:     props.venue.id,
            owner_id:     auth.user.id,
            name:         form.value.name.trim(),
            service_type: selType.value,
            sport:        selType.value === 'court' ? form.value.sport : null,
            pricing_type: form.value.pricing_type,
            hourly_rate:  form.value.hourly_rate  ? Number(form.value.hourly_rate)  : null,
            session_rate: form.value.session_rate ? Number(form.value.session_rate) : null,
            monthly_rate: form.value.monthly_rate ? Number(form.value.monthly_rate) : null,
            capacity:     form.value.capacity     ? Number(form.value.capacity)     : null,
            schedule:     selType.value === 'class' ? form.value.schedule : null,
        }
        if (editing.value) {
            await axios.put(`/sub-courts/${editing.value.id}`, payload)
            toast.success('Service updated!')
        } else {
            await axios.post('/sub-courts', payload)
            toast.success('Service added!')
        }
        emit('changed')
        await fetchServices()
        view.value = 'list'
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to save')
    } finally { saving.value = false }
}

const remove = async (svc) => {
    if (!confirm(`Remove "${svc.name}"?`)) return
    try {
        await axios.delete(`/sub-courts/${svc.id}`, { data: { owner_id: auth.user.id } })
        toast.success('Removed')
        emit('changed')
        await fetchServices()
    } catch { toast.error('Could not remove') }
}
</script>

<template>
    <Teleport to="#app-root">
        <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="opacity-0" enter-to-class="opacity-100"
                    leave-active-class="transition duration-200 ease-in"  leave-from-class="opacity-100" leave-to-class="opacity-0">
            <div v-if="modelValue && venue" class="absolute inset-0 bg-black/50 z-[160]" @click.self="close">
                <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="translate-y-full" enter-to-class="translate-y-0"
                            leave-active-class="transition duration-200 ease-in"  leave-from-class="translate-y-0"    leave-to-class="translate-y-full">
                    <div v-if="modelValue" class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl max-h-[90vh] flex flex-col">

                        <!-- Handle + Header -->
                        <div class="shrink-0 pt-3">
                            <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-3"></div>
                            <div class="flex items-center gap-3 px-5 pb-4 border-b border-slate-100">
                                <button v-if="view !== 'list'" @click="view = view === 'form' ? 'type-select' : 'list'"
                                    class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center shrink-0">
                                    <ChevronLeft :size="16" class="text-slate-500" />
                                </button>
                                <div class="flex-1">
                                    <p class="text-[10px] font-black text-primary uppercase tracking-wider">{{ venue.name }}</p>
                                    <h3 class="text-base font-extrabold text-slate-900">
                                        {{ view === 'list' ? 'Manage Services' : view === 'type-select' ? 'What do you offer?' : (editing ? 'Edit Service' : 'Add Service') }}
                                    </h3>
                                </div>
                                <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center shrink-0">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <!-- ── LIST VIEW ─────────────────────────────────────────── -->
                        <div v-if="view === 'list'" class="flex-1 overflow-y-auto px-5 py-5 space-y-4">
                            <!-- Loading -->
                            <div v-if="loading" class="space-y-3">
                                <div v-for="i in 3" :key="i" class="h-16 bg-slate-100 rounded-2xl animate-pulse"></div>
                            </div>

                            <!-- Empty -->
                            <div v-else-if="!services.length" class="text-center py-12 bg-slate-50 rounded-3xl border-2 border-dashed border-slate-200">
                                <LayoutGrid :size="32" class="text-slate-300 mx-auto mb-3" />
                                <p class="font-bold text-slate-500 text-sm">No services yet</p>
                                <p class="text-xs text-slate-400 mt-1">Add courts, classes or pools</p>
                            </div>

                            <!-- Service cards -->
                            <div v-else class="space-y-3">
                                <div v-for="svc in services" :key="svc.id"
                                    class="flex items-center gap-3 bg-slate-50 rounded-2xl px-4 py-3 ring-1 ring-slate-100">
                                    <!-- Type icon -->
                                    <div :class="[typeInfo(svc.service_type).bg, 'w-10 h-10 rounded-xl flex items-center justify-center shrink-0']">
                                        <component :is="typeInfo(svc.service_type).icon" :size="18" :class="typeInfo(svc.service_type).text" />
                                    </div>
                                    <!-- Info -->
                                    <div class="flex-1 min-w-0">
                                        <p class="font-bold text-slate-800 text-sm truncate">{{ svc.name }}</p>
                                        <p class="text-xs text-slate-500 truncate">
                                            <span v-if="svc.sport" class="text-primary font-semibold">{{ sportInfo(svc.sport).label }} · </span>
                                            {{ priceLabel(svc) }}
                                            <span v-if="svc.service_type === 'class' && svc.schedule"> · {{ scheduleLabel(svc) }}</span>
                                            <span v-if="svc.capacity"> · {{ svc.capacity }} spots</span>
                                        </p>
                                    </div>
                                    <!-- Actions -->
                                    <button @click="startEdit(svc)" class="w-8 h-8 rounded-xl bg-white ring-1 ring-slate-200 flex items-center justify-center shrink-0">
                                        <Pencil :size="13" class="text-slate-500" />
                                    </button>
                                    <button @click="remove(svc)" class="w-8 h-8 rounded-xl bg-red-50 ring-1 ring-red-100 flex items-center justify-center shrink-0">
                                        <Trash2 :size="13" class="text-red-400" />
                                    </button>
                                </div>
                            </div>

                            <!-- Add button -->
                            <button @click="goAdd"
                                class="w-full flex items-center justify-center gap-2 bg-primary text-white font-extrabold py-4 rounded-2xl text-sm active:scale-[0.98] transition-transform">
                                <Plus :size="16" />
                                Add Service
                            </button>
                        </div>

                        <!-- ── TYPE SELECT VIEW ───────────────────────────────────── -->
                        <div v-else-if="view === 'type-select'" class="flex-1 overflow-y-auto px-5 py-5">
                            <p class="text-sm text-slate-500 mb-5">Choose what type of service you want to add to this venue.</p>
                            <div class="grid grid-cols-2 gap-3">
                                <button v-for="t in SERVICE_TYPES" :key="t.id" @click="pickType(t.id)"
                                    :class="[t.bg, t.ring, 'ring-1 rounded-2xl p-5 flex flex-col items-start gap-2 active:scale-[0.97] transition-transform text-left']">
                                    <component :is="t.icon" :size="28" :class="t.text" />
                                    <div>
                                        <p :class="[t.text, 'font-extrabold text-base']">{{ t.label }}</p>
                                        <p class="text-xs text-slate-500 mt-0.5">{{ t.desc }}</p>
                                    </div>
                                </button>
                            </div>
                        </div>

                        <!-- ── FORM VIEW ──────────────────────────────────────────── -->
                        <div v-else class="flex-1 overflow-y-auto px-5 py-5 space-y-5">
                            <!-- Type badge -->
                            <div :class="[typeInfo(selType).bg, typeInfo(selType).ring, 'ring-1 rounded-xl px-3 py-2 flex items-center gap-2 w-fit']">
                                <component :is="typeInfo(selType).icon" :size="14" :class="typeInfo(selType).text" />
                                <span :class="[typeInfo(selType).text, 'text-xs font-bold']">{{ typeInfo(selType).label }}</span>
                            </div>

                            <!-- Name -->
                            <div>
                                <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">
                                    Name <span class="text-red-400">*</span>
                                </label>
                                <input v-model="form.name" type="text"
                                    :placeholder="selType === 'court' ? 'e.g. Badminton Court 1' : selType === 'class' ? 'e.g. Zumba, Classical Dance' : selType === 'pool' ? 'e.g. Swimming Pool' : 'Service name'"
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm focus:ring-primary focus:outline-none" />
                            </div>

                            <!-- COURT: sport + hourly rate -->
                            <template v-if="selType === 'court'">
                                <div>
                                    <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">Sport</label>
                                    <div class="grid grid-cols-3 gap-2">
                                        <button v-for="s in SPORTS" :key="s.id" @click="form.sport = s.id"
                                            :class="form.sport === s.id
                                                ? 'bg-primary text-white ring-primary'
                                                : 'bg-slate-50 text-slate-600 ring-slate-200'"
                                            class="ring-1 rounded-xl py-2.5 flex flex-col items-center gap-1 text-[11px] font-bold transition-all active:scale-95">
                                            <component :is="s.icon" :size="16" />
                                            {{ s.label }}
                                        </button>
                                    </div>
                                </div>
                                <div>
                                    <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">
                                        Hourly Rate <span class="text-red-400">*</span>
                                    </label>
                                    <div class="flex items-center gap-2 ring-1 ring-slate-200 rounded-xl px-4 h-12 focus-within:ring-primary">
                                        <span class="text-slate-400 font-bold text-sm">₹</span>
                                        <input v-model="form.hourly_rate" type="number" min="1" placeholder="e.g. 300"
                                            class="flex-1 text-sm font-bold bg-transparent border-none focus:ring-0" />
                                        <span class="text-xs text-slate-400 shrink-0">/ hr</span>
                                    </div>
                                </div>
                            </template>

                            <!-- CLASS: schedule + pricing -->
                            <template v-else-if="selType === 'class'">
                                <div>
                                    <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">Days</label>
                                    <div class="flex gap-2 flex-wrap">
                                        <button v-for="day in DAYS" :key="day" @click="toggleDay(day)"
                                            :class="form.schedule.days.includes(day)
                                                ? 'bg-primary text-white'
                                                : 'bg-slate-100 text-slate-600'"
                                            class="w-11 h-11 rounded-xl text-xs font-bold transition-all active:scale-95">
                                            {{ day }}
                                        </button>
                                    </div>
                                </div>
                                <div class="grid grid-cols-2 gap-3">
                                    <div>
                                        <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">Start Time</label>
                                        <input v-model="form.schedule.start_time" type="time"
                                            class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm focus:ring-primary focus:outline-none" />
                                    </div>
                                    <div>
                                        <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">End Time</label>
                                        <input v-model="form.schedule.end_time" type="time"
                                            class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm focus:ring-primary focus:outline-none" />
                                    </div>
                                </div>
                                <!-- Pricing type -->
                                <div>
                                    <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">Pricing</label>
                                    <div class="flex gap-2 mb-3">
                                        <button @click="form.pricing_type = 'monthly'" :class="form.pricing_type === 'monthly' ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'" class="flex-1 py-2.5 rounded-xl text-xs font-bold transition-all">Monthly</button>
                                        <button @click="form.pricing_type = 'session'" :class="form.pricing_type === 'session' ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'" class="flex-1 py-2.5 rounded-xl text-xs font-bold transition-all">Per Session</button>
                                    </div>
                                    <div class="flex items-center gap-2 ring-1 ring-slate-200 rounded-xl px-4 h-12 focus-within:ring-primary">
                                        <span class="text-slate-400 font-bold text-sm">₹</span>
                                        <input v-if="form.pricing_type === 'monthly'" v-model="form.monthly_rate" type="number" min="1" placeholder="e.g. 2000"
                                            class="flex-1 text-sm font-bold bg-transparent border-none focus:ring-0" />
                                        <input v-else v-model="form.session_rate" type="number" min="1" placeholder="e.g. 500"
                                            class="flex-1 text-sm font-bold bg-transparent border-none focus:ring-0" />
                                        <span class="text-xs text-slate-400 shrink-0">/ {{ form.pricing_type === 'monthly' ? 'month' : 'session' }}</span>
                                    </div>
                                </div>
                                <div>
                                    <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">Max Spots <span class="font-normal normal-case text-slate-300">(optional)</span></label>
                                    <input v-model="form.capacity" type="number" min="1" placeholder="e.g. 15"
                                        class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm focus:ring-primary focus:outline-none" />
                                </div>
                            </template>

                            <!-- POOL: session rate + capacity -->
                            <template v-else-if="selType === 'pool'">
                                <div>
                                    <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">Pricing</label>
                                    <div class="flex gap-2 mb-3">
                                        <button @click="form.pricing_type = 'session'" :class="form.pricing_type === 'session' ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'" class="flex-1 py-2.5 rounded-xl text-xs font-bold transition-all">Per Session</button>
                                        <button @click="form.pricing_type = 'hourly'"  :class="form.pricing_type === 'hourly'  ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'" class="flex-1 py-2.5 rounded-xl text-xs font-bold transition-all">Per Hour</button>
                                    </div>
                                    <div class="flex items-center gap-2 ring-1 ring-slate-200 rounded-xl px-4 h-12 focus-within:ring-primary">
                                        <span class="text-slate-400 font-bold text-sm">₹</span>
                                        <input v-if="form.pricing_type === 'session'" v-model="form.session_rate" type="number" min="1" placeholder="e.g. 500"
                                            class="flex-1 text-sm font-bold bg-transparent border-none focus:ring-0" />
                                        <input v-else v-model="form.hourly_rate" type="number" min="1" placeholder="e.g. 300"
                                            class="flex-1 text-sm font-bold bg-transparent border-none focus:ring-0" />
                                        <span class="text-xs text-slate-400 shrink-0">/ {{ form.pricing_type === 'session' ? 'session' : 'hr' }}</span>
                                    </div>
                                </div>
                                <div>
                                    <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">Capacity <span class="font-normal normal-case text-slate-300">(lanes / spots)</span></label>
                                    <input v-model="form.capacity" type="number" min="1" placeholder="e.g. 6"
                                        class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm focus:ring-primary focus:outline-none" />
                                </div>
                            </template>

                            <!-- OTHER: pricing type + rate -->
                            <template v-else>
                                <div>
                                    <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">Pricing Type</label>
                                    <div class="flex gap-2 mb-3">
                                        <button v-for="pt in [{id:'hourly',l:'Per Hour'},{id:'session',l:'Per Session'},{id:'monthly',l:'Monthly'}]" :key="pt.id"
                                            @click="form.pricing_type = pt.id" :class="form.pricing_type === pt.id ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'"
                                            class="flex-1 py-2.5 rounded-xl text-xs font-bold transition-all">{{ pt.l }}</button>
                                    </div>
                                    <div class="flex items-center gap-2 ring-1 ring-slate-200 rounded-xl px-4 h-12 focus-within:ring-primary">
                                        <span class="text-slate-400 font-bold text-sm">₹</span>
                                        <input v-model="form.hourly_rate" type="number" min="1" placeholder="Rate"
                                            class="flex-1 text-sm font-bold bg-transparent border-none focus:ring-0" />
                                    </div>
                                </div>
                            </template>

                            <!-- Save button -->
                            <button @click="save" :disabled="saving"
                                class="w-full bg-primary text-white font-extrabold py-4 rounded-2xl text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition-transform disabled:opacity-60">
                                <Loader2 v-if="saving" :size="16" class="animate-spin" />
                                <span v-else>{{ editing ? 'Save Changes' : 'Add Service' }}</span>
                            </button>
                        </div>

                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
