<script setup>
import { ref, watch } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    X, MapPin, Star, Users, IndianRupee, Loader2,
    BadgeCheck, Upload, Clock, CheckCircle2, Camera
} from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    place: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue', 'claimed'])

const auth   = useAuthStore()
const toast  = useToastStore()

const hourlyRate    = ref('')
const description   = ref('')
const proofUrl      = ref('')
const proofPreview  = ref(null)
const uploadLoading = ref(false)
const loading       = ref(false)
const submitted     = ref(false)   // show success/pending screen

watch(() => props.modelValue, (open) => {
    if (open) {
        hourlyRate.value   = ''
        description.value  = ''
        proofUrl.value     = ''
        proofPreview.value = null
        submitted.value    = false
    }
})

const close = () => emit('update:modelValue', false)

const handleProofUpload = async (event) => {
    const file = event.target.files[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (e) => { proofPreview.value = e.target.result }
    reader.readAsDataURL(file)
    uploadLoading.value = true
    try {
        const formData = new FormData()
        formData.append('image', file)
        const res = await axios.post('/upload', formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
        })
        proofUrl.value = res.data.url
    } catch {
        toast.error('Photo upload failed')
        proofPreview.value = null
    } finally {
        uploadLoading.value = false
        event.target.value = ''
    }
}

const submit = async () => {
    if (!auth.isLoggedIn) { close(); return }
    if (!hourlyRate.value || isNaN(hourlyRate.value) || Number(hourlyRate.value) <= 0) {
        toast.error('Enter a valid hourly rate'); return
    }
    if (!proofUrl.value) {
        toast.error('Please upload proof of ownership'); return
    }
    loading.value = true
    try {
        const res = await axios.post('/courts/claim', {
            owner_id:    auth.user.id,
            place_id:    props.place.id,
            hourly_rate: Number(hourlyRate.value),
            description: description.value.trim(),
            proof_url:   proofUrl.value,
        })
        submitted.value = true
        emit('claimed', res.data.court_id)
    } catch (err) {
        toast.error(err.response?.data?.message || 'Could not submit claim')
    } finally {
        loading.value = false
    }
}
</script>

<template>
    <Teleport to="#app-root">
        <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="opacity-0" enter-to-class="opacity-100"
                    leave-active-class="transition duration-200 ease-in"  leave-from-class="opacity-100" leave-to-class="opacity-0">
            <div v-if="modelValue && place" class="absolute inset-0 bg-black/50 z-[160]" @click.self="close">
                <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="translate-y-full" enter-to-class="translate-y-0"
                            leave-active-class="transition duration-200 ease-in"  leave-from-class="translate-y-0"    leave-to-class="translate-y-full">
                    <div v-if="modelValue" class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl overflow-hidden max-h-[92vh] flex flex-col">

                        <!-- Handle -->
                        <div class="pt-3 pb-1 flex justify-center shrink-0">
                            <div class="w-10 h-1 bg-slate-200 rounded-full"></div>
                        </div>

                        <!-- Header -->
                        <div class="flex items-center justify-between px-5 py-3 shrink-0 border-b border-slate-100">
                            <div>
                                <p class="text-[10px] font-black text-primary uppercase tracking-wider">Claim this Venue</p>
                                <h3 class="text-base font-extrabold text-slate-900 leading-tight">
                                    {{ submitted ? 'Claim Submitted!' : 'List on KoCourt' }}
                                </h3>
                            </div>
                            <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                                <X :size="16" class="text-slate-500" />
                            </button>
                        </div>

                        <!-- ── PENDING SUCCESS STATE ── -->
                        <div v-if="submitted" class="flex-1 flex flex-col items-center justify-center px-6 py-10 text-center space-y-4">
                            <div class="w-20 h-20 bg-amber-100 rounded-full flex items-center justify-center">
                                <Clock :size="36" class="text-amber-600" />
                            </div>
                            <div>
                                <p class="text-xl font-extrabold text-slate-900">Under Review</p>
                                <p class="text-sm text-slate-500 mt-1 leading-relaxed">
                                    Your claim for <strong>{{ place.name }}</strong> has been submitted.<br>
                                    Our team will verify your proof and approve within <strong>24–48 hours</strong>.
                                </p>
                            </div>
                            <div class="w-full bg-slate-50 rounded-2xl p-4 space-y-2 text-left">
                                <div v-for="(step, i) in [
                                    { label: 'Claim submitted', done: true },
                                    { label: 'Team reviews your proof', done: false },
                                    { label: 'Court goes live & you start earning', done: false },
                                ]" :key="i" class="flex items-center gap-3">
                                    <div class="w-5 h-5 rounded-full flex items-center justify-center shrink-0"
                                        :class="step.done ? 'bg-emerald-500' : 'bg-slate-200'">
                                        <CheckCircle2 v-if="step.done" :size="12" class="text-white" />
                                        <span v-else class="text-[9px] font-black text-slate-400">{{ i + 1 }}</span>
                                    </div>
                                    <p class="text-xs font-medium" :class="step.done ? 'text-emerald-700' : 'text-slate-500'">
                                        {{ step.label }}
                                    </p>
                                </div>
                            </div>
                            <button @click="close"
                                class="w-full bg-primary text-white font-extrabold py-4 rounded-2xl text-sm">
                                Got it
                            </button>
                        </div>

                        <!-- ── CLAIM FORM ── -->
                        <div v-else class="flex-1 overflow-y-auto px-5 pb-8 space-y-5 pt-4">

                            <!-- Venue preview card -->
                            <div class="rounded-2xl overflow-hidden ring-1 ring-slate-100 shadow-sm">
                                <div class="relative h-32">
                                    <img :src="place.image_url" :alt="place.name"
                                        class="w-full h-full object-cover"
                                        onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80'" />
                                    <div class="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent"></div>
                                    <div class="absolute bottom-3 left-3">
                                        <span class="bg-white/90 text-slate-700 text-[10px] font-extrabold px-3 py-1 rounded-full uppercase">{{ place.type }}</span>
                                    </div>
                                    <div v-if="place.rating" class="absolute top-3 right-3">
                                        <span class="bg-white/90 text-amber-700 text-[10px] font-extrabold px-2.5 py-1 rounded-full flex items-center gap-1">
                                            <Star :size="10" class="fill-amber-400 text-amber-400" />
                                            {{ place.rating }}
                                        </span>
                                    </div>
                                </div>
                                <div class="bg-white px-4 py-3">
                                    <p class="font-extrabold text-slate-900 text-[15px]">{{ place.name }}</p>
                                    <div class="flex items-center gap-1 text-slate-400 text-xs mt-1">
                                        <MapPin :size="11" class="shrink-0" />
                                        <span class="truncate">{{ place.address }}</span>
                                    </div>
                                    <div v-if="place.request_count > 0" class="flex items-center gap-1.5 mt-2">
                                        <Users :size="12" class="text-primary" />
                                        <span class="text-[11px] font-bold text-primary">
                                            {{ place.request_count }} {{ place.request_count === 1 ? 'person' : 'people' }} waiting for this venue
                                        </span>
                                    </div>
                                </div>
                            </div>

                            <!-- Role upgrade notice -->
                            <div v-if="auth.isLoggedIn && !auth.isOwner"
                                class="flex items-start gap-3 bg-amber-50 border border-amber-100 rounded-2xl px-4 py-3">
                                <BadgeCheck :size="18" class="text-amber-600 shrink-0 mt-0.5" />
                                <p class="text-xs text-amber-800 font-medium leading-relaxed">
                                    Your account will be upgraded to <strong>Venue Owner</strong> once your claim is approved.
                                </p>
                            </div>

                            <!-- Proof of ownership (required) -->
                            <div>
                                <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">
                                    Proof of Ownership <span class="text-red-400">*</span>
                                </label>
                                <p class="text-[11px] text-slate-400 mb-3">
                                    Upload a photo of your <strong>GST certificate</strong>, <strong>shop/establishment license</strong>, or a <strong>selfie inside the venue</strong>.
                                </p>
                                <div class="relative rounded-2xl overflow-hidden border-2 border-dashed border-slate-200 bg-slate-50"
                                    :class="proofPreview ? 'border-solid border-emerald-200 bg-emerald-50/30' : ''">
                                    <!-- Preview -->
                                    <img v-if="proofPreview" :src="proofPreview"
                                        class="w-full h-40 object-cover rounded-2xl" />
                                    <!-- Placeholder -->
                                    <div v-else class="flex flex-col items-center gap-2 py-8 pointer-events-none">
                                        <Camera :size="28" class="text-slate-300" />
                                        <p class="text-sm font-medium text-slate-400">Tap to upload proof</p>
                                        <p class="text-[11px] text-slate-300">JPG, PNG · Max 5 MB</p>
                                    </div>
                                    <!-- Uploading spinner -->
                                    <div v-if="uploadLoading" class="absolute inset-0 bg-white/80 flex items-center justify-center rounded-2xl">
                                        <Loader2 :size="24" class="animate-spin text-primary" />
                                    </div>
                                    <!-- Verified checkmark -->
                                    <div v-if="proofUrl && !uploadLoading"
                                        class="absolute top-2 right-2 w-7 h-7 bg-emerald-500 rounded-full flex items-center justify-center shadow">
                                        <CheckCircle2 :size="14" class="text-white" />
                                    </div>
                                    <!-- File input overlaid -->
                                    <input type="file" accept="image/jpeg,image/png,image/webp,application/pdf"
                                        @change="handleProofUpload"
                                        class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                                </div>
                                <p v-if="proofUrl && !uploadLoading" class="text-[11px] text-emerald-600 font-semibold mt-1.5">
                                    ✓ Proof uploaded successfully
                                </p>
                            </div>

                            <!-- Hourly rate -->
                            <div>
                                <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">
                                    Hourly Rate <span class="text-red-400">*</span>
                                </label>
                                <div class="flex items-center gap-2 ring-1 ring-slate-200 rounded-xl px-4 h-12 bg-white focus-within:ring-primary transition-all">
                                    <IndianRupee :size="16" class="text-slate-400 shrink-0" />
                                    <input v-model="hourlyRate" type="number" min="1" placeholder="e.g. 500"
                                        class="flex-1 text-sm font-bold bg-transparent border-none focus:ring-0 placeholder:text-slate-300" />
                                    <span class="text-xs text-slate-400 font-medium shrink-0">/ hr</span>
                                </div>
                            </div>

                            <!-- Description (optional) -->
                            <div>
                                <label class="text-[11px] font-black text-slate-400 uppercase tracking-wider block mb-2">
                                    Description <span class="text-slate-300 font-normal normal-case">(optional)</span>
                                </label>
                                <textarea v-model="description" rows="3" placeholder="Facilities, courts available, parking..."
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm bg-white focus:ring-primary focus:outline-none resize-none placeholder:text-slate-300 transition-all" />
                            </div>

                            <!-- What happens next -->
                            <div class="bg-slate-50 rounded-2xl px-4 py-4 space-y-2.5">
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">What happens next</p>
                                <div v-for="(step, i) in [
                                    'Our team reviews your proof (24–48 hrs)',
                                    'Court goes live once approved',
                                    'Set schedule · Players book · You earn',
                                ]" :key="i" class="flex items-center gap-3">
                                    <div class="w-5 h-5 rounded-full bg-primary text-white text-[10px] font-black flex items-center justify-center shrink-0">{{ i + 1 }}</div>
                                    <p class="text-xs text-slate-600 font-medium">{{ step }}</p>
                                </div>
                            </div>

                            <!-- CTA -->
                            <button @click="submit" :disabled="loading || uploadLoading"
                                class="w-full bg-primary text-white font-extrabold py-4 rounded-2xl text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition-transform disabled:opacity-60">
                                <Loader2 v-if="loading" :size="16" class="animate-spin" />
                                <template v-else>
                                    <Upload :size="15" />
                                    Submit Claim for Review
                                </template>
                            </button>

                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
