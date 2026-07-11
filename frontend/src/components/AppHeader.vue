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
    <header class="sticky top-0 z-40 bg-white glass-blur sm:rounded-t-[3rem]"
        :class="isHome ? 'border-b-0' : 'border-b border-gray-100'">

        <div class="page-gutter flex items-center justify-between"
            :class="isHome ? 'pb-2' : 'pb-2'"
            :style="{ paddingTop: 'max(0.6rem, env(safe-area-inset-top, 0px))' }">

            <div class="flex items-center gap-3 flex-1 min-w-0">
                <button v-if="isDetail" @click="router.back()"
                    class="w-11 h-11 rounded-full bg-white shadow-premium flex items-center justify-center shrink-0 active:scale-95 transition-transform border border-gray-100">
                    <ChevronLeft :size="22" :stroke-width="2.5" class="text-black" />
                </button>

                <div class="min-w-0 flex-1">
                    <div id="header-subtitle" class="text-[11px] font-semibold text-ink-muted leading-none mb-0.5"></div>

                    <h1 v-if="isHome" class="text-[22px] font-extrabold text-black leading-none tracking-tight">
                        Find a court.
                    </h1>
                    <h1 v-else class="text-[17px] font-bold text-black leading-tight truncate">
                        <span v-if="isDetail" id="header-subject"></span>
                        <span v-else>{{ title || 'KoCourt' }}</span>
                    </h1>
                </div>
            </div>

            <div class="flex items-center gap-2 ml-3 shrink-0">
                <div id="header-action" class="flex items-center gap-2"></div>

                <template v-if="auth.isLoggedIn">
                    <button @click="router.push('/notifications')"
                        class="relative w-10 h-10 flex items-center justify-center rounded-full bg-gray-100 text-black active:scale-95 transition-transform">
                        <Bell :size="18" :stroke-width="2" />
                        <span v-if="hasNotifications"
                            class="absolute top-1.5 right-1.5 min-w-[8px] h-2 w-2 bg-red-500 rounded-full border-[1.5px] border-white">
                        </span>
                    </button>
                    <div @click="router.push('/profile')"
                        class="w-11 h-11 rounded-full overflow-hidden bg-gray-100 flex items-center justify-center cursor-pointer active:scale-95 transition-transform shrink-0">
                        <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                        <span v-else class="text-[13px] font-bold text-black">{{ userInitials }}</span>
                    </div>
                </template>

                <button v-else @click="router.push('/login')"
                    class="text-[13px] font-bold text-white bg-black px-5 py-2.5 rounded-full active:scale-95 transition-transform">
                    Sign in
                </button>
            </div>
        </div>

        <div id="header-extra"></div>
    </header>
</template>
