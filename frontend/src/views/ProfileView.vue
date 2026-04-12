<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    User, Phone, LogOut, ChevronRight,
    Shield, HelpCircle, FileText, Camera,
    LayoutGrid, CalendarDays, Award, Pencil, Check, X
} from 'lucide-vue-next'
import KoLogo from '@/components/KoLogo.vue'

const router = useRouter()
const auth = useAuthStore()
const toast = useToastStore()

const editingName  = ref(false)
const nameInput    = ref('')
const nameLoading  = ref(false)
const avatarLoading = ref(false)

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

const menuGroups = [
    {
        group: 'Activity',
        items: [
            { label: 'My Bookings',    icon: CalendarDays, action: () => router.push('/bookings') },
            { label: 'My Services',    icon: LayoutGrid,   action: () => router.push('/my-services') },
            { label: 'My Memberships', icon: Award,        action: () => router.push('/subscriptions') },
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
]
</script>

<template>
    <div class="min-h-full bg-slate-50">
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
            <div v-if="auth.isLoggedIn" class="bg-white rounded-2xl p-5 shadow-sm border border-slate-100 flex items-center gap-4">
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
        </div>

        <!-- Menu -->
        <div v-if="auth.isLoggedIn" class="px-4 pb-8 space-y-5">
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

            <p class="text-center text-xs text-slate-300 pt-2">KoCourt v1.0 · Sports, Gym & Club Booking</p>
        </div>
    </div>
</template>
