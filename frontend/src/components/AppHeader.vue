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
    <!-- Frosted glass header — matches Kinetic Stadium design -->
    <header class="sticky top-0 z-40 border-b border-surface-variant/30"
        style="background:rgba(248,249,250,0.85);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px)">

        <div class="px-5 flex items-center justify-between gap-3"
            :style="{ paddingTop: 'max(0.75rem, env(safe-area-inset-top, 0px))', paddingBottom: '0.75rem' }">

            <!-- Left -->
            <div class="flex items-center gap-3 flex-1 min-w-0">
                <button v-if="isDetail" @click="router.back()"
                    class="w-9 h-9 rounded-full bg-surface-container flex items-center justify-center shrink-0 active:scale-90 transition-transform border border-surface-variant/40">
                    <ChevronLeft :size="20" :stroke-width="2.5" class="text-on-surface" />
                </button>

                <!-- Home: logo + divider + location -->
                <template v-if="isHome">
                    <img src="/logo.png" alt="KoCourt" class="h-8 w-auto object-contain shrink-0" />
                    <div class="w-px h-4 bg-surface-variant/40 shrink-0"></div>
                    <div id="header-subtitle" class="flex items-center gap-1 cursor-pointer"></div>
                </template>

                <!-- Inner pages: subtitle + title -->
                <div v-else class="min-w-0">
                    <p class="text-[11px] font-semibold text-on-surface-variant leading-none mb-0.5">
                        <span id="header-subtitle"></span>
                    </p>
                    <h1 class="text-[16px] font-bold text-on-surface leading-tight truncate">
                        <span v-if="isDetail" id="header-subject"></span>
                        <span v-else>{{ title || 'KoCourt' }}</span>
                    </h1>
                </div>
            </div>

            <!-- Right: actions -->
            <div class="flex items-center gap-2 shrink-0">
                <div id="header-action" class="flex items-center gap-2"></div>

                <template v-if="auth.isLoggedIn">
                    <button @click="router.push('/notifications')"
                        class="relative w-10 h-10 flex items-center justify-center rounded-full border border-surface-variant/20 hover:bg-surface-container-low active:scale-90 transition-all">
                        <Bell :size="20" :stroke-width="2" class="text-on-surface" />
                        <span v-if="hasNotifications"
                            class="absolute top-1.5 right-1.5 w-2 h-2 bg-primary rounded-full border-2 border-white">
                        </span>
                    </button>
                    <!-- Avatar with primary ring — from design -->
                    <button @click="router.push('/profile')"
                        class="w-10 h-10 rounded-full p-0.5 border border-primary/20 bg-gradient-to-tr from-primary/10 to-transparent active:scale-90 transition-transform shrink-0">
                        <div class="w-full h-full rounded-full overflow-hidden bg-surface-container flex items-center justify-center">
                            <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                            <span v-else class="text-[12px] font-bold text-on-surface">{{ userInitials }}</span>
                        </div>
                    </button>
                </template>
                <button v-else @click="router.push('/login')"
                    class="text-[13px] font-bold text-on-primary bg-primary px-4 py-2 rounded-xl active:scale-95 transition-transform shadow-fab">
                    Sign in
                </button>
            </div>
        </div>

        <div id="header-extra"></div>
    </header>
</template>
