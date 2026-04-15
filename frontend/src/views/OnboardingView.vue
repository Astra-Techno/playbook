<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { MapPin, CalendarCheck, Star } from 'lucide-vue-next'

const router = useRouter()
const current = ref(0)

const slides = [
    {
        icon: MapPin,
        color: 'text-primary',
        bg: 'bg-primary-light',
        title: 'Discover Courts Near You',
        body: 'Find football turfs, badminton courts, gyms and more — just share your location and we\'ll show the best venues nearby.',
        emoji: '🏟️',
    },
    {
        icon: CalendarCheck,
        color: 'text-violet-600',
        bg: 'bg-violet-50',
        title: 'Book Instantly',
        body: 'Pick your slot, pay online, and get a confirmed booking in seconds. No calls, no waiting.',
        emoji: '📅',
    },
    {
        icon: Star,
        color: 'text-amber-500',
        bg: 'bg-amber-50',
        title: 'Play More, Save More',
        body: 'Subscribe to membership plans for peak-hour access and exclusive discounts at your favourite venues.',
        emoji: '⭐',
    },
]

const next = () => {
    if (current.value < slides.length - 1) { current.value++; return }
    finish()
}
const finish = () => {
    localStorage.setItem('kocourt_onboarding', '1')
    router.replace('/')
}
</script>

<template>
    <div class="min-h-full bg-white flex flex-col">
        <!-- Skip -->
        <div class="flex justify-end px-5 pt-5">
            <button @click="finish" class="text-xs font-bold text-slate-400 hover:text-slate-600">Skip</button>
        </div>

        <!-- Slides -->
        <div class="flex-1 flex flex-col items-center justify-center px-8 text-center">
            <div class="relative w-full overflow-hidden">
                <transition name="slide-fade" mode="out-in">
                    <div :key="current" class="flex flex-col items-center">
                        <!-- Icon circle -->
                        <div class="w-28 h-28 rounded-full flex items-center justify-center mb-8"
                            :class="slides[current].bg">
                            <span class="text-5xl">{{ slides[current].emoji }}</span>
                        </div>

                        <h1 class="text-2xl font-extrabold text-slate-900 leading-tight mb-4">
                            {{ slides[current].title }}
                        </h1>
                        <p class="text-slate-500 text-sm leading-relaxed max-w-[280px]">
                            {{ slides[current].body }}
                        </p>
                    </div>
                </transition>
            </div>
        </div>

        <!-- Dots + button -->
        <div class="px-8 pb-12 flex flex-col items-center gap-6">
            <!-- Dots -->
            <div class="flex gap-2">
                <div v-for="(_, i) in slides" :key="i"
                    class="h-2 rounded-full transition-all duration-300"
                    :class="i === current ? 'w-6 bg-primary' : 'w-2 bg-slate-200'">
                </div>
            </div>

            <!-- CTA button -->
            <button @click="next"
                class="w-full bg-primary text-white font-extrabold py-4 rounded-2xl text-base shadow-md active:scale-[0.98] transition-transform">
                {{ current < slides.length - 1 ? 'Next' : 'Get Started' }}
            </button>
        </div>
    </div>
</template>

<style scoped>
.slide-fade-enter-active, .slide-fade-leave-active { transition: all 0.25s ease; }
.slide-fade-enter-from { opacity: 0; transform: translateX(30px); }
.slide-fade-leave-to   { opacity: 0; transform: translateX(-30px); }
</style>
