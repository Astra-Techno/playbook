<script setup>
import { ref, watch } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { X, Plus, Trash2, Loader2, Tag } from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    court: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue', 'changed'])

const auth  = useAuthStore()
const toast = useToastStore()

const rules      = ref([])
const loading    = ref(false)
const saving     = ref(false)
const removingId = ref(null)
const adding     = ref(false)

const newName      = ref('')
const newDayType   = ref('all')
const newStartHour = ref(5)
const newEndHour   = ref(22)
const newPrice     = ref('')
const newPriority  = ref(10)

const DAY_TYPES = [
    { value: 'all',     label: 'Every day' },
    { value: 'weekday', label: 'Weekdays' },
    { value: 'weekend', label: 'Weekends' },
]

const HOURS = Array.from({ length: 24 }, (_, i) => {
    const h12 = i === 0 ? 12 : i > 12 ? i - 12 : i
    const ampm = i >= 12 ? 'PM' : 'AM'
    return { value: i, label: `${h12}:00 ${ampm}` }
})

const close = () => emit('update:modelValue', false)

const fetchRules = async () => {
    if (!props.court) return
    loading.value = true
    try {
        const res = await axios.get(`/pricing-rules?court_id=${props.court.id}`)
        rules.value = res.data.rules || []
    } catch { rules.value = [] }
    finally { loading.value = false }
}

watch(() => props.modelValue, open => {
    if (open) { adding.value = false; resetForm(); fetchRules() }
})

const resetForm = () => {
    newName.value      = ''
    newDayType.value   = 'all'
    newStartHour.value = 5
    newEndHour.value   = 22
    newPrice.value     = ''
    newPriority.value  = 10
}

const addRule = async () => {
    if (!newName.value.trim()) { toast.error('Enter rule name'); return }
    if (!newPrice.value)       { toast.error('Enter price'); return }
    if (newStartHour.value >= newEndHour.value) { toast.error('End hour must be after start'); return }
    saving.value = true
    try {
        await axios.post('/pricing-rules', {
            court_id:   props.court.id,
            owner_id:   auth.user.id,
            name:       newName.value.trim(),
            day_type:   newDayType.value,
            start_hour: newStartHour.value,
            end_hour:   newEndHour.value,
            price:      parseFloat(newPrice.value),
            priority:   newPriority.value,
        })
        resetForm()
        adding.value = false
        await fetchRules()
        emit('changed')
        toast.success('Pricing rule added')
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to add rule')
    } finally { saving.value = false }
}

const removeRule = async (rule) => {
    removingId.value = rule.id
    try {
        await axios.delete(`/pricing-rules/${rule.id}`, { data: { owner_id: auth.user.id } })
        rules.value = rules.value.filter(r => r.id !== rule.id)
        emit('changed')
        toast.success('Rule removed')
    } catch { toast.error('Failed to remove') }
    finally { removingId.value = null }
}

const dayTypeLabel = (dt) => DAY_TYPES.find(d => d.value === dt)?.label ?? dt
const hourLabel    = (h)  => HOURS[h]?.label ?? h
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
                                    <h3 class="text-base font-extrabold text-slate-900">Dynamic Pricing</h3>
                                </div>
                                <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <div class="flex-1 overflow-y-auto px-5 py-5 space-y-5">

                            <!-- Info -->
                            <div class="bg-amber-50 rounded-xl px-4 py-3 text-xs text-amber-700 leading-relaxed">
                                Rules with higher priority override lower ones. Base rate (₹{{ court.hourly_rate }}/hr) applies when no rule matches.
                            </div>

                            <!-- Rules list -->
                            <div v-if="loading" class="space-y-2">
                                <div v-for="i in 3" :key="i" class="h-16 bg-slate-100 rounded-xl animate-pulse"></div>
                            </div>
                            <div v-else-if="rules.length" class="space-y-2">
                                <div v-for="rule in rules" :key="rule.id"
                                    class="flex items-start gap-3 bg-slate-50 rounded-xl px-4 py-3">
                                    <Tag :size="14" class="text-primary shrink-0 mt-0.5" />
                                    <div class="flex-1 min-w-0">
                                        <div class="flex items-center gap-2">
                                            <p class="text-sm font-bold text-slate-800">{{ rule.name }}</p>
                                            <span class="text-[10px] bg-primary/10 text-primary px-1.5 py-0.5 rounded-full font-bold">P{{ rule.priority }}</span>
                                        </div>
                                        <p class="text-[11px] text-slate-400 mt-0.5">
                                            {{ dayTypeLabel(rule.day_type) }} · {{ hourLabel(rule.start_hour) }} – {{ hourLabel(rule.end_hour) }}
                                        </p>
                                        <p class="text-sm font-extrabold text-emerald-600 mt-0.5">₹{{ rule.price }}/hr</p>
                                    </div>
                                    <button @click="removeRule(rule)" :disabled="removingId === rule.id"
                                        class="w-7 h-7 rounded-full bg-white flex items-center justify-center active:scale-90 transition">
                                        <Loader2 v-if="removingId === rule.id" :size="12" class="animate-spin text-red-400" />
                                        <Trash2 v-else :size="12" class="text-red-400" />
                                    </button>
                                </div>
                            </div>
                            <p v-else class="text-center text-slate-400 text-sm py-4">No pricing rules — base rate applies</p>

                            <!-- Add form -->
                            <div v-if="adding" class="bg-slate-50 rounded-2xl p-4 space-y-3">
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">New Rule</p>

                                <input v-model="newName" type="text" placeholder="Rule name (e.g. Weekend Peak) *"
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white" />

                                <!-- Day type -->
                                <div>
                                    <p class="text-[10px] font-bold text-slate-400 uppercase mb-1.5">Applies on</p>
                                    <div class="flex gap-2">
                                        <button v-for="dt in DAY_TYPES" :key="dt.value" @click="newDayType = dt.value"
                                            class="flex-1 py-2 rounded-xl text-xs font-bold transition-all"
                                            :class="newDayType === dt.value ? 'bg-primary text-white' : 'bg-white ring-1 ring-slate-200 text-slate-600'">
                                            {{ dt.label }}
                                        </button>
                                    </div>
                                </div>

                                <!-- Hours -->
                                <div class="grid grid-cols-2 gap-2">
                                    <div>
                                        <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">From</p>
                                        <select v-model.number="newStartHour"
                                            class="w-full ring-1 ring-slate-200 rounded-xl px-3 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white">
                                            <option v-for="h in HOURS" :key="h.value" :value="h.value">{{ h.label }}</option>
                                        </select>
                                    </div>
                                    <div>
                                        <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">To</p>
                                        <select v-model.number="newEndHour"
                                            class="w-full ring-1 ring-slate-200 rounded-xl px-3 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white">
                                            <option v-for="h in HOURS" :key="h.value" :value="h.value">{{ h.label }}</option>
                                        </select>
                                    </div>
                                </div>

                                <!-- Price + Priority -->
                                <div class="grid grid-cols-2 gap-2">
                                    <div>
                                        <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">Price (₹/hr) *</p>
                                        <input v-model="newPrice" type="number" placeholder="e.g. 800"
                                            class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white" />
                                    </div>
                                    <div>
                                        <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">Priority</p>
                                        <input v-model.number="newPriority" type="number" placeholder="10"
                                            class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white" />
                                    </div>
                                </div>

                                <div class="flex gap-2">
                                    <button @click="adding = false; resetForm()"
                                        class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-white ring-1 ring-slate-200 text-slate-600">
                                        Cancel
                                    </button>
                                    <button @click="addRule" :disabled="saving"
                                        class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-primary text-white flex items-center justify-center gap-1.5 disabled:opacity-50">
                                        <Loader2 v-if="saving" :size="13" class="animate-spin" />
                                        <span>Add Rule</span>
                                    </button>
                                </div>
                            </div>

                            <button v-else @click="adding = true"
                                class="w-full py-3 rounded-2xl text-sm font-bold border-2 border-dashed border-slate-200 text-slate-500 flex items-center justify-center gap-2 hover:border-primary hover:text-primary transition-all">
                                <Plus :size="14" />
                                Add Pricing Rule
                            </button>

                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
