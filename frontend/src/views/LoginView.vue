<script setup>
import { ref, computed, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { ArrowLeft, ArrowRight, CheckCircle2, Loader2 } from 'lucide-vue-next'

const router = useRouter()
const auth   = useAuthStore()

const step    = ref(1)
const phone   = ref('')
const otp     = ref(['', '', '', ''])
const name    = ref('')
const loading = ref(false)
const error   = ref('')
const otpRefs = ref([])

const otpString = computed(() => otp.value.join(''))

const handlePhoneSubmit = async () => {
    error.value = ''
    if (!/^\d{10}$/.test(phone.value)) { error.value = 'Enter your 10-digit mobile number (without country code)'; return }
    loading.value = true
    try {
        await axios.post('/auth/send-otp', { phone: phone.value })
        step.value = 2
        await nextTick()
        otpRefs.value[0]?.focus()
    } catch (err) {
        error.value = err.response?.data?.message || 'Failed to send OTP. Try again.'
    } finally {
        loading.value = false
    }
}

const handleOtpInput = (i, e) => {
    const val = e.target.value.replace(/\D/g, '')
    otp.value[i] = val.slice(-1)
    if (val && i < 3) otpRefs.value[i + 1]?.focus()
    if (otpString.value.length === 4) verifyOtp()
}

const handleOtpKeydown = (i, e) => {
    if (e.key === 'Backspace' && !otp.value[i] && i > 0) {
        otp.value[i - 1] = ''
        otpRefs.value[i - 1]?.focus()
    }
}

const verifyOtp = async () => {
    error.value = ''
    if (otpString.value.length < 4) { error.value = 'Enter the 4-digit OTP'; return }
    loading.value = true
    try {
        const payload = { phone: phone.value, otp: otpString.value }
        if (step.value === 3) {
            if (!name.value.trim()) { error.value = 'Enter your name'; return }
            payload.name = name.value.trim()
            payload.role = 'player'
        }
        const res  = await axios.post('/auth/verify-otp', payload)
        const data = res.data
        if (data.new_user) { step.value = 3; return }
        auth.setAuth(data.user, data.token)
        router.replace('/')
    } catch (err) {
        const data = err.response?.data
        if (err.response?.status === 404 || data?.new_user) { step.value = 3; return }
        // At step 3, an OTP error means the session expired — guide user to re-verify
        if (step.value === 3 && err.response?.status === 400) {
            error.value = 'Your OTP session expired. Please go back and request a new code.'
        } else {
            error.value = data?.message || 'Something went wrong. Try again.'
        }
    } finally {
        loading.value = false
    }
}

const handleRegisterSubmit = () => {
    if (!name.value.trim()) { error.value = 'Enter your name'; return }
    verifyOtp()
}

const resendOtp = async () => {
    error.value = ''
    otp.value = ['', '', '', '']
    try {
        await axios.post('/auth/send-otp', { phone: phone.value })
    } catch (err) {
        error.value = err.response?.data?.message || 'Failed to resend OTP.'
    }
}

const goBack = () => {
    error.value = ''
    if (step.value > 1) { step.value--; return }
    router.push('/')
}

const categories = ['🏸 Badminton', '⚽ Football', '🏋️ Gym', '🎾 Tennis', '🏊 Swimming', '🥊 Boxing', '🏏 Cricket', '🏀 Basketball']
</script>

<template>
    <!-- Full page scroll — keyboard pushes content up, user scrolls to input -->
    <div class="bg-white">

        <!-- ── STEP 1: Phone ─────────────────────────────── -->
        <template v-if="step === 1">
            <!-- Compact brand bar -->
            <div class="bg-black px-5 pb-6" :style="{ paddingTop: 'max(3.5rem, calc(env(safe-area-inset-top, 0px) + 1rem))' }">
                <div class="flex items-center gap-3 mb-4">
                    <img src="/logo.png" alt="KoCourt" class="w-10 h-10 rounded-xl object-cover" />
                    <div>
                        <p class="text-white font-extrabold text-base leading-none">KoCourt</p>
                        <p class="text-white/40 text-[9px] font-semibold tracking-widest mt-0.5">SPORTS · GYM · CLUB</p>
                    </div>
                </div>
                <p class="text-white/50 text-[11px] font-semibold uppercase tracking-widest mb-0.5">Get Started</p>
                <h2 class="text-white text-2xl font-extrabold leading-tight">Enter your mobile<br>number</h2>
            </div>

            <!-- Form (no flex-1 — sits in document flow, page scrolls) -->
            <div class="px-5 pt-6 pb-10">
                <div v-if="error"
                    class="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 text-sm font-semibold px-4 py-3 rounded-2xl mb-5">
                    ⚠ {{ error }}
                </div>

                <label class="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-2">Mobile Number</label>
                <div class="flex rounded-2xl border-2 border-gray-200 focus-within:border-black transition-colors overflow-hidden mb-4 bg-gray-50 focus-within:bg-white">
                    <div class="flex items-center gap-1.5 px-4 border-r border-gray-200 shrink-0">
                        <span class="text-base">🇮🇳</span>
                        <span class="text-sm font-bold text-gray-500">+91</span>
                    </div>
                    <input v-model="phone" type="tel" inputmode="numeric" maxlength="10"
                        placeholder="98765 43210"
                        @keyup.enter="handlePhoneSubmit"
                        class="flex-1 px-4 py-4 text-2xl font-bold tracking-widest bg-transparent border-none focus:ring-0 focus:outline-none placeholder:text-gray-300 placeholder:font-normal placeholder:text-lg placeholder:tracking-normal" />
                </div>

                <button @click="handlePhoneSubmit" :disabled="loading"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-base font-bold mb-6">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Continue <ArrowRight :size="18" /></template>
                </button>

                <p class="text-center text-[11px] text-gray-400 leading-relaxed">
                    By continuing you agree to our
                    <RouterLink to="/terms" class="text-black font-semibold">Terms</RouterLink> &amp;
                    <RouterLink to="/privacy" class="text-black font-semibold">Privacy Policy</RouterLink>
                </p>

                <!-- Sport chips at bottom — decorative, below the fold is fine -->
                <div class="flex gap-2 mt-8 flex-wrap justify-center">
                    <span v-for="c in categories" :key="c"
                        class="bg-gray-100 text-gray-500 text-[11px] font-semibold px-3 py-1.5 rounded-full">
                        {{ c }}
                    </span>
                </div>
            </div>
        </template>

        <!-- ── STEP 2: OTP ────────────────────────────────── -->
        <template v-else-if="step === 2">
            <!-- Compact header -->
            <div class="bg-black px-5 pb-6 relative" :style="{ paddingTop: 'max(3.5rem, calc(env(safe-area-inset-top, 0px) + 1rem))' }">
                <button @click="goBack"
                    class="absolute left-4 w-9 h-9 rounded-full bg-white/15 flex items-center justify-center text-white active:scale-90 transition-transform" style="top: max(3.5rem, calc(env(safe-area-inset-top, 0px) + 1rem))">
                    <ArrowLeft :size="18" />
                </button>
                <div class="pl-10">
                    <p class="text-white/50 text-[11px] font-semibold uppercase tracking-widest mb-0.5">Verification</p>
                    <h2 class="text-white text-xl font-extrabold leading-tight">OTP sent to</h2>
                    <p class="text-white/60 text-sm font-semibold mt-0.5">+91 {{ phone }}</p>
                </div>
            </div>

            <div class="px-5 pt-7 pb-10">
                <div v-if="error"
                    class="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 text-sm font-semibold px-4 py-3 rounded-2xl mb-5">
                    ⚠ {{ error }}
                </div>

                <label class="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-4 text-center">Enter 4-digit OTP</label>

                <!-- Responsive OTP grid — 4 equal columns, fills full width -->
                <div class="grid grid-cols-4 gap-3 mb-7">
                    <input v-for="(_, i) in otp" :key="i"
                        :ref="el => otpRefs[i] = el"
                        v-model="otp[i]"
                        type="tel" inputmode="numeric" maxlength="1"
                        @input="handleOtpInput(i, $event)"
                        @keydown="handleOtpKeydown(i, $event)"
                        class="aspect-square w-full text-center text-3xl font-extrabold border-2 rounded-2xl focus:outline-none transition-all"
                        :class="otp[i] ? 'border-black bg-black text-white shadow-lg' : 'border-gray-200 bg-gray-50 text-black'" />
                </div>

                <button @click="verifyOtp" :disabled="loading || otpString.length < 4"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-base font-bold disabled:opacity-40 mb-5">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Verify &amp; Continue <CheckCircle2 :size="18" /></template>
                </button>

                <p class="text-center text-sm text-gray-400">
                    Didn't receive the OTP?
                    <button @click="resendOtp" class="text-black font-bold ml-1 underline underline-offset-2">Resend</button>
                </p>
            </div>
        </template>

        <!-- ── STEP 3: Name ───────────────────────────────── -->
        <template v-else>
            <!-- Compact header -->
            <div class="bg-black px-5 pb-6 relative" :style="{ paddingTop: 'max(3.5rem, calc(env(safe-area-inset-top, 0px) + 1rem))' }">
                <button @click="goBack"
                    class="absolute left-4 w-9 h-9 rounded-full bg-white/15 flex items-center justify-center text-white active:scale-90 transition-transform" style="top: max(3.5rem, calc(env(safe-area-inset-top, 0px) + 1rem))">
                    <ArrowLeft :size="18" />
                </button>
                <div class="pl-10">
                    <p class="text-white/50 text-[11px] font-semibold uppercase tracking-widest mb-0.5">New Account</p>
                    <h2 class="text-white text-xl font-extrabold">Complete your profile</h2>
                </div>
            </div>

            <div class="px-5 pt-7 pb-10">
                <div v-if="error"
                    class="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 text-sm font-semibold px-4 py-3 rounded-2xl mb-5">
                    ⚠ {{ error }}
                </div>

                <div class="flex items-center gap-3 bg-gray-50 rounded-2xl px-4 py-3 mb-6 border border-gray-100">
                    <span class="text-2xl shrink-0">👋</span>
                    <p class="text-sm text-gray-500 leading-snug">
                        Welcome! Signing up with<br>
                        <span class="font-bold text-black">+91 {{ phone }}</span>
                    </p>
                </div>

                <label class="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-2">Your Full Name</label>
                <input v-model="name" type="text" placeholder="e.g. Mathavan Kumar"
                    @keyup.enter="handleRegisterSubmit"
                    autofocus
                    class="w-full px-4 py-4 text-xl font-semibold rounded-2xl border-2 border-gray-200 focus:border-black focus:outline-none bg-gray-50 focus:bg-white transition-colors mb-5 placeholder:text-gray-300 placeholder:font-normal placeholder:text-base" />

                <button @click="handleRegisterSubmit" :disabled="loading"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-base font-bold">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Create Account <ArrowRight :size="18" /></template>
                </button>
            </div>
        </template>

    </div>
</template>
