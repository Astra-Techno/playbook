<script setup>
import { ref, watch } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { X, Plus, Trash2, Loader2, LayoutGrid } from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    court: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue', 'changed'])

const auth  = useAuthStore()
const toast = useToastStore()

const subCourts  = ref([])
const loading    = ref(false)
const saving     = ref(false)
const removingId = ref(null)

const newName  = ref('')
const newRate  = ref('')
const newDesc  = ref('')
const adding   = ref(false)

const close = () => emit('update:modelValue', false)

const fetchSubCourts = async () => {
    if (!props.court) return
    loading.value = true
    try {
        const res = await axios.get(`/sub-courts?court_id=${props.court.id}`)
        subCourts.value = res.data.sub_courts || []
    } catch { subCourts.value = [] }
    finally { loading.value = false }
}

watch(() => props.modelValue, open => {
    if (open) { newName.value = ''; newRate.value = ''; newDesc.value = ''; fetchSubCourts() }
})

const addSubCourt = async () => {
    if (!newName.value.trim()) { toast.error('Enter a name'); return }
    saving.value = true
    try {
        await axios.post('/sub-courts', {
            court_id:    props.court.id,
            owner_id:    auth.user.id,
            name:        newName.value.trim(),
            description: newDesc.value.trim() || null,
            hourly_rate: newRate.value ? parseFloat(newRate.value) : null,
        })
        newName.value = ''; newRate.value = ''; newDesc.value = ''
        adding.value = false
        await fetchSubCourts()
        emit('changed')
        toast.success('Space added')
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to add')
    } finally { saving.value = false }
}

const removeSubCourt = async (sc) => {
    removingId.value = sc.id
    try {
        await axios.delete(`/sub-courts/${sc.id}`, { data: { owner_id: auth.user.id } })
        subCourts.value = subCourts.value.filter(s => s.id !== sc.id)
        emit('changed')
        toast.success('Removed')
    } catch { toast.error('Failed to remove') }
    finally { removingId.value = null }
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
                                    <h3 class="text-base font-extrabold text-slate-900">Spaces</h3>
                                </div>
                                <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <div class="flex-1 overflow-y-auto px-5 py-5 space-y-5">

                            <!-- Info banner -->
                            <div class="bg-blue-50 rounded-xl px-4 py-3 text-xs text-blue-700 leading-relaxed">
                                Add individual bookable spaces inside this venue — e.g. Court A/B, Lane 1/2, Table 1, Dance Room. Players can pick a specific space when booking.
                            </div>

                            <!-- Sub-court list -->
                            <div v-if="loading" class="space-y-2">
                                <div v-for="i in 3" :key="i" class="h-14 bg-slate-100 rounded-xl animate-pulse"></div>
                            </div>
                            <div v-else-if="subCourts.length" class="space-y-2">
                                <div v-for="sc in subCourts" :key="sc.id"
                                    class="flex items-center gap-3 bg-slate-50 rounded-xl px-4 py-3">
                                    <LayoutGrid :size="14" class="text-primary shrink-0" />
                                    <div class="flex-1 min-w-0">
                                        <p class="text-sm font-bold text-slate-800">{{ sc.name }}</p>
                                        <p class="text-[11px] text-slate-400">
                                            {{ sc.hourly_rate ? `₹${sc.hourly_rate}/hr` : 'Inherits venue rate' }}
                                            <span v-if="sc.description"> · {{ sc.description }}</span>
                                        </p>
                                    </div>
                                    <button @click="removeSubCourt(sc)" :disabled="removingId === sc.id"
                                        class="w-7 h-7 rounded-full bg-white flex items-center justify-center active:scale-90 transition">
                                        <Loader2 v-if="removingId === sc.id" :size="12" class="animate-spin text-red-400" />
                                        <Trash2 v-else :size="12" class="text-red-400" />
                                    </button>
                                </div>
                            </div>
                            <p v-else class="text-center text-slate-400 text-sm py-4">No spaces added yet</p>

                            <!-- Add form -->
                            <div v-if="adding" class="bg-slate-50 rounded-2xl p-4 space-y-3">
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">New Space</p>
                                <input v-model="newName" type="text" placeholder="Name (e.g. Court A, Lane 1, Table 2) *"
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white" />
                                <input v-model="newRate" type="number" placeholder="Hourly rate (leave blank to use venue rate)"
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white" />
                                <input v-model="newDesc" type="text" placeholder="Description (optional)"
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-white" />
                                <div class="flex gap-2">
                                    <button @click="adding = false"
                                        class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-white ring-1 ring-slate-200 text-slate-600">
                                        Cancel
                                    </button>
                                    <button @click="addSubCourt" :disabled="saving"
                                        class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-primary text-white flex items-center justify-center gap-1.5 disabled:opacity-50">
                                        <Loader2 v-if="saving" :size="13" class="animate-spin" />
                                        <span>Add</span>
                                    </button>
                                </div>
                            </div>

                            <button v-else @click="adding = true"
                                class="w-full py-3 rounded-2xl text-sm font-bold border-2 border-dashed border-slate-200 text-slate-500 flex items-center justify-center gap-2 hover:border-primary hover:text-primary transition-all">
                                <Plus :size="14" />
                                Add Space
                            </button>

                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
