<script setup>
import { ref, watch } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { X, UserPlus, Trash2, Shield, Eye, Loader2, Phone, Users } from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    court: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue'])

const auth  = useAuthStore()
const toast = useToastStore()

const staff       = ref([])
const loadingList = ref(false)
const phone       = ref('')
const role        = ref('manager')
const addLoading  = ref(false)
const removeId    = ref(null)

const close = () => emit('update:modelValue', false)

const fetchStaff = async () => {
    if (!props.court) return
    loadingList.value = true
    try {
        const res = await axios.get(`/court-staff?court_id=${props.court.id}&owner_id=${auth.user.id}`)
        staff.value = res.data.staff || []
    } catch { staff.value = [] }
    finally { loadingList.value = false }
}

watch(() => props.modelValue, (open) => {
    if (open) { phone.value = ''; role.value = 'manager'; fetchStaff() }
})

const addStaff = async () => {
    if (!phone.value.trim()) { toast.error('Enter a phone number'); return }
    addLoading.value = true
    try {
        const res = await axios.post('/court-staff', {
            court_id: props.court.id,
            owner_id: auth.user.id,
            phone:    phone.value.trim(),
            role:     role.value,
        })
        staff.value.push(res.data.staff)
        phone.value = ''
        toast.success(res.data.message)
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to add staff')
    } finally {
        addLoading.value = false
    }
}

const removeStaff = async (member) => {
    removeId.value = member.id
    try {
        await axios.delete(`/court-staff/${member.id}`, { data: { owner_id: auth.user.id } })
        staff.value = staff.value.filter(s => s.id !== member.id)
        toast.success(`${member.name} removed`)
    } catch {
        toast.error('Failed to remove')
    } finally {
        removeId.value = null
    }
}

const initials = (name) => (name || '?').split(' ').map(p => p[0]).join('').toUpperCase().slice(0, 2)
</script>

<template>
    <Teleport to="#app-root">
        <Transition
            enter-active-class="transition duration-300 ease-out" enter-from-class="opacity-0" enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"  leave-from-class="opacity-100" leave-to-class="opacity-0">
            <div v-if="modelValue && court" class="absolute inset-0 bg-black/50 z-[160]" @click.self="close">
                <Transition
                    enter-active-class="transition duration-300 ease-out" enter-from-class="translate-y-full" enter-to-class="translate-y-0"
                    leave-active-class="transition duration-200 ease-in"  leave-from-class="translate-y-0"    leave-to-class="translate-y-full">
                    <div v-if="modelValue" class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl max-h-[88vh] flex flex-col">

                        <!-- Handle + Header -->
                        <div class="pt-3 shrink-0">
                            <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-3"></div>
                            <div class="flex items-center justify-between px-5 pb-4 border-b border-slate-100">
                                <div>
                                    <p class="text-[10px] font-black text-primary uppercase tracking-wider">{{ court.name }}</p>
                                    <h3 class="text-base font-extrabold text-slate-900">Manage Staff</h3>
                                </div>
                                <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <div class="flex-1 overflow-y-auto px-5 py-5 space-y-6">

                            <!-- Add Staff -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3">Add Staff Member</p>
                                <div class="space-y-2">
                                    <!-- Phone input -->
                                    <div class="flex items-center gap-2 ring-1 ring-slate-200 rounded-xl px-4 h-12 focus-within:ring-primary transition-all bg-white">
                                        <Phone :size="15" class="text-slate-400 shrink-0" />
                                        <input v-model="phone" type="tel" placeholder="Staff phone number"
                                            class="flex-1 text-sm bg-transparent border-none focus:ring-0 placeholder:text-slate-300"
                                            @keyup.enter="addStaff" />
                                    </div>
                                    <!-- Role selector -->
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
                                    <!-- Role description -->
                                    <p class="text-[11px] text-slate-400 px-1">
                                        <template v-if="role === 'manager'">Can view, create &amp; cancel bookings</template>
                                        <template v-else>Can view bookings only</template>
                                    </p>
                                    <button @click="addStaff" :disabled="addLoading"
                                        class="w-full bg-primary text-white text-sm font-extrabold py-3 rounded-xl flex items-center justify-center gap-2 active:scale-[0.98] transition-transform disabled:opacity-60">
                                        <Loader2 v-if="addLoading" :size="15" class="animate-spin" />
                                        <UserPlus v-else :size="15" />
                                        Add Staff
                                    </button>
                                </div>
                            </div>

                            <!-- Staff List -->
                            <div>
                                <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3">
                                    Current Staff
                                    <span v-if="staff.length" class="ml-1 bg-slate-100 text-slate-500 px-1.5 py-0.5 rounded-full text-[10px]">{{ staff.length }}</span>
                                </p>

                                <div v-if="loadingList" class="space-y-3">
                                    <div v-for="i in 2" :key="i" class="h-14 bg-slate-100 rounded-2xl animate-pulse"></div>
                                </div>

                                <div v-else-if="staff.length === 0"
                                    class="flex flex-col items-center py-8 text-center">
                                    <div class="w-12 h-12 rounded-2xl bg-slate-100 flex items-center justify-center mb-3">
                                        <Users :size="22" class="text-slate-400" />
                                    </div>
                                    <p class="text-sm font-bold text-slate-500">No staff added yet</p>
                                    <p class="text-xs text-slate-400 mt-1">Add staff by phone number above</p>
                                </div>

                                <div v-else class="space-y-2">
                                    <div v-for="member in staff" :key="member.id"
                                        class="flex items-center gap-3 bg-slate-50 rounded-2xl px-4 py-3">
                                        <!-- Avatar -->
                                        <div class="w-10 h-10 rounded-full bg-primary-light flex items-center justify-center shrink-0 overflow-hidden">
                                            <img v-if="member.avatar_url" :src="member.avatar_url" class="w-full h-full object-cover" />
                                            <span v-else class="text-xs font-extrabold text-primary">{{ initials(member.name) }}</span>
                                        </div>
                                        <!-- Info -->
                                        <div class="flex-1 min-w-0">
                                            <p class="text-sm font-bold text-slate-800 truncate">{{ member.name }}</p>
                                            <p class="text-xs text-slate-400">{{ member.phone }}</p>
                                        </div>
                                        <!-- Role badge -->
                                        <span class="text-[10px] font-black px-2.5 py-1 rounded-full shrink-0"
                                            :class="member.role === 'manager' ? 'bg-primary/10 text-primary' : 'bg-slate-200 text-slate-500'">
                                            {{ member.role }}
                                        </span>
                                        <!-- Remove -->
                                        <button @click="removeStaff(member)" :disabled="removeId === member.id"
                                            class="w-8 h-8 rounded-full bg-red-50 flex items-center justify-center shrink-0 active:scale-90 transition-transform disabled:opacity-50">
                                            <Loader2 v-if="removeId === member.id" :size="13" class="animate-spin text-red-400" />
                                            <Trash2 v-else :size="13" class="text-red-400" />
                                        </button>
                                    </div>
                                </div>
                            </div>

                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
