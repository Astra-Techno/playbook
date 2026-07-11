<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Bell, ChevronLeft } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { useNotificationsStore } from '../stores/notifications'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const isHome    = computed(() => route.path === '/')
const isDetail  = computed(() => !!route.params.id || route.meta.isDetail)
const title     = computed(() => route.meta.title || '')

const userInitials = computed(() => {
    const parts = (auth.user?.name || 'KO').split(' ')
    return parts.map(p => p[0]).join('').toUpperCase().slice(0, 2)
})

const notifications    = useNotificationsStore()
const hasNotifications = computed(() => notifications.count > 0)
</script>

<template>
    <header class="sticky top-0 z-40 bg-white border-b border-gray-100 sm:rounded-t-[3rem]">
        <div class="px-4 flex items-center justify-between gap-3"
            :style="{ paddingTop: 'max(0.5rem, env(safe-area-inset-top, 0px))', paddingBottom: '0.5rem' }">

            <!-- Left: back or brand/title -->
            <div class="flex items-center gap-2.5 flex-1 min-w-0">
                <button v-if="isDetail" @click="router.back()"
                    class="w-9 h-9 rounded-full bg-gray-100 flex items-center justify-center shrink-0 active:scale-90 transition-transform">
                    <ChevronLeft :size="20" :stroke-width="2.5" class="text-black" />
                </button>

                <!-- Home: logo + brand -->
                <div v-if="isHome" class="flex items-center gap-2">
                    <img src="/logo.png" alt="KoCourt" class="w-7 h-7 rounded-lg object-cover" />
                    <span class="font-condensed font-extrabold text-[17px] tracking-tight text-black" style="font-family:'Barlow Condensed',sans-serif">KoCourt</span>
                </div>

                <!-- Inner pages: title -->
                <div v-else class="min-w-0">
                    <p class="text-[11px] font-semibold text-gray-400 leading-none mb-0.5">
                        <span id="header-subtitle"></span>
                    </p>
                    <h1 class="text-[16px] font-bold text-black leading-tight truncate">
                        <span v-if="isDetail" id="header-subject"></span>
                        <span v-else>{{ title || 'KoCourt' }}</span>
                    </h1>
                </div>
            </div>

            <!-- Right: actions -->
            <div class="flex items-center gap-1.5 shrink-0">
                <div id="header-action" class="flex items-center gap-1.5"></div>

                <template v-if="auth.isLoggedIn">
                    <button @click="router.push('/notifications')"
                        class="relative w-9 h-9 flex items-center justify-center rounded-full bg-gray-100 active:scale-90 transition-transform">
                        <Bell :size="17" :stroke-width="2" class="text-black" />
                        <span v-if="hasNotifications"
                            class="absolute top-1.5 right-1.5 w-2 h-2 bg-red-500 rounded-full border-[1.5px] border-white">
                        </span>
                    </button>
                    <button @click="router.push('/profile')"
                        class="w-9 h-9 rounded-full overflow-hidden bg-gray-100 flex items-center justify-center active:scale-90 transition-transform shrink-0">
                        <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                        <span v-else class="text-[12px] font-bold text-black">{{ userInitials }}</span>
                    </button>
                </template>
                <button v-else @click="router.push('/login')"
                    class="text-[13px] font-bold text-white bg-black px-4 py-2 rounded-full active:scale-95 transition-transform">
                    Sign in
                </button>
            </div>
        </div>

        <!-- Slot for inner page extra content (search bars, tabs, etc) -->
        <div id="header-extra"></div>
    </header>
</template>
