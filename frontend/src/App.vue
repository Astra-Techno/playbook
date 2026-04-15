<script setup>
import { ref, watch, useTemplateRef, onMounted } from 'vue'
import { RouterView, RouterLink, useRoute } from 'vue-router'
import {
    CalendarDays, User,
    CheckCircle2, XCircle, Info,
    Compass, Rss, Map, ShieldCheck,
    Star, X, Loader2
} from 'lucide-vue-next'
import axios from 'axios'
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
        notifications.venueAlerts.filter(n => !n.read_at).forEach(n => {
            toastStore.info(n.type === 'booking_invite' ? '🏸 ' + n.title : n.title)
            notifications.markRead(n.id)
        })
    } else {
        notifications.clear()
    }
}, { immediate: true })

const route   = useRoute()
const mainEl  = useTemplateRef('mainEl')

// Refresh user data from server on load so avatar/profile changes made on
// other devices are picked up immediately (localStorage is device-local)
onMounted(() => { if (auth.isLoggedIn) auth.refreshUser() })

watch(() => route.path, () => {
    if (mainEl.value) mainEl.value.scrollTop = 0
})

const isActive = (path) =>
    path === '/' ? route.path === '/' : route.path.startsWith(path)

const toastIcon = { success: CheckCircle2, error: XCircle, info: Info }
const toastBg   = { success: 'bg-slate-900', error: 'bg-red-600', info: 'bg-primary' }

// ── Global review prompt ──────────────────────────────────────────────────────

const reviewPrompt = ref({ show: false, booking: null, rating: 0, comment: '', loading: false })
let sessionChecked = false   // only fetch once per page load

const parseLocal = (dt) => { const [d, t] = String(dt).split(' '); return new Date(`${d}T${t || '00:00:00'}`) }

const lsReviewed  = () => `reviewed_bookings_${auth.user?.id}`
const lsDismissed = () => `dismissed_reviews_${auth.user?.id}`
const getSet      = (key) => new Set(JSON.parse(localStorage.getItem(key) || '[]'))
const addToSet    = (key, id) => { const s = getSet(key); s.add(String(id)); localStorage.setItem(key, JSON.stringify([...s])) }

const checkReviewPrompt = async () => {
    if (sessionChecked || !auth.isLoggedIn || auth.isAdmin) return
    // /bookings page already handles it
    if (route.path === '/bookings') { sessionChecked = true; return }
    sessionChecked = true

    try {
        const res = await axios.get(`/bookings?user_id=${auth.user?.id}`)
        const now     = new Date()
        const cutoff  = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
        const reviewed  = getSet(lsReviewed())
        const dismissed = getSet(lsDismissed())
        const target = (res.data.records || []).find(b =>
            b.status !== 'cancelled' &&
            parseLocal(b.start_time) < now &&
            parseLocal(b.start_time) >= cutoff &&
            !reviewed.has(String(b.id)) &&
            !dismissed.has(String(b.id))
        )
        if (!target) return
        setTimeout(() => {
            reviewPrompt.value = { show: true, booking: target, rating: 0, comment: '', loading: false }
        }, 2000)
    } catch { /* silent */ }
}

// Trigger once after first route navigation when logged in
watch(() => route.path, () => {
    if (!sessionChecked) checkReviewPrompt()
}, { immediate: true })

// Also re-arm when user logs in mid-session
watch(() => auth.user?.id, (id) => { if (id) { sessionChecked = false; checkReviewPrompt() } })

const dismissPrompt = () => {
    const { booking } = reviewPrompt.value
    if (booking) addToSet(lsDismissed(), booking.id)
    reviewPrompt.value.show = false
}

const submitPromptRating = async () => {
    const { booking, rating, comment } = reviewPrompt.value
    if (!rating) return
    reviewPrompt.value.loading = true
    try {
        await axios.post('/reviews', {
            court_id: booking.court_id, user_id: auth.user?.id,
            booking_id: booking.id, rating, comment,
        })
        toastStore.success('Thanks for your review!')
        addToSet(lsReviewed(), booking.id)
        reviewPrompt.value.show = false
    } catch (err) {
        toastStore.error(err.response?.data?.message || 'Failed to submit review')
    } finally {
        reviewPrompt.value.loading = false
    }
}
</script>

<template>
    <!-- Centered mobile-width wrapper -->
    <div class="min-h-[100dvh] bg-slate-100 flex justify-center">
    <div id="app-root" class="relative w-full max-w-[430px] bg-white h-[100dvh] flex flex-col overflow-hidden shadow-sm">

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
        <main ref="mainEl" class="flex-1 min-h-0 scrollbar-hide"
            :class="[
                route.meta.fullScreen ? 'overflow-hidden' : 'overflow-y-auto',
                auth.isLoggedIn && !route.meta.fullScreen ? 'pb-24' : ''
            ]">
            <RouterView />
        </main>

        <!-- Bottom Nav — shown when logged in -->
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

        <!-- Global Review Prompt -->
        <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="reviewPrompt.show" class="absolute inset-0 bg-black/50 z-[300] flex items-end" @click.self="dismissPrompt">
                <div class="bg-white w-full rounded-t-3xl px-5 pt-5 pb-10">
                    <div class="flex items-center justify-between mb-1">
                        <div>
                            <p class="text-[10px] font-bold text-primary uppercase tracking-wider mb-0.5">How was your session?</p>
                            <h3 class="font-bold text-slate-900 text-base">Rate Your Experience</h3>
                        </div>
                        <button @click="dismissPrompt" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                            <X :size="16" class="text-slate-500" />
                        </button>
                    </div>
                    <p class="text-sm text-slate-500 mb-5">{{ reviewPrompt.booking?.court_name }}</p>

                    <!-- Stars -->
                    <div class="flex gap-2 justify-center mb-5">
                        <button v-for="n in 5" :key="n" @click="reviewPrompt.rating = n" class="active:scale-90 transition-transform">
                            <Star :size="40"
                                :class="n <= reviewPrompt.rating ? 'text-amber-400 fill-amber-400' : 'text-slate-200 fill-slate-200'" />
                        </button>
                    </div>

                    <textarea v-model="reviewPrompt.comment" placeholder="Share your experience (optional)..." class="input-field resize-none mb-4" rows="3" />

                    <div class="flex gap-3">
                        <button @click="dismissPrompt" class="btn-ghost flex-1">Not Now</button>
                        <button @click="submitPromptRating" :disabled="!reviewPrompt.rating || reviewPrompt.loading"
                            class="btn-primary flex-1 flex items-center justify-center gap-2">
                            <Loader2 v-if="reviewPrompt.loading" :size="16" class="animate-spin" />
                            <template v-else>Submit Review</template>
                        </button>
                    </div>
                </div>
            </div>
        </Transition>

    </div>
    </div>
</template>
