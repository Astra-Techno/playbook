<script setup>
import { computed, watch } from 'vue'
import { RouterView, RouterLink, useRoute, useRouter } from 'vue-router'
import {
    CalendarDays, User,
    CheckCircle2, XCircle, Info,
    Compass, Rss, Map, ShieldCheck
} from 'lucide-vue-next'
import { useAuthStore } from './stores/auth'
import { useToastStore } from './stores/toast'
import { useNotificationsStore } from './stores/notifications'
import AppHeader from './components/AppHeader.vue'

const auth          = useAuthStore()
const toastStore    = useToastStore()
const notifications = useNotificationsStore()

// Fetch notifications when user logs in; clear on logout
watch(() => auth.user?.id, async (uid) => {
    if (uid) {
        await notifications.fetch(uid)
        // Show toast for unread venue-live alerts
        notifications.venueAlerts.filter(n => !n.read_at).forEach(n => {
            toastStore.info(n.title)
            notifications.markRead(n.id)
        })
    } else {
        notifications.clear()
    }
}, { immediate: true })
const route      = useRoute()
const router     = useRouter()

const isActive = (path) =>
    path === '/' ? route.path === '/' : route.path.startsWith(path)

const toastIcon = { success: CheckCircle2, error: XCircle, info: Info }
const toastBg   = { success: 'bg-slate-900', error: 'bg-red-600', info: 'bg-primary' }
</script>

<template>
    <!-- Centered mobile-width wrapper -->
    <div class="min-h-[100dvh] bg-slate-100 flex justify-center">
    <div class="relative w-full max-w-[430px] bg-white h-[100dvh] flex flex-col overflow-hidden shadow-sm">

        <!-- Toast overlay -->
        <div class="absolute top-4 inset-x-4 z-[200] space-y-2 pointer-events-none">
            <TransitionGroup
                enter-active-class="transition duration-250 ease-out"
                enter-from-class="opacity-0 -translate-y-2 scale-95"
                enter-to-class="opacity-100 translate-y-0 scale-100"
                leave-active-class="transition duration-150 ease-in"
                leave-from-class="opacity-100"
                leave-to-class="opacity-0 scale-95">
                <div v-for="t in toastStore.toasts" :key="t.id"
                    :class="[toastBg[t.type], 'flex items-center gap-3 px-4 py-3 rounded-2xl shadow-xl text-white text-sm font-semibold pointer-events-auto']">
                    <component :is="toastIcon[t.type]" :size="17" class="shrink-0" />
                    <span>{{ t.message }}</span>
                </div>
            </TransitionGroup>
        </div>

        <!-- Global Header -->
        <AppHeader />

        <!-- Page content -->
        <main class="flex-1 min-h-0 scrollbar-hide"
            :class="[
                route.meta.fullScreen ? 'overflow-hidden' : 'overflow-y-auto',
                auth.isLoggedIn && !route.meta.fullScreen ? 'pb-20' : ''
            ]">
            <RouterView />
        </main>

        <!-- Bottom Nav — shown only when logged in -->
        <nav v-if="auth.isLoggedIn"
            class="absolute bottom-0 inset-x-0 bg-white/95 backdrop-blur-md border-t border-slate-100 z-50 px-6 py-3 flex justify-between items-center"
            style="box-shadow: 0 -2px 20px rgba(0,0,0,0.07);">

            <RouterLink to="/"
                class="flex flex-col items-center gap-0.5 transition-colors"
                :class="isActive('/') ? 'text-primary' : 'text-slate-400'">
                <Compass :size="24" :stroke-width="isActive('/') ? 2.5 : 1.8" />
                <span class="text-[10px] font-bold">Explore</span>
            </RouterLink>

            <RouterLink to="/feed"
                class="flex flex-col items-center gap-0.5 transition-colors"
                :class="isActive('/feed') ? 'text-primary' : 'text-slate-400'">
                <Rss :size="24" :stroke-width="isActive('/feed') ? 2.5 : 1.8" />
                <span class="text-[10px]" :class="isActive('/feed') ? 'font-bold' : 'font-medium'">Feed</span>
            </RouterLink>

            <!-- FAB — Map -->
            <div class="flex flex-col items-center -mt-8">
                <RouterLink to="/map"
                    class="bg-primary text-white size-14 rounded-full flex items-center justify-center border-4 border-white active:scale-95 transition-transform"
                    :class="isActive('/map') ? 'ring-2 ring-primary ring-offset-2' : ''"
                    style="box-shadow: 0 6px 24px rgba(124,58,237,0.40);">
                    <Map :size="24" :stroke-width="2" />
                </RouterLink>
                <span class="text-[10px] font-medium mt-1" :class="isActive('/map') ? 'text-primary font-bold' : 'text-slate-400'">Map</span>
            </div>

            <!-- Admin: show Admin panel link; others: show Bookings -->
            <RouterLink v-if="auth.isAdmin" to="/admin"
                class="flex flex-col items-center gap-0.5 transition-colors relative"
                :class="isActive('/admin') ? 'text-primary' : 'text-slate-400'">
                <ShieldCheck :size="24" :stroke-width="isActive('/admin') ? 2.5 : 1.8" />
                <span class="text-[10px]" :class="isActive('/admin') ? 'font-bold' : 'font-medium'">Admin</span>
            </RouterLink>
            <RouterLink v-else to="/bookings"
                class="flex flex-col items-center gap-0.5 transition-colors"
                :class="isActive('/bookings') ? 'text-primary' : 'text-slate-400'">
                <CalendarDays :size="24" :stroke-width="isActive('/bookings') ? 2.5 : 1.8" />
                <span class="text-[10px]" :class="isActive('/bookings') ? 'font-bold' : 'font-medium'">Bookings</span>
            </RouterLink>

            <RouterLink to="/profile"
                class="flex flex-col items-center gap-0.5 transition-colors"
                :class="isActive('/profile') ? 'text-primary' : 'text-slate-400'">
                <User :size="24" :stroke-width="isActive('/profile') ? 2.5 : 1.8" />
                <span class="text-[10px]" :class="isActive('/profile') ? 'font-bold' : 'font-medium'">Profile</span>
            </RouterLink>

        </nav>

    </div>
    </div>
</template>
