<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import { UserCheck, Loader2, Phone, Calendar, Award, X } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const toast  = useToastStore()

const venueId = route.params.id
const spaceId = route.params.spaceId

const space    = ref(null)
const members  = ref([])
const loading  = ref(true)
const cancellingId = ref(null)

onMounted(async () => {
    try {
        const [spaceRes, membersRes] = await Promise.all([
            axios.get(`/sub-courts/${spaceId}`),
            axios.get(`/subscriptions/members?court_id=${venueId}&sub_court_id=${spaceId}`)
        ])
        space.value   = spaceRes.data.space
        members.value = membersRes.data.members || []
    } catch {
        toast.error('Failed to load members')
        router.replace(`/my-venues/${venueId}/spaces/${spaceId}`)
    } finally {
        loading.value = false
    }
})

const daysLeft = (endDate) => {
    const diff = Math.ceil((new Date(endDate) - new Date()) / (1000 * 60 * 60 * 24))
    return diff
}

const fmtDate = (d) => new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })

const cancelSub = async (sub) => {
    if (!confirm(`Cancel ${sub.user_name}'s membership?`)) return
    cancellingId.value = sub.id
    try {
        await axios.put(`/subscriptions/${sub.id}/cancel`)
        members.value = members.value.filter(m => m.id !== sub.id)
        toast.success('Membership cancelled')
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to cancel')
    } finally {
        cancellingId.value = null
    }
}
</script>

<template>
    <Teleport to="#header-subject">{{ space?.name || 'Members' }}</Teleport>
    <Teleport to="#header-subtitle">{{ space?.name ? space.name + ' · Members' : 'Members' }}</Teleport>

    <div class="min-h-full bg-slate-50">
        <!-- Header -->
        <div class="bg-white px-5 pt-5 pb-4 border-b border-slate-100">
            <div class="flex items-center justify-between">
                <div>
                    <h1 class="text-lg font-bold text-slate-900">Members</h1>
                    <p class="text-xs text-slate-500">Active subscribers · {{ space?.name }}</p>
                </div>
                <div v-if="!loading" class="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center">
                    <span class="text-primary font-extrabold text-sm">{{ members.length }}</span>
                </div>
            </div>
        </div>

        <div class="px-4 py-4 pb-8">
            <div v-if="loading" class="space-y-2">
                <div v-for="i in 4" :key="i" class="h-20 bg-white rounded-2xl animate-pulse ring-1 ring-slate-100"></div>
            </div>

            <div v-else-if="!members.length" class="flex flex-col items-center justify-center py-16 text-center">
                <div class="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mb-3">
                    <UserCheck :size="26" class="text-slate-300" />
                </div>
                <p class="font-semibold text-slate-700">No active members</p>
                <p class="text-xs text-slate-400 mt-1">Members who subscribe to this space's plans will appear here</p>
            </div>

            <div v-else class="space-y-2">
                <div v-for="m in members" :key="m.id"
                    class="bg-white rounded-2xl px-4 py-3.5 shadow-sm ring-1 ring-slate-100">
                    <div class="flex items-start gap-3">
                        <!-- Avatar -->
                        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0 font-extrabold text-primary text-sm">
                            {{ (m.user_name || '?').charAt(0).toUpperCase() }}
                        </div>
                        <!-- Info -->
                        <div class="flex-1 min-w-0">
                            <p class="text-sm font-bold text-slate-800 truncate">{{ m.user_name }}</p>
                            <div class="flex items-center gap-1 text-[11px] text-slate-400 mt-0.5">
                                <Award :size="10" />
                                <span>{{ m.plan_name }}</span>
                                <span class="text-slate-300">·</span>
                                <span class="font-semibold text-primary">₹{{ m.plan_price }}</span>
                            </div>
                            <div class="flex items-center gap-3 mt-1.5">
                                <div class="flex items-center gap-1 text-[10px] text-slate-400">
                                    <Calendar :size="10" />
                                    <span>Expires {{ fmtDate(m.end_date) }}</span>
                                </div>
                                <!-- Days left badge -->
                                <span class="text-[10px] font-bold px-2 py-0.5 rounded-full"
                                    :class="daysLeft(m.end_date) <= 7 ? 'bg-red-50 text-red-500' :
                                            daysLeft(m.end_date) <= 30 ? 'bg-amber-50 text-amber-600' :
                                            'bg-emerald-50 text-emerald-600'">
                                    {{ daysLeft(m.end_date) > 0 ? daysLeft(m.end_date) + 'd left' : 'Expired' }}
                                </span>
                            </div>
                        </div>
                        <!-- Actions -->
                        <div class="shrink-0 flex flex-col items-end gap-2">
                            <a v-if="m.user_phone" :href="`tel:${m.user_phone}`"
                                class="w-8 h-8 rounded-xl bg-slate-50 flex items-center justify-center">
                                <Phone :size="13" class="text-slate-400" />
                            </a>
                            <button @click="cancelSub(m)" :disabled="cancellingId === m.id"
                                class="w-8 h-8 rounded-xl bg-red-50 flex items-center justify-center active:scale-90 transition">
                                <Loader2 v-if="cancellingId === m.id" :size="13" class="animate-spin text-red-400" />
                                <X v-else :size="13" class="text-red-400" />
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>
