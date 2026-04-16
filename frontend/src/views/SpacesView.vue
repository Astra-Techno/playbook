<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Plus, Trash2, Loader2, LayoutGrid, Camera, X } from 'lucide-vue-next'

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
            court_id:    courtId,
            owner_id:    auth.user.id,
            name:        newName.value.trim(),
            description: newDesc.value.trim() || null,
            hourly_rate: newRate.value ? parseFloat(newRate.value) : null,
            image_url:   newImageUrl.value || null,
        })
        newName.value = ''; newRate.value = ''; newDesc.value = ''; clearImage()
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
                    class="flex items-center gap-3 bg-white rounded-2xl overflow-hidden shadow-sm ring-1 ring-slate-100">
                    <!-- Photo -->
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
                    </div>
                    <button @click="removeSpace(sc)" :disabled="removingId === sc.id"
                        class="w-10 h-10 flex items-center justify-center shrink-0 mr-2 active:scale-90 transition">
                        <Loader2 v-if="removingId === sc.id" :size="14" class="animate-spin text-red-400" />
                        <Trash2 v-else :size="15" class="text-red-400" />
                    </button>
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
                    <div class="flex gap-2">
                        <button @click="adding = false; clearImage()"
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
