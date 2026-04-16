<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Plus, Trash2, Loader2, LayoutGrid } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const courtId   = route.params.id
const courtName = ref('')
const spaces    = ref([])
const loading   = ref(true)
const saving    = ref(false)
const removingId = ref(null)

const newName  = ref('')
const newRate  = ref('')
const newDesc  = ref('')
const adding   = ref(false)

onMounted(async () => {
    try {
        const [courtRes, spacesRes] = await Promise.all([
            axios.get(`/courts/${courtId}`),
            axios.get(`/sub-courts?court_id=${courtId}`)
        ])
        courtName.value = courtRes.data.court?.name ?? ''
        spaces.value    = spacesRes.data.sub_courts || []
    } catch { toast.error('Failed to load') }
    finally { loading.value = false }
})

const addSpace = async () => {
    if (!newName.value.trim()) { toast.error('Enter a name'); return }
    saving.value = true
    try {
        await axios.post('/sub-courts', {
            court_id:    courtId,
            owner_id:    auth.user.id,
            name:        newName.value.trim(),
            description: newDesc.value.trim() || null,
            hourly_rate: newRate.value ? parseFloat(newRate.value) : null,
        })
        newName.value = ''; newRate.value = ''; newDesc.value = ''
        adding.value = false
        const res = await axios.get(`/sub-courts?court_id=${courtId}`)
        spaces.value = res.data.sub_courts || []
        toast.success('Space added')
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to add')
    } finally { saving.value = false }
}

const removeSpace = async (sc) => {
    removingId.value = sc.id
    try {
        await axios.delete(`/sub-courts/${sc.id}`, { data: { owner_id: auth.user.id } })
        spaces.value = spaces.value.filter(s => s.id !== sc.id)
        toast.success('Removed')
    } catch { toast.error('Failed to remove') }
    finally { removingId.value = null }
}
</script>

<template>
    <div class="min-h-screen bg-slate-50">
        <!-- Header -->
        <div class="bg-white px-5 pt-5 pb-5 border-b border-slate-100">
            <p v-if="courtName" class="text-[10px] font-black text-primary uppercase tracking-wider mb-0.5">{{ courtName }}</p>
            <h1 class="text-lg font-bold text-slate-900">Spaces</h1>
            <p class="text-xs text-slate-500">Manage bookable spaces inside this venue</p>
        </div>

        <div class="px-5 py-5 pb-8 space-y-5">
            <!-- Info -->
            <div class="bg-blue-50 rounded-xl px-4 py-3 text-xs text-blue-700 leading-relaxed">
                Add individual bookable spaces — e.g. Court A/B, Lane 1/2, Table 1, Dance Room. Players can pick a specific space when booking.
            </div>

            <!-- Loading -->
            <div v-if="loading" class="space-y-2">
                <div v-for="i in 3" :key="i" class="h-14 bg-slate-100 rounded-xl animate-pulse"></div>
            </div>

            <!-- List -->
            <div v-else-if="spaces.length" class="space-y-2">
                <div v-for="sc in spaces" :key="sc.id"
                    class="flex items-center gap-3 bg-white rounded-xl px-4 py-3 shadow-sm ring-1 ring-slate-100">
                    <LayoutGrid :size="14" class="text-primary shrink-0" />
                    <div class="flex-1 min-w-0">
                        <p class="text-sm font-bold text-slate-800">{{ sc.name }}</p>
                        <p class="text-[11px] text-slate-400">
                            {{ sc.hourly_rate ? `₹${sc.hourly_rate}/hr` : 'Inherits venue rate' }}
                            <span v-if="sc.description"> · {{ sc.description }}</span>
                        </p>
                    </div>
                    <button @click="removeSpace(sc)" :disabled="removingId === sc.id"
                        class="w-8 h-8 rounded-full bg-red-50 flex items-center justify-center active:scale-90 transition">
                        <Loader2 v-if="removingId === sc.id" :size="12" class="animate-spin text-red-400" />
                        <Trash2 v-else :size="13" class="text-red-400" />
                    </button>
                </div>
            </div>
            <p v-else-if="!loading" class="text-center text-slate-400 text-sm py-6">No spaces added yet</p>

            <!-- Add form -->
            <div v-if="adding" class="bg-white rounded-2xl p-4 space-y-3 shadow-sm ring-1 ring-slate-100">
                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">New Space</p>
                <input v-model="newName" type="text" placeholder="Name (e.g. Court A, Lane 1, Table 2) *"
                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                <input v-model="newRate" type="number" placeholder="Hourly rate (leave blank to use venue rate)"
                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                <input v-model="newDesc" type="text" placeholder="Description (optional)"
                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                <div class="flex gap-2">
                    <button @click="adding = false"
                        class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-slate-100 text-slate-600">Cancel</button>
                    <button @click="addSpace" :disabled="saving"
                        class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-primary text-white flex items-center justify-center gap-1.5 disabled:opacity-50">
                        <Loader2 v-if="saving" :size="13" class="animate-spin" />
                        <span>Add</span>
                    </button>
                </div>
            </div>

            <button v-else @click="adding = true"
                class="w-full py-3.5 rounded-2xl text-sm font-bold border-2 border-dashed border-slate-200 text-slate-500 flex items-center justify-center gap-2 hover:border-primary hover:text-primary transition-all">
                <Plus :size="14" /> Add Space
            </button>
        </div>
    </div>
</template>
