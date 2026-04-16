<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import {
    Plus, Tag, Calendar,
    IndianRupee, Check, Trash2, Info, Sun, Moon, Layers3, Infinity
} from 'lucide-vue-next'

const route = useRoute()
const toast = useToastStore()

const courtId = route.params.id
const plans = ref([])
const loading = ref(true)
const addLoading = ref(false)
const showForm = ref(false)

const newPlan = ref({
    name: '',
    description: '',
    slot_type: 'unlimited',
    duration_days: 30,
    price: '',
})

const slotOptions = [
    { id: 'morning',   label: 'Morning Batch', desc: 'Access during morning peak', icon: Sun,      cls: 'text-amber-600',  bg: 'bg-amber-50 border-amber-300' },
    { id: 'evening',   label: 'Evening Batch', desc: 'Access during evening peak', icon: Moon,     cls: 'text-indigo-600', bg: 'bg-indigo-50 border-indigo-300' },
    { id: 'full_day',  label: 'Full Day',      desc: 'Both morning & evening',     icon: Layers3,  cls: 'text-primary',bg: 'bg-primary-light border-primary/30' },
    { id: 'unlimited', label: 'Unlimited',     desc: 'Any time, any slot',         icon: Infinity, cls: 'text-slate-600',  bg: 'bg-slate-50 border-slate-300' },
]

const slotMeta = {
    morning:   { label: 'Morning',   cls: 'bg-amber-100 text-amber-700' },
    evening:   { label: 'Evening',   cls: 'bg-indigo-100 text-indigo-700' },
    full_day:  { label: 'Full Day',  cls: 'bg-primary-light text-primary' },
    unlimited: { label: 'Unlimited', cls: 'bg-slate-100 text-slate-600' },
}

const durationPresets = [
    { label: '1 Month', days: 30 },
    { label: '3 Months', days: 90 },
    { label: '6 Months', days: 180 },
    { label: '1 Year', days: 365 },
]

const fetchPlans = async () => {
    try {
        const res = await axios.get(`/plans?court_id=${courtId}`)
        plans.value = res.data.records || []
    } catch {
        plans.value = []
    } finally {
        loading.value = false
    }
}

onMounted(fetchPlans)

const deletingId = ref(null)

const deletePlan = async (id) => {
    if (!confirm('Delete this plan? This cannot be undone.')) return
    deletingId.value = id
    try {
        await axios.delete(`/plans/${id}`)
        toast.success('Plan deleted')
        plans.value = plans.value.filter(p => p.id !== id)
    } catch (err) {
        const msg = err.response?.data?.message || 'Failed to delete plan'
        toast.error(msg)
    } finally {
        deletingId.value = null
    }
}

const addPlan = async () => {
    if (!newPlan.value.name || !newPlan.value.price) {
        toast.error('Plan name and price are required')
        return
    }
    addLoading.value = true
    try {
        await axios.post('/plans', { ...newPlan.value, court_id: courtId })
        toast.success('Membership plan created!')
        newPlan.value = { name: '', description: '', slot_type: 'unlimited', duration_days: 30, price: '' }
        showForm.value = false
        fetchPlans()
    } catch {
        toast.error('Failed to create plan')
    } finally {
        addLoading.value = false
    }
}
</script>

<template>
    <div class="min-h-screen bg-slate-50">

        <!-- Header -->
        <div class="bg-white px-5 pt-5 pb-5 border-b border-slate-100">
            <h1 class="text-lg font-bold text-slate-900">Membership Plans</h1>
            <p class="text-xs text-slate-500">Create & manage subscription plans for your court</p>
        </div>

        <!-- Content -->
        <div class="px-5 py-5 pb-8">

            <!-- Add Plan Button -->
            <button
                v-if="!showForm"
                @click="showForm = true"
                class="w-full flex items-center justify-center gap-2 bg-white border-2 border-dashed border-primary/30 text-primary font-semibold py-4 rounded-2xl mb-5 hover:bg-primary-light transition-colors">
                <Plus :size="18" :stroke-width="2.5" />
                Create New Plan
            </button>

            <!-- Add Plan Form -->
            <div v-if="showForm" class="card p-5 mb-5">
                <h3 class="font-bold text-slate-900 mb-4">New Membership Plan</h3>
                <div class="space-y-4">
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Plan Name *</label>
                        <input v-model="newPlan.name" type="text" placeholder="e.g. Monthly Gold, Weekend Pass" class="input-field" />
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Access Type</label>
                        <div class="grid grid-cols-2 gap-2">
                            <button
                                v-for="opt in slotOptions"
                                :key="opt.id"
                                @click="newPlan.slot_type = opt.id"
                                :class="newPlan.slot_type === opt.id
                                    ? opt.bg + ' border-2'
                                    : 'bg-white border-2 border-slate-200'"
                                class="flex items-center gap-2 p-3 rounded-xl transition-all text-left">
                                <component :is="opt.icon" :size="16" :class="opt.cls" />
                                <div>
                                    <p class="text-xs font-bold text-slate-800">{{ opt.label }}</p>
                                    <p class="text-[10px] text-slate-400">{{ opt.desc }}</p>
                                </div>
                            </button>
                        </div>
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Duration</label>
                        <div class="grid grid-cols-4 gap-2 mb-2">
                            <button
                                v-for="p in durationPresets"
                                :key="p.days"
                                @click="newPlan.duration_days = p.days"
                                :class="newPlan.duration_days === p.days
                                    ? 'bg-primary text-white border-primary'
                                    : 'bg-white text-slate-600 border-slate-200'"
                                class="py-2 rounded-xl border-2 text-xs font-semibold transition-all">
                                {{ p.label }}
                            </button>
                        </div>
                        <div class="flex items-center gap-2">
                            <input
                                v-model.number="newPlan.duration_days"
                                type="number"
                                placeholder="Or enter custom days"
                                class="input-field text-sm" />
                            <span class="text-sm text-slate-500 shrink-0 font-medium">days</span>
                        </div>
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Price (₹) *</label>
                        <input v-model="newPlan.price" type="number" placeholder="e.g. 1500" class="input-field" />
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Description</label>
                        <textarea v-model="newPlan.description" rows="2" placeholder="What's included in this plan..." class="input-field resize-none text-sm"></textarea>
                    </div>

                    <div class="flex gap-3">
                        <button @click="showForm = false" class="btn-ghost flex-1">Cancel</button>
                        <button
                            @click="addPlan"
                            :disabled="addLoading"
                            class="btn-primary flex-1 flex items-center justify-center gap-2">
                            <span v-if="addLoading" class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                            <template v-else>
                                <Check :size="16" />
                                Create Plan
                            </template>
                        </button>
                    </div>
                </div>
            </div>

            <!-- Plans List -->
            <h2 class="section-title mb-3">Active Plans</h2>

            <div v-if="loading" class="space-y-3">
                <div v-for="i in 2" :key="i" class="card p-4 animate-pulse">
                    <div class="h-4 bg-slate-200 rounded w-2/3 mb-2"></div>
                    <div class="h-3 bg-slate-200 rounded w-1/2"></div>
                </div>
            </div>

            <div v-else-if="plans.length === 0" class="text-center py-12">
                <div class="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mx-auto mb-4">
                    <Tag :size="28" class="text-slate-300" />
                </div>
                <p class="font-semibold text-slate-700">No plans yet</p>
                <p class="text-sm text-slate-400 mt-1">Create membership plans to offer subscriptions to players.</p>
            </div>

            <div v-else class="space-y-4">
                <div
                    v-for="(plan, index) in plans"
                    :key="plan.id"
                    class="card p-5 relative overflow-hidden">
                    <!-- Popular badge -->
                    <div v-if="index === 0" class="absolute top-0 right-0 bg-primary text-white text-[10px] font-bold px-3 py-1 rounded-bl-xl">
                        POPULAR
                    </div>

                    <div class="flex items-start justify-between gap-3 mb-3">
                        <div>
                            <h3 class="font-bold text-slate-900 text-base">{{ plan.name }}</h3>
                            <p v-if="plan.description" class="text-sm text-slate-500 mt-0.5">{{ plan.description }}</p>
                        </div>
                        <div class="text-right shrink-0">
                            <p class="text-2xl font-bold text-primary">₹{{ plan.price }}</p>
                        </div>
                    </div>

                    <div class="flex items-center gap-3 flex-wrap text-sm text-slate-500">
                        <span class="flex items-center gap-1.5">
                            <Calendar :size="14" class="text-slate-400" />
                            {{ plan.duration_days }} days validity
                        </span>
                        <span class="flex items-center gap-1.5 text-primary font-medium">
                            <IndianRupee :size="13" />
                            {{ Math.round(plan.price / plan.duration_days) }}/day
                        </span>
                        <span v-if="plan.slot_type" :class="(slotMeta[plan.slot_type] || slotMeta.unlimited).cls"
                            class="text-[11px] font-bold px-2 py-0.5 rounded-full">
                            {{ (slotMeta[plan.slot_type] || slotMeta.unlimited).label }}
                        </span>
                    </div>

                    <div class="mt-3 pt-3 border-t border-slate-100 flex justify-end">
                        <button
                            @click="deletePlan(plan.id)"
                            :disabled="deletingId === plan.id"
                            class="flex items-center gap-1.5 text-xs font-semibold text-red-500 hover:text-red-700 disabled:opacity-50 transition-colors">
                            <span v-if="deletingId === plan.id" class="w-3 h-3 border-2 border-red-300 border-t-red-500 rounded-full animate-spin"></span>
                            <Trash2 v-else :size="14" />
                            Delete Plan
                        </button>
                    </div>
                </div>
            </div>

            <!-- Info note -->
            <div class="mt-5 flex items-start gap-2 bg-blue-50 border border-blue-100 rounded-2xl p-4">
                <Info :size="15" class="text-blue-500 shrink-0 mt-0.5" />
                <p class="text-xs text-blue-700">Plans are visible to players on your court's booking page. Players can subscribe for unlimited access during the plan period.</p>
            </div>
        </div>
    </div>
</template>
