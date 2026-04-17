<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Plus, Trash2, Loader2, LayoutGrid, Camera, X, Lock, Users, Pencil, Check } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const courtId    = route.params.id
const courtName  = ref('')
const spaces     = ref([])
const loading    = ref(true)
const saving     = ref(false)
const removingId = ref(null)

const newName     = ref('')
const newRate     = ref('')
const newDesc     = ref('')
const newImageUrl = ref('')
const imagePreview = ref('')
const uploadLoading = ref(false)
const adding      = ref(false)
const newMode     = ref('exclusive')
const newCapacity = ref(1)

// Edit state
const editingId       = ref(null)
const editSaving      = ref(false)
const editUploadLoading = ref(false)
const editForm        = ref({ name: '', hourly_rate: '', description: '', booking_mode: 'exclusive', capacity: 1, image_url: '', imagePreview: '' })

const startEdit = (sc) => {
    editingId.value = sc.id
    editForm.value  = {
        name:         sc.name,
        hourly_rate:  sc.hourly_rate ?? '',
        description:  sc.description ?? '',
        booking_mode: sc.booking_mode || 'exclusive',
        capacity:     sc.capacity || 1,
        image_url:    sc.image_url || '',
        imagePreview: sc.image_url || '',
    }
}

const cancelEdit = () => { editingId.value = null }

const handleEditImageSelect = async (e) => {
    const file = e.target.files[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (ev) => { editForm.value.imagePreview = ev.target.result }
    reader.readAsDataURL(file)
    editUploadLoading.value = true
    try {
        const formData = new FormData()
        formData.append('image', file)
        const res = await axios.post('/upload', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
        editForm.value.image_url = res.data.url
    } catch { toast.error('Image upload failed') }
    finally { editUploadLoading.value = false }
}

const saveEdit = async () => {
    if (!editForm.value.name.trim()) { toast.error('Enter a name'); return }
    editSaving.value = true
    try {
        await axios.put(`/sub-courts/${editingId.value}`, {
            owner_id:     auth.user.id,
            name:         editForm.value.name.trim(),
            description:  editForm.value.description.trim() || null,
            hourly_rate:  editForm.value.hourly_rate !== '' ? parseFloat(editForm.value.hourly_rate) : null,
            image_url:    editForm.value.image_url || null,
            booking_mode: editForm.value.booking_mode,
            capacity:     editForm.value.booking_mode === 'shared' ? Math.max(1, parseInt(editForm.value.capacity) || 1) : 1,
        })
        const res = await axios.get(`/sub-courts?court_id=${courtId}`)
        spaces.value = res.data.sub_courts || []
        editingId.value = null
        toast.success('Space updated')
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to update')
    } finally { editSaving.value = false }
}

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

const handleImageSelect = async (e) => {
    const file = e.target.files[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (ev) => { imagePreview.value = ev.target.result }
    reader.readAsDataURL(file)
    uploadLoading.value = true
    try {
        const formData = new FormData()
        formData.append('image', file)
        const res = await axios.post('/upload', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
        newImageUrl.value = res.data.url
    } catch { toast.error('Image upload failed') }
    finally { uploadLoading.value = false }
}

const clearImage = () => { newImageUrl.value = ''; imagePreview.value = '' }

const addSpace = async () => {
    if (!newName.value.trim()) { toast.error('Enter a name'); return }
    saving.value = true
    try {
        await axios.post('/sub-courts', {
            court_id:     courtId,
            owner_id:     auth.user.id,
            name:         newName.value.trim(),
            description:  newDesc.value.trim() || null,
            hourly_rate:  newRate.value ? parseFloat(newRate.value) : null,
            image_url:    newImageUrl.value || null,
            booking_mode: newMode.value,
            capacity:     newMode.value === 'shared' ? Math.max(1, parseInt(newCapacity.value) || 1) : 1,
        })
        newName.value = ''; newRate.value = ''; newDesc.value = ''; clearImage(); newMode.value = 'exclusive'; newCapacity.value = 1
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
    <!-- Teleport title into app header -->
    <Teleport to="#header-subject">{{ courtName || 'Spaces' }}</Teleport>
    <Teleport to="#header-subtitle">Spaces</Teleport>

    <div class="min-h-screen bg-slate-50 pb-24">

        <div class="px-5 py-5 space-y-4">

            <!-- Info banner -->
            <div class="bg-blue-50 rounded-xl px-4 py-3 text-xs text-blue-700 leading-relaxed">
                Add individual bookable spaces — e.g. Court A/B, Lane 1/2, Table 1, Dance Room. Players can pick a specific space when booking.
            </div>

            <!-- Loading -->
            <div v-if="loading" class="space-y-3">
                <div v-for="i in 3" :key="i" class="h-20 bg-slate-100 rounded-2xl animate-pulse"></div>
            </div>

            <!-- Spaces list -->
            <div v-else-if="spaces.length" class="space-y-3">
                <div v-for="sc in spaces" :key="sc.id"
                    class="bg-white rounded-2xl overflow-hidden shadow-sm ring-1 ring-slate-100">

                    <!-- Compact view -->
                    <div v-if="editingId !== sc.id" class="flex items-center gap-3">
                        <div class="w-20 h-20 shrink-0 bg-slate-100 flex items-center justify-center overflow-hidden">
                            <img v-if="sc.image_url" :src="sc.image_url" class="w-full h-full object-cover" onerror="this.style.display='none'" />
                            <LayoutGrid v-else :size="22" :stroke-width="1.5" class="text-slate-300" />
                        </div>
                        <div class="flex-1 min-w-0 py-3 pr-1">
                            <p class="text-sm font-bold text-slate-800">{{ sc.name }}</p>
                            <p class="text-[11px] text-slate-400 mt-0.5">
                                {{ sc.hourly_rate ? `₹${sc.hourly_rate}/hr` : 'Inherits venue rate' }}
                                <span v-if="sc.description"> · {{ sc.description }}</span>
                            </p>
                            <div class="flex items-center gap-1.5 mt-1">
                                <span class="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full"
                                    :class="sc.booking_mode === 'shared' ? 'bg-cyan-50 text-cyan-600' : 'bg-slate-100 text-slate-500'">
                                    <Users v-if="sc.booking_mode === 'shared'" :size="10" />
                                    <Lock v-else :size="10" />
                                    {{ sc.booking_mode === 'shared' ? `Shared · ${sc.capacity} spots` : 'Exclusive' }}
                                </span>
                            </div>
                        </div>
                        <div class="flex items-center gap-1 mr-2 shrink-0">
                            <button @click="startEdit(sc)"
                                class="w-9 h-9 flex items-center justify-center rounded-xl bg-slate-50 active:scale-90 transition">
                                <Pencil :size="14" class="text-slate-400" />
                            </button>
                            <button @click="removeSpace(sc)" :disabled="removingId === sc.id"
                                class="w-9 h-9 flex items-center justify-center active:scale-90 transition">
                                <Loader2 v-if="removingId === sc.id" :size="14" class="animate-spin text-red-400" />
                                <Trash2 v-else :size="14" class="text-red-400" />
                            </button>
                        </div>
                    </div>

                    <!-- Inline edit form -->
                    <div v-else>
                        <!-- Image picker -->
                        <div class="relative h-36 bg-slate-100">
                            <img v-if="editForm.imagePreview" :src="editForm.imagePreview" class="w-full h-full object-cover" />
                            <div v-else class="w-full h-full flex flex-col items-center justify-center gap-2">
                                <Camera :size="24" class="text-slate-300" />
                                <p class="text-xs text-slate-400">Change photo</p>
                            </div>
                            <label class="absolute inset-0 cursor-pointer">
                                <input type="file" accept="image/*" class="hidden" @change="handleEditImageSelect" />
                            </label>
                            <div v-if="editUploadLoading" class="absolute inset-0 bg-white/70 flex items-center justify-center">
                                <Loader2 :size="20" class="animate-spin text-primary" />
                            </div>
                            <button v-if="editForm.imagePreview" @click.stop="editForm.imagePreview = ''; editForm.image_url = ''"
                                class="absolute top-2 right-2 w-7 h-7 rounded-full bg-black/50 flex items-center justify-center">
                                <X :size="13" class="text-white" />
                            </button>
                        </div>
                        <div class="p-4 space-y-3">
                            <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">Edit Space</p>
                            <input v-model="editForm.name" type="text" placeholder="Name *"
                                class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                            <input v-model="editForm.hourly_rate" type="number" placeholder="Hourly rate (blank = venue rate)"
                                class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                            <input v-model="editForm.description" type="text" placeholder="Description (optional)"
                                class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                            <div>
                                <p class="text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1.5">Booking Type</p>
                                <div class="flex gap-2">
                                    <button @click="editForm.booking_mode = 'exclusive'; editForm.capacity = 1"
                                        class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl text-xs font-bold transition-all"
                                        :class="editForm.booking_mode === 'exclusive' ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500'">
                                        <Lock :size="12" /> Exclusive
                                    </button>
                                    <button @click="editForm.booking_mode = 'shared'"
                                        class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl text-xs font-bold transition-all"
                                        :class="editForm.booking_mode === 'shared' ? 'bg-cyan-500 text-white' : 'bg-slate-100 text-slate-500'">
                                        <Users :size="12" /> Shared
                                    </button>
                                </div>
                            </div>
                            <div v-if="editForm.booking_mode === 'shared'">
                                <p class="text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1.5">Max Capacity</p>
                                <input v-model.number="editForm.capacity" type="number" min="2"
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                            </div>
                            <div class="flex gap-2">
                                <button @click="cancelEdit"
                                    class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-slate-100 text-slate-600">Cancel</button>
                                <button @click="saveEdit" :disabled="editSaving || editUploadLoading"
                                    class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-primary text-white flex items-center justify-center gap-1.5 disabled:opacity-50">
                                    <Loader2 v-if="editSaving" :size="13" class="animate-spin" />
                                    <Check v-else :size="13" />
                                    Save
                                </button>
                            </div>
                        </div>
                    </div>

                </div>
            </div>
            <p v-else-if="!loading" class="text-center text-slate-400 text-sm py-6">No spaces added yet</p>

            <!-- Add form -->
            <div v-if="adding" class="bg-white rounded-2xl overflow-hidden shadow-sm ring-1 ring-slate-100">
                <!-- Image picker -->
                <div class="relative h-40 bg-slate-100">
                    <img v-if="imagePreview" :src="imagePreview" class="w-full h-full object-cover" />
                    <div v-else class="w-full h-full flex flex-col items-center justify-center gap-2">
                        <Camera :size="28" class="text-slate-300" />
                        <p class="text-xs text-slate-400">Add photo (optional)</p>
                    </div>
                    <label class="absolute inset-0 cursor-pointer">
                        <input type="file" accept="image/*" class="hidden" @change="handleImageSelect" />
                    </label>
                    <div v-if="uploadLoading" class="absolute inset-0 bg-white/70 flex items-center justify-center">
                        <Loader2 :size="22" class="animate-spin text-primary" />
                    </div>
                    <button v-if="imagePreview" @click.stop="clearImage"
                        class="absolute top-2 right-2 w-7 h-7 rounded-full bg-black/50 flex items-center justify-center">
                        <X :size="14" class="text-white" />
                    </button>
                </div>

                <div class="p-4 space-y-3">
                    <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">New Space</p>
                    <input v-model="newName" type="text" placeholder="Name (e.g. Court A, Lane 1, Table 2) *"
                        class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                    <input v-model="newRate" type="number" placeholder="Hourly rate (leave blank to use venue rate)"
                        class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                    <input v-model="newDesc" type="text" placeholder="Description (optional)"
                        class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                    <!-- Booking mode toggle -->
                    <div>
                        <p class="text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1.5">Booking Type</p>
                        <div class="flex gap-2">
                            <button @click="newMode = 'exclusive'; newCapacity = 1"
                                class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl text-xs font-bold transition-all"
                                :class="newMode === 'exclusive' ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500'">
                                <Lock :size="12" /> Exclusive
                            </button>
                            <button @click="newMode = 'shared'"
                                class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl text-xs font-bold transition-all"
                                :class="newMode === 'shared' ? 'bg-cyan-500 text-white' : 'bg-slate-100 text-slate-500'">
                                <Users :size="12" /> Shared
                            </button>
                        </div>
                        <p class="text-[10px] text-slate-400 mt-1 px-1">
                            <template v-if="newMode === 'exclusive'">One booking at a time (courts, turfs)</template>
                            <template v-else>Multiple simultaneous bookings (pool, gym)</template>
                        </p>
                    </div>
                    <!-- Capacity (shared only) -->
                    <div v-if="newMode === 'shared'">
                        <p class="text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1.5">Max Capacity</p>
                        <input v-model.number="newCapacity" type="number" min="2" placeholder="e.g. 20 (max simultaneous users)"
                            class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-2.5 text-sm focus:ring-primary focus:outline-none bg-slate-50" />
                    </div>
                    <div class="flex gap-2">
                        <button @click="adding = false; clearImage(); newMode = 'exclusive'; newCapacity = 1"
                            class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-slate-100 text-slate-600">Cancel</button>
                        <button @click="addSpace" :disabled="saving || uploadLoading"
                            class="flex-1 py-2.5 rounded-xl text-sm font-bold bg-primary text-white flex items-center justify-center gap-1.5 disabled:opacity-50">
                            <Loader2 v-if="saving" :size="13" class="animate-spin" />
                            <span>Add Space</span>
                        </button>
                    </div>
                </div>
            </div>

            <button v-else @click="adding = true"
                class="w-full py-3.5 rounded-2xl text-sm font-bold border-2 border-dashed border-slate-200 text-slate-500 flex items-center justify-center gap-2 hover:border-primary hover:text-primary transition-all">
                <Plus :size="14" /> Add Space
            </button>

        </div>
    </div>
</template>
