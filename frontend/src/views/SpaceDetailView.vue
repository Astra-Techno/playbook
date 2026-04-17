<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import {
    Tag, Award, Ban, CalendarCheck, Users, Lock,
    ChevronRight, Loader2, LayoutGrid, UserCheck
} from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const toast  = useToastStore()

const venueId = route.params.id
const spaceId = route.params.spaceId

const space   = ref(null)
const loading = ref(true)

onMounted(async () => {
    try {
        const res = await axios.get(`/sub-courts/${spaceId}`)
        space.value = res.data.space
    } catch {
        toast.error('Failed to load space')
        router.replace(`/my-venues/${venueId}/spaces`)
    } finally {
        loading.value = false
    }
})

const menuItems = computed(() => [
    {
        label: 'Pricing Rules',
        desc:  'Set peak hour rates and special prices',
        icon:  Tag,
        to:    `/my-venues/${venueId}/spaces/${spaceId}/pricing`,
    },
    {
        label: 'Membership Plans',
        desc:  'Create subscription plans for this space',
        icon:  Award,
        to:    `/my-venues/${venueId}/spaces/${spaceId}/plans`,
    },
    {
        label: 'Block Slots',
        desc:  'Mark time slots as unavailable',
        icon:  Ban,
        to:    `/my-venues/${venueId}/spaces/${spaceId}/block`,
    },
    {
        label: 'Bookings',
        desc:  'View all bookings for this space',
        icon:  CalendarCheck,
        to:    `/my-venues/${venueId}/spaces/${spaceId}/bookings`,
    },
    {
        label: 'Members',
        desc:  'Active subscribers for this space',
        icon:  UserCheck,
        to:    `/my-venues/${venueId}/spaces/${spaceId}/members`,
    },
])
</script>

<template>
    <Teleport to="#header-subject">{{ space?.name || 'Space' }}</Teleport>
    <Teleport to="#header-subtitle">Space Settings</Teleport>

    <div class="min-h-screen bg-slate-50">

        <div v-if="loading" class="flex items-center justify-center h-64">
            <Loader2 :size="28" class="text-primary animate-spin" />
        </div>

        <template v-else-if="space">
            <!-- Space info card -->
            <div class="mx-4 mt-5 bg-white rounded-2xl overflow-hidden shadow-sm ring-1 ring-slate-100 mb-5">
                <!-- Image or placeholder -->
                <div class="relative h-36 bg-slate-100">
                    <img v-if="space.image_url" :src="space.image_url"
                        class="w-full h-full object-cover"
                        onerror="this.style.display='none'" />
                    <div v-else class="w-full h-full flex items-center justify-center">
                        <LayoutGrid :size="40" :stroke-width="1.5" class="text-slate-300" />
                    </div>
                    <!-- Mode badge -->
                    <div class="absolute top-3 left-3 flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold shadow-sm"
                        :class="space.booking_mode === 'shared'
                            ? 'bg-blue-500 text-white'
                            : 'bg-emerald-500 text-white'">
                        <Users v-if="space.booking_mode === 'shared'" :size="10" :stroke-width="3" />
                        <Lock v-else :size="10" :stroke-width="3" />
                        {{ space.booking_mode === 'shared' ? `Shared · ${space.capacity} cap` : 'Exclusive' }}
                    </div>
                </div>

                <div class="p-4">
                    <h1 class="text-xl font-bold text-slate-900">{{ space.name }}</h1>
                    <p v-if="space.description" class="text-sm text-slate-500 mt-0.5">{{ space.description }}</p>
                    <div class="mt-3 flex items-end justify-between">
                        <div v-if="space.hourly_rate">
                            <span class="text-xs text-slate-400 font-medium block">Rate</span>
                            <span class="text-primary font-bold text-lg">₹{{ space.hourly_rate }}<span class="text-sm font-normal text-slate-500">/hr</span></span>
                        </div>
                        <div v-else>
                            <span class="text-xs text-slate-400">Uses venue base rate</span>
                        </div>
                        <button @click="router.push(`/my-venues/${venueId}/spaces`)"
                            class="text-xs font-bold text-primary bg-primary/10 px-3 py-1.5 rounded-full">
                            All Spaces
                        </button>
                    </div>
                </div>
            </div>

            <!-- Menu -->
            <div class="px-4 pb-8">
                <p class="text-[11px] font-bold text-slate-400 uppercase tracking-widest mb-2 px-1">Configure</p>
                <div class="bg-white rounded-2xl overflow-hidden divide-y divide-slate-50" style="box-shadow:0 1px 6px rgba(0,0,0,0.06)">
                    <button
                        v-for="item in menuItems"
                        :key="item.label"
                        @click="router.push(item.to)"
                        class="w-full flex items-center gap-3 px-4 py-3.5 hover:bg-slate-50 active:bg-slate-100 transition-colors">
                        <div class="w-9 h-9 bg-slate-100 rounded-xl flex items-center justify-center shrink-0">
                            <component :is="item.icon" :size="17" class="text-slate-600" />
                        </div>
                        <div class="flex-1 text-left">
                            <p class="text-sm font-semibold text-slate-800">{{ item.label }}</p>
                            <p class="text-xs text-slate-400">{{ item.desc }}</p>
                        </div>
                        <ChevronRight :size="15" class="text-slate-300" />
                    </button>
                </div>
            </div>
        </template>

    </div>
</template>
