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
    if (!/^\d{10}$/.test(phone.value)) { error.value = 'Enter a valid 10-digit mobile number'; return }
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
        error.value = data?.message || 'Something went wrong. Try again.'
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
    <div class="min-h-full flex flex-col">

        <!-- Gradient Hero -->
        <div class="bg-gradient-to-br from-primary via-violet-700 to-purple-900 px-6 pt-14 pb-10 relative overflow-hidden">
            <div class="absolute -top-14 -right-14 w-48 h-48 bg-white/5 rounded-full pointer-events-none"></div>
            <div class="absolute top-20 -right-6 w-24 h-24 bg-white/5 rounded-full pointer-events-none"></div>
            <div class="absolute -bottom-10 -left-10 w-36 h-36 bg-white/5 rounded-full pointer-events-none"></div>

            <button v-if="step > 1" @click="goBack"
                class="absolute top-14 left-5 w-9 h-9 rounded-full bg-white/15 flex items-center justify-center text-white active:scale-90 transition-transform">
                <ArrowLeft :size="18" />
            </button>

            <div class="flex items-center gap-3 mb-6">
                <img src="/logo.png" alt="KoCourt" class="w-12 h-12 rounded-2xl shadow-xl object-cover" />
                <div>
                    <h1 class="text-white font-extrabold text-[22px] leading-none tracking-tight">KoCourt</h1>
                    <p class="text-white/50 text-[10px] font-semibold mt-0.5 tracking-widest">SPORTS · GYM · CLUB</p>
                </div>
            </div>

            <p class="text-white/55 text-xs font-semibold uppercase tracking-wider mb-1">
                {{ step === 1 ? 'Get Started' : step === 2 ? 'Verification' : 'New Account' }}
            </p>
            <h2 class="text-white text-xl font-bold leading-snug">
                {{ step === 1 ? 'Enter your mobile number'
                 : step === 2 ? 'OTP sent to +91 ' + phone
                 : 'Complete your profile' }}
            </h2>

            <div v-if="step === 1" class="flex gap-2 mt-5 flex-wrap">
                <span v-for="c in categories" :key="c"
                    class="bg-white/10 text-white/70 text-[10px] font-semibold px-2.5 py-1 rounded-full tracking-wide">
                    {{ c }}
                </span>
            </div>
        </div>

        <!-- Form Body -->
        <div class="flex-1 bg-white px-5 pt-7 pb-10">

            <div v-if="error"
                class="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 text-sm font-semibold px-4 py-3 rounded-xl mb-5">
                ⚠ {{ error }}
            </div>

            <!-- STEP 1: Phone -->
            <template v-if="step === 1">
                <label class="block text-sm font-semibold text-slate-700 mb-2">Mobile Number</label>
                <div class="flex rounded-xl border-2 border-slate-200 focus-within:border-primary transition-colors overflow-hidden mb-5">
                    <div class="flex items-center gap-1.5 px-4 bg-slate-50 border-r border-slate-200 shrink-0">
                        <span>🇮🇳</span>
                        <span class="text-sm font-bold text-slate-500">+91</span>
                    </div>
                    <input v-model="phone" type="tel" inputmode="numeric" maxlength="10"
                        placeholder="98765 43210"
                        @keyup.enter="handlePhoneSubmit"
                        class="flex-1 px-4 py-4 text-lg font-bold bg-transparent border-none focus:ring-0 placeholder:text-slate-300 placeholder:font-normal" />
                </div>

                <button @click="handlePhoneSubmit" :disabled="loading"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-[15px]">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Continue <ArrowRight :size="18" /></template>
                </button>

                <p class="text-center text-[11px] text-slate-400 mt-5 leading-relaxed">
                    By continuing you agree to our
                    <RouterLink to="/terms" class="text-primary font-semibold">Terms</RouterLink> &
                    <RouterLink to="/privacy" class="text-primary font-semibold">Privacy Policy</RouterLink>
                </p>
            </template>

            <!-- STEP 2: OTP -->
            <template v-else-if="step === 2">
                <label class="block text-sm font-semibold text-slate-700 mb-5">Enter 4-digit OTP</label>
                <div class="flex gap-3 justify-center mb-6">
                    <input v-for="(_, i) in otp" :key="i"
                        :ref="el => otpRefs[i] = el"
                        v-model="otp[i]"
                        type="tel" inputmode="numeric" maxlength="1"
                        @input="handleOtpInput(i, $event)"
                        @keydown="handleOtpKeydown(i, $event)"
                        class="w-[62px] h-[62px] text-center text-2xl font-extrabold border-2 rounded-xl bg-white focus:ring-0 transition-all"
                        :class="otp[i] ? 'border-primary text-primary scale-105 shadow-md shadow-primary/20' : 'border-slate-200 text-slate-900'" />
                </div>

                <button @click="verifyOtp" :disabled="loading || otpString.length < 4"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-[15px]">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Verify & Continue <CheckCircle2 :size="18" /></template>
                </button>

                <p class="text-center text-sm text-slate-400 mt-4">
                    Didn't receive?
                    <button @click="resendOtp" class="text-primary font-bold ml-1">Resend OTP</button>
                </p>
            </template>

            <!-- STEP 3: Register — name only, no role selection -->
            <template v-else>
                <div class="text-center mb-6">
                    <div class="w-16 h-16 bg-primary-light rounded-full flex items-center justify-center mx-auto mb-3">
                        <span class="text-3xl">👋</span>
                    </div>
                    <p class="text-slate-500 text-sm">Looks like you're new here.<br>Let's set up your account.</p>
                </div>

                <label class="block text-sm font-semibold text-slate-700 mb-2">Your Full Name</label>
                <input v-model="name" type="text" placeholder="e.g. Mathavan Kumar"
                    @keyup.enter="handleRegisterSubmit" class="input-field mb-6" autofocus />

                <button @click="handleRegisterSubmit" :disabled="loading"
                    class="w-full btn-primary flex items-center justify-center gap-2 py-4 text-[15px]">
                    <Loader2 v-if="loading" :size="18" class="animate-spin" />
                    <template v-else>Create Account <ArrowRight :size="18" /></template>
                </button>
            </template>
        </div>
    </div>
</template>
