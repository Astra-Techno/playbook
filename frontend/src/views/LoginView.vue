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
    <div class="min-h-full flex flex-col bg-white">

        <!-- STEP 1: Full gradient hero -->
        <template v-if="step === 1">
            <div class="bg-gradient-to-br from-black via-gray-900 to-black px-6 pt-14 pb-8 relative overflow-hidden shrink-0">
                <div class="absolute -top-14 -right-14 w-48 h-48 bg-white/5 rounded-full pointer-events-none"></div>
                <div class="absolute -bottom-10 -left-10 w-36 h-36 bg-white/5 rounded-full pointer-events-none"></div>

                <div class="flex items-center gap-3 mb-5">
                    <img src="/logo.png" alt="KoCourt" class="w-11 h-11 rounded-2xl shadow-xl object-cover" />
                    <div>
                        <h1 class="text-white font-extrabold text-xl leading-none tracking-tight">KoCourt</h1>
                        <p class="text-white/50 text-[10px] font-semibold mt-0.5 tracking-widest">SPORTS · GYM · CLUB</p>
                    </div>
                </div>

                <p class="text-white/55 text-[11px] font-semibold uppercase tracking-wider mb-1">Get Started</p>
                <h2 class="text-white text-xl font-bold leading-snug">Enter your mobile number</h2>

                <div class="flex gap-2 mt-4 flex-wrap">
                    <span v-for="c in categories" :key="c"
                        class="bg-white/10 text-white/70 text-[10px] font-semibold px-2.5 py-1 rounded-full tracking-wide">
                        {{ c }}
                    </span>
                </div>
            </div>

            <div class="flex-1 px-5 pt-7 pb-8">
                <div v-if="error"
                    class="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 text-sm font-semibold px-4 py-3 rounded-2xl mb-5">
                    ⚠ {{ error }}
                </div>

                <label class="block text-sm font-semibold text-gray-500 mb-2">Mobile Number</label>
                <div class="flex rounded-2xl border-2 border-gray-200 focus-within:border-black transition-colors overflow-hidden mb-5">
                    <div class="flex items-center gap-1.5 px-4 bg-gray-50 border-r border-gray-200 shrink-0">
                        <span class="text-base">🇮🇳</span>
                        <span class="text-sm font-bold text-gray-500">+91</span>
                    </div>
                    <input v-model="phone" type="tel" inputmode="numeric" maxlength="10"
                        placeholder="98765 43210"
                        @keyup.enter="handlePhoneSubmit"
                        class="flex-1 px-4 py-4 text-xl font-bold tracking-widest bg-transparent border-none focus:ring-0 placeholder:text-gray-300 placeholder:font-normal placeholder:tracking-normal placeholder:text-base" />
                </div>

                <button @click="handlePhoneSubmit" :disabled="loading"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-base font-bold">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Continue <ArrowRight :size="18" /></template>
                </button>

                <p class="text-center text-[11px] text-gray-400 mt-5 leading-relaxed">
                    By continuing you agree to our
                    <RouterLink to="/terms" class="text-black font-semibold">Terms</RouterLink> &amp;
                    <RouterLink to="/privacy" class="text-black font-semibold">Privacy Policy</RouterLink>
                </p>
            </div>
        </template>

        <!-- STEP 2: OTP — compact header so keyboard doesn't bury the boxes -->
        <template v-else-if="step === 2">
            <!-- Compact header bar -->
            <div class="bg-black px-5 pt-12 pb-5 shrink-0 relative">
                <button @click="goBack"
                    class="absolute top-12 left-4 w-9 h-9 rounded-full bg-white/15 flex items-center justify-center text-white active:scale-90 transition-transform">
                    <ArrowLeft :size="18" />
                </button>
                <div class="text-center">
                    <p class="text-white/50 text-[11px] font-semibold uppercase tracking-widest mb-1">Verification</p>
                    <h2 class="text-white text-lg font-bold">OTP sent to</h2>
                    <p class="text-white/70 text-sm font-semibold mt-0.5">+91 {{ phone }}</p>
                </div>
            </div>

            <!-- Form -->
            <div class="flex-1 px-5 pt-8 pb-8">
                <div v-if="error"
                    class="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 text-sm font-semibold px-4 py-3 rounded-2xl mb-5">
                    ⚠ {{ error }}
                </div>

                <p class="text-center text-sm font-semibold text-gray-500 mb-5">Enter 4-digit OTP</p>

                <!-- Responsive OTP grid — always fills full width -->
                <div class="grid grid-cols-4 gap-3 mb-7">
                    <input v-for="(_, i) in otp" :key="i"
                        :ref="el => otpRefs[i] = el"
                        v-model="otp[i]"
                        type="tel" inputmode="numeric" maxlength="1"
                        @input="handleOtpInput(i, $event)"
                        @keydown="handleOtpKeydown(i, $event)"
                        class="aspect-square w-full text-center text-3xl font-extrabold border-2 rounded-2xl bg-gray-50 focus:bg-white focus:outline-none transition-all"
                        :class="otp[i] ? 'border-black bg-black text-white shadow-lg' : 'border-gray-200 text-black'" />
                </div>

                <button @click="verifyOtp" :disabled="loading || otpString.length < 4"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-base font-bold disabled:opacity-40">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Verify &amp; Continue <CheckCircle2 :size="18" /></template>
                </button>

                <p class="text-center text-sm text-gray-400 mt-5">
                    Didn't receive the OTP?
                    <button @click="resendOtp" class="text-black font-bold ml-1 underline underline-offset-2">Resend</button>
                </p>
            </div>
        </template>

        <!-- STEP 3: New user name — compact header -->
        <template v-else>
            <!-- Compact header bar -->
            <div class="bg-black px-5 pt-12 pb-5 shrink-0 relative">
                <button @click="goBack"
                    class="absolute top-12 left-4 w-9 h-9 rounded-full bg-white/15 flex items-center justify-center text-white active:scale-90 transition-transform">
                    <ArrowLeft :size="18" />
                </button>
                <div class="text-center">
                    <p class="text-white/50 text-[11px] font-semibold uppercase tracking-widest mb-1">New Account</p>
                    <h2 class="text-white text-lg font-bold">Complete your profile</h2>
                </div>
            </div>

            <div class="flex-1 px-5 pt-8 pb-8">
                <div v-if="error"
                    class="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 text-sm font-semibold px-4 py-3 rounded-2xl mb-5">
                    ⚠ {{ error }}
                </div>

                <div class="flex items-center gap-3 bg-gray-50 rounded-2xl px-4 py-3 mb-6">
                    <div class="w-10 h-10 bg-black rounded-full flex items-center justify-center shrink-0">
                        <span class="text-xl">👋</span>
                    </div>
                    <p class="text-sm text-gray-500 leading-snug">Welcome! You're registering with <span class="font-bold text-black">+91 {{ phone }}</span></p>
                </div>

                <label class="block text-sm font-semibold text-gray-500 mb-2">Your Full Name</label>
                <input v-model="name" type="text" placeholder="e.g. Mathavan Kumar"
                    @keyup.enter="handleRegisterSubmit"
                    autofocus
                    class="w-full px-4 py-4 text-lg font-semibold rounded-2xl border-2 border-gray-200 focus:border-black focus:outline-none bg-gray-50 focus:bg-white transition-colors mb-6 placeholder:text-gray-300 placeholder:font-normal" />

                <button @click="handleRegisterSubmit" :disabled="loading"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-base font-bold">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Create Account <ArrowRight :size="18" /></template>
                </button>
            </div>
        </template>

    </div>
</template>
