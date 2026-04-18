<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Bell, ChevronLeft } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { useNotificationsStore } from '../stores/notifications'
import KoLogo from './KoLogo.vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

// Dynamic title based on router metadata
const title = computed(() => route.meta.title || 'KoCourt')
const showGreeting = computed(() => route.meta.showGreeting)
const isSocial = computed(() => route.path.startsWith('/feed'))
const isDetail = computed(() => route.name === 'post-detail' || !!route.params.id)
const isTopLevel = computed(() => !isDetail.value)
const subtitle = computed(() => route.meta.subtitle)

// User info for greeting
const firstName = computed(() => auth.user?.name?.split(' ')[0] || 'there')
const userInitials = computed(() => {
    const parts = (auth.user?.name || 'Owner').split(' ')
    return parts.map(p => p[0]).join('').toUpperCase().slice(0, 2)
})

const notifications    = useNotificationsStore()
const hasNotifications = computed(() => notifications.count > 0)
</script>

<template>
    <header class="sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-slate-100">
        
        <!-- Main row: Logo + Title + Actions -->
        <div class="flex items-center justify-between px-5 pt-3 pb-3">
            <div class="flex items-center gap-3 flex-1 min-w-0">
                <!-- Back Button for items -->
                <button v-if="isDetail" @click="router.back()"
                    class="w-9 h-9 rounded-full bg-slate-100 flex items-center justify-center shrink-0 active:scale-95 transition-transform">
                    <ChevronLeft :size="20" :stroke-width="2.5" class="text-slate-600" />
                </button>

                <!-- Standard Logo Button -->
                <button @click="router.push('/')" class="shrink-0 active:scale-95 transition-transform">
                    <KoLogo :size="36" :showText="isTopLevel" />
                </button>
                
                <div class="min-w-0">
                    <h1 v-if="!isTopLevel" class="text-slate-900 text-[16px] font-black leading-tight tracking-tight truncate flex items-center gap-2">
                        <template v-if="showGreeting">Hello!</template>
                        <template v-else>
                            <span class="text-slate-300 font-bold">/</span>
                            <div id="header-subject" class="truncate"></div>
                        </template>
                    </h1>
                    <div id="header-subtitle" class="text-[9px] font-black text-primary/60 uppercase tracking-[0.1em] mt-0.5 leading-none"></div>
                </div>
            </div>

            <!-- Header Action Slot (Teleport) -->
            <div id="header-action" class="flex items-center gap-2"></div>

            <!-- Global Action Icons -->
            <div v-if="auth.isLoggedIn" class="flex items-center gap-2 ml-3">
                <button @click="router.push('/notifications')"
                    class="relative w-9 h-9 flex items-center justify-center rounded-full bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors active:scale-95">
                    <Bell :size="16" :stroke-width="1.8" />
                    <span v-if="hasNotifications"
                        class="absolute top-1.5 right-1.5 min-w-[16px] h-4 bg-red-500 rounded-full border-2 border-white flex items-center justify-center text-white text-[9px] font-black px-0.5">
                        {{ notifications.count }}
                    </span>
                </button>
                <div @click="router.push('/profile')" class="w-9 h-9 rounded-full overflow-hidden bg-primary-light flex items-center justify-center ring-2 ring-primary/20 cursor-pointer active:scale-95 transition-transform">
                    <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                    <span v-else class="text-xs font-extrabold text-primary">{{ userInitials }}</span>
                </div>
            </div>
            
            <!-- Login button for guests -->
            <div v-else class="ml-3">
                <button @click="router.push('/login')" class="text-xs font-bold text-white bg-primary px-4 py-2 rounded-xl active:scale-95 transition-transform">
                    Sign in
                </button>
            </div>
        </div>

        <!-- Teleport destination for page-specific bottom sections (Search Bar, Categories) -->
        <div id="header-extra"></div>
    </header>
</template>

