<script setup>
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    X, MapPin, Star, Users, IndianRupee, Loader2,
    BadgeCheck, ChevronRight
} from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    place: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue', 'claimed'])

const auth   = useAuthStore()
const toast  = useToastStore()
const router = useRouter()

const hourlyRate  = ref('')
const description = ref('')
const loading     = ref(false)

watch(() => props.modelValue, (open) => {
    if (open) { hourlyRate.value = ''; description.value = '' }
})

const close = () => emit('update:modelValue', false)

const submit = async () => {
    if (!auth.isLoggedIn) { close(); router.push('/login'); return }
    if (!hourlyRate.value || isNaN(hourlyRate.value) || Number(hourlyRate.value) <= 0) {
        toast.error('Enter a valid hourly rate'); return
    }
    loading.value = true
    try {
        const res = await axios.post('/courts/claim', {
            owner_id:    auth.user.id,
            place_id:    props.place.id,
            hourly_rate: Number(hourlyRate.value),
            description: description.value.trim(),
        })
        // Update auth store if role was upgraded to owner
        if (res.data.user) {
            auth.setAuth(res.data.user, localStorage.getItem('token'))
        }
        toast.success('Venue claimed! Set up your schedule next.')
        emit('claimed', res.data.court_id)
        close()
        router.push('/my-services')
    } catch (err) {
        toast.error(err.response?.data?.message || 'Could not claim venue')
    } finally {
        loading.value = false
    }
}
</script>

<template>
    <Teleport to="#app-root">
        <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="modelValue && place" class="absolute inset-0 bg-black/50 z-[160]" @click.self="close">
                <Transition
                    enter-active-class="transition duration-300 ease-out"
                    enter-from-class="translate-y-full"
                    enter-to-class="translate-y-0"
                    leave-active-class="transition duration-200 ease-in"
                    leave-from-class="translate-y-0"
                    leave-to-class="translate-y-full">
                    <div v-if="modelValue" class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl overflow-hidden max-h-[90vh] flex flex-col">

                        <!-- Handle -->
                        <div class="pt-3 pb-1 flex justify-center shrink-0">
                            <div class="w-10 h-1 bg-slate-200 rounded-full"></div>
                        </div>

                        <!-- Header -->
                        <div class="flex items-center justify-between px-5 py-3 shrink-0">
                            <div>
                                <p class="text-[10px] font-black text-primary uppercase tracking-wider">Claim this Venue</p>
                                <h3 class="text-base font-extrabold text-slate-900 leading-tight">List on KoCourt</h3>
                            </div>
                            <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                                <X :size="16" class="text-slate-500" />
                            </button>
                        </div>

                        <div class="flex-1 overflow-y-auto px-5 pb-8 space-y-5">

                            <!-- Venue preview card -->
                            <div class="rounded-2xl overflow-hidden ring-1 ring-slate-100 shadow-sm">
                                <div class="relative h-36">
                                    <img :src="place.image_url" :alt="place.name"
                                        class="w-full h-full object-cover"
                                        onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80'" />
                                    <div class="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent"></div>
                                    <div class="absolute bottom-3 left-3">
                                        <span class="bg-white/90 text-slate-700 text-[10px] font-extrabold px-3 py-1 rounded-full uppercase">
                                            {{ place.type }}
                                        </span>
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

                            <!-- Role upgrade notice for players -->
                            <div v-if="auth.isLoggedIn && !auth.isOwner"
                                class="flex items-start gap-3 bg-amber-50 border border-amber-100 rounded-2xl px-4 py-3">
                                <BadgeCheck :size="18" class="text-amber-600 shrink-0 mt-0.5" />
                                <p class="text-xs text-amber-800 font-medium leading-relaxed">
                                    Your account will be upgraded to a <strong>Venue Owner</strong> account so you can manage bookings and earnings.
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
                                <textarea v-model="description" rows="3" placeholder="Briefly describe your venue — facilities, courts available, parking..."
                                    class="w-full ring-1 ring-slate-200 rounded-xl px-4 py-3 text-sm bg-white focus:ring-primary focus:outline-none resize-none placeholder:text-slate-300 transition-all" />
                            </div>

                            <!-- What happens next -->
                            <div class="bg-slate-50 rounded-2xl px-4 py-4 space-y-2.5">
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">What happens next</p>
                                <div v-for="(step, i) in [
                                    'Venue listed on KoCourt instantly',
                                    'Set your schedule & slot timings',
                                    'Players start booking & you earn',
                                ]" :key="i" class="flex items-center gap-3">
                                    <div class="w-5 h-5 rounded-full bg-primary text-white text-[10px] font-black flex items-center justify-center shrink-0">{{ i + 1 }}</div>
                                    <p class="text-xs text-slate-600 font-medium">{{ step }}</p>
                                </div>
                            </div>

                            <!-- CTA -->
                            <button @click="submit" :disabled="loading"
                                class="w-full bg-primary text-white font-extrabold py-4 rounded-2xl text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition-transform disabled:opacity-60">
                                <Loader2 v-if="loading" :size="16" class="animate-spin" />
                                <template v-else>
                                    Claim &amp; List Now
                                    <ChevronRight :size="16" />
                                </template>
                            </button>

                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
