<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    User, Phone, LogOut, ChevronRight,
    Shield, HelpCircle, FileText, Camera,
    LayoutGrid, CalendarDays, Award, Pencil, Check, X, Loader2,
    Wallet, Star, MapPin
} from 'lucide-vue-next'
import KoLogo from '@/components/KoLogo.vue'

const router = useRouter()
const auth = useAuthStore()
const toast = useToastStore()

const editingName  = ref(false)
const nameInput    = ref('')
const nameLoading  = ref(false)
const avatarLoading = ref(false)

// ── Extended profile ──────────────────────────────────────────
const editingProfile = ref(false)
const profileLoading = ref(false)
const bioInput       = ref('')
const skillInput     = ref('')   // 'beginner' | 'intermediate' | 'advanced'
const sportsInput    = ref([])   // string[]

const SPORT_OPTIONS = ['Badminton', 'Football', 'Cricket', 'Tennis', 'Basketball', 'Swimming', 'Boxing', 'Gym']
const SKILL_LEVELS  = ['beginner', 'intermediate', 'advanced']

const startEditProfile = () => {
    bioInput.value    = auth.user?.bio || ''
    skillInput.value  = auth.user?.skill_level || ''
    sportsInput.value = Array.isArray(auth.user?.sport_preferences) ? [...auth.user.sport_preferences] : []
    editingProfile.value = true
}

const toggleSport = (s) => {
    const idx = sportsInput.value.indexOf(s)
    if (idx >= 0) sportsInput.value.splice(idx, 1)
    else sportsInput.value.push(s)
}

const saveProfile = async () => {
    profileLoading.value = true
    try {
        const res = await axios.put('/auth/profile', {
            user_id:          auth.user?.id,
            bio:              bioInput.value.trim(),
            skill_level:      skillInput.value || null,
            sport_preferences: sportsInput.value,
        })
        const updated = res.data.user
        auth.user.bio               = updated.bio
        auth.user.skill_level       = updated.skill_level
        auth.user.sport_preferences = updated.sport_preferences
        localStorage.setItem('user', JSON.stringify(auth.user))
        toast.success('Profile updated!')
        editingProfile.value = false
    } catch { toast.error('Could not save profile') }
    finally { profileLoading.value = false }
}

const handleAvatarUpload = async (event) => {
    const file = event.target.files[0]
    if (!file) return
    avatarLoading.value = true
    try {
        const formData = new FormData()
        formData.append('image', file)
        const res = await axios.post('/upload', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
        auth.updateAvatar(res.data.url)
        await axios.put('/auth/profile', { user_id: auth.user?.id, avatar_url: res.data.url })
        toast.success('Profile photo updated!')
    } catch {
        toast.error('Failed to upload photo')
    } finally {
        avatarLoading.value = false
        event.target.value = ''
    }
}

const startEditName = () => {
    nameInput.value = auth.user?.name || ''
    editingName.value = true
}

const saveName = async () => {
    if (!nameInput.value.trim()) return
    nameLoading.value = true
    try {
        const res = await axios.put('/auth/profile', { user_id: auth.user?.id, name: nameInput.value.trim() })
        auth.user.name = res.data.user.name
        localStorage.setItem('user', JSON.stringify(auth.user))
        toast.success('Name updated!')
        editingName.value = false
    } catch { toast.error('Could not update name') }
    finally { nameLoading.value = false }
}

const initials = computed(() => {
    if (!auth.user?.name) return '?'
    return auth.user?.name?.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()
})

const logout = () => {
    auth.logout()
    toast.success('Logged out successfully')
    router.push('/')
}

// ── Push Notification Debug Panel ─────────────────────────────
const debugTaps      = ref(0)
const showDebug      = ref(false)
const debugLog       = ref([])
const debugSending   = ref(false)

const tapVersion = () => {
    debugTaps.value++
    if (debugTaps.value >= 5) { showDebug.value = !showDebug.value; debugTaps.value = 0 }
}

const debugInfo = computed(() => ({
    saasAvailable:  typeof window !== 'undefined' && !!window.SaaS,
    identitySet:    typeof window !== 'undefined' && window.SaaS
                        ? window.SaaS.hasUserIdentity() === 'true'
                        : false,
    userId:         auth.user?.id   || '—',
    userName:       auth.user?.name || '—',
    userPhone:      auth.user?.phone || auth.user?.email || '—',
    userRole:       auth.user?.role  || '—',
    userCity:       auth.user?.city  || '—',
}))

const addLog = (msg, type = 'info') => {
    const time = new Date().toLocaleTimeString()
    debugLog.value.unshift({ msg, type, time })
    if (debugLog.value.length > 30) debugLog.value.pop()
}

const debugSyncIdentity = () => {
    if (!window.SaaS) { addLog('window.SaaS not available', 'error'); return }
    const u = auth.user
    if (!u) { addLog('Not logged in', 'error'); return }
    try {
        window.SaaS.updateUserIdentity(String(u.id || ''), String(u.phone || u.email || ''), String(u.name || ''))
        const tags = [u.role, u.city].filter(Boolean)
        if (tags.length) window.SaaS.setUserTags(JSON.stringify(tags))
        addLog(`Identity synced: ${u.name} (${u.id}) tags=[${tags.join(',')}]`, 'success')
    } catch (e) {
        addLog('Error: ' + e.message, 'error')
    }
}

const debugClearIdentity = () => {
    if (!window.SaaS) { addLog('window.SaaS not available', 'error'); return }
    try {
        window.SaaS.clearUserIdentity()
        addLog('Identity cleared on device', 'success')
    } catch (e) {
        addLog('Error: ' + e.message, 'error')
    }
}

const debugCheckIdentity = () => {
    if (!window.SaaS) { addLog('window.SaaS not available — running in browser', 'warn'); return }
    const has = window.SaaS.hasUserIdentity()
    addLog(`hasUserIdentity() → ${has}`, has === 'true' ? 'success' : 'warn')
}

const APPIFY_TOKEN   = import.meta.env.VITE_APPIFY_APP_TOKEN  || ''
const APPIFY_API_URL = import.meta.env.VITE_APPIFY_API_URL    || 'https://appifyweb24.com/backend/index.php'

const fcmToken = ref('')

const debugRequestToken = () => {
    if (!window.SaaS) { addLog('window.SaaS not available — running in browser, not app', 'error'); return }
    addLog('Requesting FCM token from Android…')
    // Set a one-time callback that the Android bridge calls back
    window.onSaaS_FCMToken = (token) => {
        fcmToken.value = token
        addLog(`FCM token received: ${token.slice(0, 30)}…`, 'success')
        window.onSaaS_FCMToken = null
    }
    window.SaaS.requestFCMToken()
}

const debugSendTestPush = async () => {
    if (!APPIFY_TOKEN) {
        addLog('VITE_APPIFY_APP_TOKEN not set in .env.local — add your AppifyWeb24 app token', 'error')
        return
    }
    debugSending.value = true
    addLog('Sending test push via AppifyWeb24 API…')
    try {
        const res = await fetch(`${APPIFY_API_URL}/v1/push/notify`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-App-Token': APPIFY_TOKEN,
            },
            body: JSON.stringify({
                title: '🔔 KoCourt Push Test',
                body: `Hello ${auth.user?.name || 'User'}! Push notifications are working.`,
                url: window.location.origin,
            }),
        })
        const data = await res.json()
        if (res.ok) {
            addLog(`✅ Push sent to ${data.sent_to} device(s)`, 'success')
        } else {
            addLog(`API error: ${data.message}`, 'error')
        }
    } catch (e) {
        addLog(`Network error: ${e.message}`, 'error')
    } finally {
        debugSending.value = false
    }
}

const isOwner = computed(() => auth.user?.role === 'owner')

const menuGroups = computed(() => [
    {
        group: 'Activity',
        items: [
            { label: 'My Bookings',    icon: CalendarDays, action: () => router.push('/bookings') },
            { label: 'My Venues',      icon: LayoutGrid,   action: () => router.push('/my-venues') },
            ...(isOwner.value ? [
                { label: 'Earnings', icon: Wallet, action: () => router.push('/my-venues?tab=earnings') },
                { label: 'Reviews',  icon: Star,   action: () => router.push('/my-venues?tab=reviews') },
            ] : []),
            { label: 'My Memberships', icon: Award,    action: () => router.push('/subscriptions') },
            { label: 'Find available courts', icon: MapPin, action: () => router.push('/find-courts') },
        ],
    },
    {
        group: 'Support',
        items: [
            { label: 'Help & FAQ',         icon: HelpCircle, action: () => router.push('/faq') },
            { label: 'Terms & Conditions', icon: FileText,   action: () => router.push('/terms') },
            { label: 'Privacy Policy',     icon: Shield,     action: () => router.push('/privacy') },
        ],
    },
])
</script>

<template>
    <div class="bg-slate-50">
        <div class="px-4 py-5 space-y-5">

            <!-- Guest -->
            <div v-if="!auth.isLoggedIn" class="flex flex-col items-center text-center py-6">
                <div class="w-20 h-20 bg-slate-100 rounded-full flex items-center justify-center mb-4">
                    <User :size="36" class="text-slate-300" />
                </div>
                <p class="font-bold text-slate-700 mb-1">Not signed in</p>
                <p class="text-sm text-slate-400 mb-5">Sign in to manage your bookings and profile</p>
                <button @click="router.push('/login')"
                    class="bg-primary text-white font-bold px-8 py-3 rounded-2xl active:scale-95 transition-transform">
                    Sign In
                </button>
            </div>

            <!-- User Card -->
            <div v-if="auth.isLoggedIn" class="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
                <!-- Avatar + Name row -->
                <div class="flex items-center gap-4 mb-3">
                    <div class="relative shrink-0">
                        <div class="w-16 h-16 rounded-2xl overflow-hidden bg-primary-light border border-primary/10 flex items-center justify-center">
                            <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                            <span v-else class="text-xl font-extrabold text-primary">{{ initials }}</span>
                        </div>
                        <label class="absolute -bottom-1 -right-1 w-6 h-6 bg-primary rounded-full flex items-center justify-center cursor-pointer border-2 border-white shadow">
                            <Camera v-if="!avatarLoading" :size="11" class="text-white" />
                            <span v-else class="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin block"></span>
                            <input type="file" accept="image/jpeg,image/png,image/webp" class="hidden" @change="handleAvatarUpload" />
                        </label>
                    </div>
                    <div class="flex-1 min-w-0">
                        <div v-if="!editingName" class="flex items-center gap-2">
                            <h2 class="text-base font-extrabold text-slate-900 truncate">{{ auth.user?.name }}</h2>
                            <button @click="startEditName" class="shrink-0 w-6 h-6 rounded-full bg-slate-100 flex items-center justify-center">
                                <Pencil :size="11" class="text-slate-500" />
                            </button>
                        </div>
                        <div v-else class="flex items-center gap-1.5">
                            <input v-model="nameInput" type="text"
                                class="flex-1 min-w-0 text-sm font-bold border border-primary rounded-lg px-2 py-1 focus:outline-none"
                                @keyup.enter="saveName" @keyup.escape="editingName = false" autofocus />
                            <button @click="saveName" :disabled="nameLoading"
                                class="w-7 h-7 rounded-full bg-primary flex items-center justify-center shrink-0">
                                <Check :size="12" class="text-white" />
                            </button>
                        </div>
                        <div v-if="auth.user?.phone" class="flex items-center gap-1.5 mt-1">
                            <Phone :size="12" class="text-slate-400" />
                            <span class="text-xs font-bold text-slate-500">+91 {{ auth.user?.phone }}</span>
                        </div>
                    </div>
                </div>

                <!-- Bio / Skills / Sports (display) -->
                <template v-if="!editingProfile">
                    <div v-if="auth.user?.bio" class="text-sm text-slate-500 leading-relaxed mb-2">{{ auth.user.bio }}</div>
                    <div class="flex flex-wrap gap-1.5 mb-2">
                        <span v-if="auth.user?.skill_level"
                            class="text-[11px] font-bold px-2.5 py-1 rounded-full capitalize"
                            :class="{ 'bg-green-100 text-green-700': auth.user.skill_level === 'beginner', 'bg-amber-100 text-amber-700': auth.user.skill_level === 'intermediate', 'bg-primary-light text-primary': auth.user.skill_level === 'advanced' }">
                            {{ auth.user.skill_level }}
                        </span>
                        <span v-for="s in (auth.user?.sport_preferences || [])" :key="s"
                            class="bg-slate-100 text-slate-600 text-[11px] font-semibold px-2.5 py-1 rounded-full">
                            {{ s }}
                        </span>
                    </div>
                    <button @click="startEditProfile"
                        class="text-xs font-bold text-primary bg-primary-light px-3 py-1.5 rounded-full flex items-center gap-1">
                        <Pencil :size="11" /> Edit Sports Profile
                    </button>
                </template>

                <!-- Edit form -->
                <template v-else>
                    <div class="mt-2 space-y-3">
                        <div>
                            <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1">Bio</label>
                            <textarea v-model="bioInput" rows="2" placeholder="Tell others about yourself..."
                                class="w-full text-sm rounded-xl bg-slate-50 border border-slate-200 px-3 py-2 resize-none focus:ring-2 focus:ring-primary/20 outline-none placeholder:text-slate-300">
                            </textarea>
                        </div>
                        <div>
                            <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-2">Skill Level</label>
                            <div class="flex gap-2">
                                <button v-for="l in SKILL_LEVELS" :key="l" @click="skillInput = l"
                                    class="flex-1 py-2 rounded-xl text-xs font-bold capitalize transition-all"
                                    :class="skillInput === l ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500'">
                                    {{ l }}
                                </button>
                            </div>
                        </div>
                        <div>
                            <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-2">Sports I Play</label>
                            <div class="flex flex-wrap gap-1.5">
                                <button v-for="s in SPORT_OPTIONS" :key="s" @click="toggleSport(s)"
                                    class="px-3 py-1.5 rounded-full text-xs font-bold transition-all"
                                    :class="sportsInput.includes(s) ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500'">
                                    {{ s }}
                                </button>
                            </div>
                        </div>
                        <div class="flex gap-2 pt-1">
                            <button @click="editingProfile = false"
                                class="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-bold text-slate-500">
                                Cancel
                            </button>
                            <button @click="saveProfile" :disabled="profileLoading"
                                class="flex-1 py-2.5 rounded-xl bg-primary text-white text-sm font-bold flex items-center justify-center gap-1.5 disabled:opacity-50">
                                <Loader2 v-if="profileLoading" :size="14" class="animate-spin" />
                                <span v-else>Save</span>
                            </button>
                        </div>
                    </div>
                </template>
            </div>
        </div>

        <!-- Menu -->
        <div v-if="auth.isLoggedIn" class="px-4 pb-4 space-y-5">
            <div v-for="group in menuGroups" :key="group.group">
                <p class="text-[11px] font-bold text-slate-400 uppercase tracking-widest mb-2 px-1">{{ group.group }}</p>
                <div class="bg-white rounded-2xl overflow-hidden divide-y divide-slate-50" style="box-shadow:0 1px 6px rgba(0,0,0,0.06)">
                    <button
                        v-for="item in group.items"
                        :key="item.label"
                        @click="item.action"
                        class="w-full flex items-center gap-3 px-4 py-3.5 hover:bg-slate-50 active:bg-slate-100 transition-colors">
                        <div class="w-9 h-9 bg-slate-100 rounded-xl flex items-center justify-center shrink-0">
                            <component :is="item.icon" :size="17" class="text-slate-600" />
                        </div>
                        <span class="flex-1 text-sm font-semibold text-slate-800 text-left">{{ item.label }}</span>
                        <ChevronRight :size="15" class="text-slate-300" />
                    </button>
                </div>
            </div>

            <!-- Logout -->
            <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow:0 1px 6px rgba(0,0,0,0.06)">
                <button
                    @click="logout"
                    class="w-full flex items-center gap-3 px-4 py-4 hover:bg-red-50 active:bg-red-100 transition-colors">
                    <div class="w-9 h-9 bg-red-100 rounded-xl flex items-center justify-center shrink-0">
                        <LogOut :size="17" class="text-red-500" />
                    </div>
                    <span class="flex-1 text-sm font-bold text-red-600 text-left">Log Out</span>
                </button>
            </div>

            <p @click="tapVersion" class="text-center text-xs text-slate-300 pt-2 select-none cursor-default">
                KoCourt v1.0 · Sports, Gym &amp; Club Booking
                <span v-if="debugTaps > 0 && !showDebug" class="text-slate-400">({{ 5 - debugTaps }} more)</span>
            </p>

            <!-- ── Push Debug Panel (tap version 5× to open) ── -->
            <div v-if="showDebug" class="mt-3 rounded-2xl border-2 border-dashed border-orange-300 bg-orange-50 overflow-hidden">
                <!-- Header -->
                <div class="flex items-center justify-between px-4 py-3 bg-orange-100 border-b border-orange-200">
                    <div class="flex items-center gap-2">
                        <span class="text-base">🔔</span>
                        <span class="text-sm font-bold text-orange-800">Push Debug Panel</span>
                        <span class="text-xs bg-orange-200 text-orange-700 px-2 py-0.5 rounded-full font-semibold">DEV ONLY</span>
                    </div>
                    <button @click="showDebug = false" class="text-orange-400 hover:text-orange-600">
                        <X :size="16" />
                    </button>
                </div>

                <!-- Status row -->
                <div class="px-4 py-3 grid grid-cols-2 gap-2 border-b border-orange-200">
                    <div class="rounded-xl p-2.5 text-center"
                        :class="debugInfo.saasAvailable ? 'bg-green-100' : 'bg-red-100'">
                        <p class="text-xs font-bold" :class="debugInfo.saasAvailable ? 'text-green-700' : 'text-red-700'">
                            window.SaaS
                        </p>
                        <p class="text-lg">{{ debugInfo.saasAvailable ? '✅' : '❌' }}</p>
                        <p class="text-xs" :class="debugInfo.saasAvailable ? 'text-green-600' : 'text-red-500'">
                            {{ debugInfo.saasAvailable ? 'In Android app' : 'Browser only' }}
                        </p>
                    </div>
                    <div class="rounded-xl p-2.5 text-center"
                        :class="debugInfo.identitySet ? 'bg-green-100' : 'bg-yellow-100'">
                        <p class="text-xs font-bold" :class="debugInfo.identitySet ? 'text-green-700' : 'text-yellow-700'">
                            Identity
                        </p>
                        <p class="text-lg">{{ debugInfo.identitySet ? '✅' : '⚠️' }}</p>
                        <p class="text-xs" :class="debugInfo.identitySet ? 'text-green-600' : 'text-yellow-600'">
                            {{ debugInfo.identitySet ? 'Linked' : 'Not linked' }}
                        </p>
                    </div>
                </div>

                <!-- User info -->
                <div class="px-4 py-3 space-y-1 border-b border-orange-200">
                    <p class="text-xs font-bold text-orange-700 mb-1.5">Current User Data</p>
                    <div v-for="(val, key) in { ID: debugInfo.userId, Name: debugInfo.userName, Phone: debugInfo.userPhone, Role: debugInfo.userRole, City: debugInfo.userCity }"
                        :key="key" class="flex justify-between text-xs">
                        <span class="text-slate-500 font-medium">{{ key }}</span>
                        <span class="font-mono text-slate-700 truncate max-w-[60%] text-right">{{ val }}</span>
                    </div>
                    <div class="flex justify-between text-xs pt-1 border-t border-orange-100 mt-1">
                        <span class="text-slate-500 font-medium">AppifyWeb24 Token</span>
                        <span :class="APPIFY_TOKEN ? 'text-green-600' : 'text-red-500'" class="font-mono">
                            {{ APPIFY_TOKEN ? APPIFY_TOKEN.slice(0,12) + '…' : 'NOT SET in .env.local' }}
                        </span>
                    </div>
                </div>

                <!-- FCM token display -->
                <div v-if="fcmToken" class="px-4 py-3 border-b border-orange-200">
                    <p class="text-xs font-bold text-orange-700 mb-1.5">FCM Token</p>
                    <div class="flex items-start gap-2">
                        <code class="flex-1 text-xs bg-white border border-orange-200 rounded-lg px-2.5 py-2 text-slate-600 font-mono break-all leading-relaxed">{{ fcmToken }}</code>
                        <button @click="() => { navigator.clipboard?.writeText(fcmToken); addLog('FCM token copied', 'success') }"
                            class="shrink-0 mt-1 p-1.5 rounded-lg bg-orange-100 hover:bg-orange-200 transition-colors">
                            <svg class="w-3.5 h-3.5 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                        </button>
                    </div>
                </div>

                <!-- Action buttons -->
                <div class="px-4 py-3 grid grid-cols-2 gap-2 border-b border-orange-200">
                    <button @click="debugRequestToken"
                        class="py-2 rounded-xl bg-blue-600 text-white text-xs font-bold active:scale-95 transition-transform">
                        Get FCM Token
                    </button>
                    <button @click="debugCheckIdentity"
                        class="py-2 rounded-xl bg-purple-600 text-white text-xs font-bold active:scale-95 transition-transform">
                        Check Identity
                    </button>
                    <button @click="debugSyncIdentity"
                        class="py-2 rounded-xl bg-green-600 text-white text-xs font-bold active:scale-95 transition-transform">
                        Sync Identity
                    </button>
                    <button @click="debugClearIdentity"
                        class="py-2 rounded-xl bg-red-500 text-white text-xs font-bold active:scale-95 transition-transform">
                        Clear Identity
                    </button>
                    <button @click="debugSendTestPush" :disabled="debugSending"
                        class="col-span-2 py-2 rounded-xl bg-orange-500 text-white text-xs font-bold disabled:opacity-50 active:scale-95 transition-transform flex items-center justify-center gap-1.5">
                        <Loader2 v-if="debugSending" :size="12" class="animate-spin" />
                        {{ debugSending ? 'Sending…' : '🔔 Send Test Push to My Device' }}
                    </button>
                </div>

                <!-- Log output -->
                <div class="px-4 py-3">
                    <div class="flex items-center justify-between mb-2">
                        <p class="text-xs font-bold text-orange-700">Log</p>
                        <button @click="debugLog = []" class="text-xs text-orange-400 hover:text-orange-600">Clear</button>
                    </div>
                    <div v-if="debugLog.length === 0" class="text-xs text-slate-400 text-center py-3">
                        No log entries yet
                    </div>
                    <div v-else class="space-y-1 max-h-40 overflow-y-auto">
                        <div v-for="(entry, i) in debugLog" :key="i"
                            class="flex gap-2 text-xs rounded-lg px-2.5 py-1.5"
                            :class="{
                                'bg-green-50 text-green-700': entry.type === 'success',
                                'bg-red-50 text-red-700': entry.type === 'error',
                                'bg-yellow-50 text-yellow-700': entry.type === 'warn',
                                'bg-white text-slate-600': entry.type === 'info',
                            }">
                            <span class="text-slate-400 shrink-0 font-mono">{{ entry.time }}</span>
                            <span class="break-all">{{ entry.msg }}</span>
                        </div>
                    </div>
                </div>
            </div>

        </div>
    </div>
</template>
