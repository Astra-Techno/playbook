<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { UserPlus, Trash2, Shield, Eye, Loader2, Phone, Users } from 'lucide-vue-next'

const route = useRoute()
const auth  = useAuthStore()
const toast = useToastStore()

const courtId    = route.params.id
const courtName  = ref('')
const staff      = ref([])
const loading    = ref(true)
const phone      = ref('')
const role       = ref('manager')
const addLoading = ref(false)
const removeId   = ref(null)

onMounted(async () => {
    try {
        const [courtRes, staffRes] = await Promise.all([
            axios.get(`/courts/${courtId}`),
            axios.get(`/court-staff?court_id=${courtId}&owner_id=${auth.user.id}`)
        ])
        courtName.value = courtRes.data.court?.name ?? ''
        staff.value     = staffRes.data.staff || []
    } catch { toast.error('Failed to load') }
    finally { loading.value = false }
})

const addStaff = async () => {
    if (!phone.value.trim()) { toast.error('Enter a phone number'); return }
    addLoading.value = true
    try {
        const res = await axios.post('/court-staff', {
            court_id: courtId,
            owner_id: auth.user.id,
            phone:    phone.value.trim(),
            role:     role.value,
        })
        staff.value.push(res.data.staff)
        phone.value = ''
        toast.success(res.data.message)
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to add staff')
    } finally { addLoading.value = false }
}

const removeStaff = async (member) => {
    removeId.value = member.id
    try {
        await axios.delete(`/court-staff/${member.id}`, { data: { owner_id: auth.user.id } })
        staff.value = staff.value.filter(s => s.id !== member.id)
        toast.success(`${member.name} removed`)
    } catch { toast.error('Failed to remove') }
    finally { removeId.value = null }
}

const initials = (name) => (name || '?').split(' ').map(p => p[0]).join('').toUpperCase().slice(0, 2)
</script>

<template>
    <Teleport to="#header-subject">{{ courtName || 'Staff' }}</Teleport>
    <Teleport to="#header-subtitle">Staff</Teleport>

    <div class="min-h-screen bg-slate-50">
        <!-- Header -->
        <div class="bg-white px-5 pt-5 pb-5 border-b border-slate-100">
            <h1 class="text-lg font-bold text-slate-900">Staff</h1>
            <p class="text-xs text-slate-500">Manage staff and their permissions</p>
        </div>

        <div class="px-5 py-5 pb-8 space-y-6">

            <!-- Add Staff -->
            <div class="bg-white rounded-2xl p-4 shadow-sm ring-1 ring-slate-100 space-y-3">
                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider">Add Staff Member</p>
                <div class="flex items-center gap-2 ring-1 ring-slate-200 rounded-xl px-4 h-12 focus-within:ring-primary transition-all bg-slate-50">
                    <Phone :size="15" class="text-slate-400 shrink-0" />
                    <input v-model="phone" type="tel" placeholder="Staff phone number"
                        class="flex-1 text-sm bg-transparent border-none focus:ring-0 placeholder:text-slate-300"
                        @keyup.enter="addStaff" />
                </div>
                <div class="flex gap-2">
                    <button @click="role = 'manager'"
                        class="flex-1 flex items-center justify-center gap-2 h-10 rounded-xl text-xs font-bold transition-all"
                        :class="role === 'manager' ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500'">
                        <Shield :size="13" /> Manager
                    </button>
                    <button @click="role = 'viewer'"
                        class="flex-1 flex items-center justify-center gap-2 h-10 rounded-xl text-xs font-bold transition-all"
                        :class="role === 'viewer' ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500'">
                        <Eye :size="13" /> Viewer
                    </button>
                </div>
                <p class="text-[11px] text-slate-400 px-1">
                    <template v-if="role === 'manager'">Can view, create &amp; cancel bookings</template>
                    <template v-else>Can view bookings only</template>
                </p>
                <button @click="addStaff" :disabled="addLoading"
                    class="w-full bg-primary text-white text-sm font-extrabold py-3 rounded-xl flex items-center justify-center gap-2 active:scale-[0.98] transition disabled:opacity-60">
                    <Loader2 v-if="addLoading" :size="15" class="animate-spin" />
                    <UserPlus v-else :size="15" />
                    Add Staff
                </button>
            </div>

            <!-- Staff List -->
            <div>
                <p class="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-2 px-1">
                    Current Staff
                    <span v-if="staff.length" class="ml-1 bg-slate-100 text-slate-500 px-1.5 py-0.5 rounded-full text-[10px]">{{ staff.length }}</span>
                </p>

                <div v-if="loading" class="space-y-3">
                    <div v-for="i in 2" :key="i" class="h-14 bg-slate-100 rounded-2xl animate-pulse"></div>
                </div>

                <div v-else-if="staff.length === 0" class="bg-white rounded-2xl flex flex-col items-center py-10 text-center shadow-sm ring-1 ring-slate-100">
                    <div class="w-12 h-12 rounded-2xl bg-slate-100 flex items-center justify-center mb-3">
                        <Users :size="22" class="text-slate-400" />
                    </div>
                    <p class="text-sm font-bold text-slate-500">No staff added yet</p>
                    <p class="text-xs text-slate-400 mt-1">Add staff by phone number above</p>
                </div>

                <div v-else class="space-y-2">
                    <div v-for="member in staff" :key="member.id"
                        class="flex items-center gap-3 bg-white rounded-2xl px-4 py-3 shadow-sm ring-1 ring-slate-100">
                        <div class="w-10 h-10 rounded-full bg-primary-light flex items-center justify-center shrink-0 overflow-hidden">
                            <img v-if="member.avatar_url" :src="member.avatar_url" class="w-full h-full object-cover" />
                            <span v-else class="text-xs font-extrabold text-primary">{{ initials(member.name) }}</span>
                        </div>
                        <div class="flex-1 min-w-0">
                            <p class="text-sm font-bold text-slate-800 truncate">{{ member.name }}</p>
                            <p class="text-xs text-slate-400">{{ member.phone }}</p>
                        </div>
                        <span class="text-[10px] font-black px-2.5 py-1 rounded-full shrink-0"
                            :class="member.role === 'manager' ? 'bg-primary/10 text-primary' : 'bg-slate-200 text-slate-500'">
                            {{ member.role }}
                        </span>
                        <button @click="removeStaff(member)" :disabled="removeId === member.id"
                            class="w-8 h-8 rounded-full bg-red-50 flex items-center justify-center shrink-0 active:scale-90 transition disabled:opacity-50">
                            <Loader2 v-if="removeId === member.id" :size="13" class="animate-spin text-red-400" />
                            <Trash2 v-else :size="13" class="text-red-400" />
                        </button>
                    </div>
                </div>
            </div>

        </div>
    </div>
</template>
