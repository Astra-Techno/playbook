<script setup>
import { computed, ref } from 'vue'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import { X, Clock, FileText, Loader2, ShieldAlert } from 'lucide-vue-next'

const props = defineProps({
    modelValue: { type: Boolean, default: false },
    block:      { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue', 'unblocked'])
const toast = useToastStore()

const close = () => emit('update:modelValue', false)
const unblockLoading = ref(false)

const BLOCK_KIND_META = {
    maintenance:   { label: 'Maintenance',   cls: 'bg-amber-100 text-amber-700' },
    holiday:       { label: 'Holiday',        cls: 'bg-blue-100 text-blue-700' },
    private_event: { label: 'Private Event',  cls: 'bg-purple-100 text-purple-700' },
    tournament:    { label: 'Tournament',     cls: 'bg-emerald-100 text-emerald-700' },
    coaching:      { label: 'Coaching',       cls: 'bg-cyan-100 text-cyan-700' },
    other:         { label: 'Blocked',        cls: 'bg-slate-100 text-slate-600' },
}

const kindMeta = computed(() => BLOCK_KIND_META[props.block?.block_kind] ?? BLOCK_KIND_META.other)

const formatTime = (dt) => {
    if (!dt) return ''
    const t = dt.includes(' ') ? dt.split(' ')[1] : dt
    const [h, m] = t.split(':').map(Number)
    const suffix = h >= 12 ? 'PM' : 'AM'
    return `${h % 12 || 12}:${String(m).padStart(2,'0')} ${suffix}`
}
const formatDate = (dt) => {
    if (!dt) return ''
    const d = dt.includes(' ') ? dt.split(' ')[0] : dt
    return new Date(d + 'T00:00:00').toLocaleDateString('en-IN', {
        weekday: 'short', day: 'numeric', month: 'short'
    })
}

const unblock = async () => {
    if (!confirm('Remove this block?')) return
    unblockLoading.value = true
    try {
        await axios.delete(`/blocked-slots/${props.block.id}`)
        toast.success('Block removed')
        emit('unblocked', props.block.id)
        close()
    } catch {
        toast.error('Could not remove block')
    } finally {
        unblockLoading.value = false
    }
}
</script>

<template>
    <Teleport to="#app-root">
        <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="modelValue && block" class="absolute inset-0 bg-black/40 z-[200]" @click.self="close">
                <Transition
                    enter-active-class="transition duration-300 ease-out"
                    enter-from-class="translate-y-full"
                    enter-to-class="translate-y-0"
                    leave-active-class="transition duration-200 ease-in"
                    leave-from-class="translate-y-0"
                    leave-to-class="translate-y-full">
                    <div v-if="modelValue && block"
                         class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl pb-10">

                        <!-- Handle + header -->
                        <div class="pt-3 pb-4 px-5 border-b border-slate-100">
                            <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-4"></div>
                            <div class="flex items-center justify-between">
                                <h3 class="text-base font-extrabold text-slate-900">Blocked Slot</h3>
                                <button @click="close"
                                    class="w-8 h-8 flex items-center justify-center rounded-full bg-slate-100 active:scale-90 transition-transform">
                                    <X :size="16" class="text-slate-500" />
                                </button>
                            </div>
                        </div>

                        <!-- Content -->
                        <div class="px-5 pt-4 space-y-4">

                            <!-- Kind badge -->
                            <div class="flex items-center gap-3">
                                <div class="w-10 h-10 rounded-2xl bg-red-50 flex items-center justify-center shrink-0">
                                    <ShieldAlert :size="18" class="text-red-500" />
                                </div>
                                <div>
                                    <span class="text-xs font-bold px-3 py-1.5 rounded-full" :class="kindMeta.cls">
                                        {{ kindMeta.label }}
                                    </span>
                                </div>
                            </div>

                            <!-- Date + Time -->
                            <div class="bg-slate-50 rounded-2xl px-4 py-3 flex items-center gap-3">
                                <Clock :size="18" class="text-primary shrink-0" />
                                <div>
                                    <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-0.5">
                                        {{ formatDate(block.start_time) }}
                                    </p>
                                    <p class="text-sm font-extrabold text-slate-900">
                                        {{ formatTime(block.start_time) }} – {{ formatTime(block.end_time) }}
                                    </p>
                                </div>
                            </div>

                            <!-- Reason -->
                            <div v-if="block.reason" class="bg-slate-50 rounded-2xl px-4 py-3 flex items-start gap-3">
                                <FileText :size="16" class="text-slate-400 mt-0.5 shrink-0" />
                                <p class="text-sm text-slate-600 leading-relaxed">{{ block.reason }}</p>
                            </div>

                            <!-- Unblock -->
                            <button @click="unblock" :disabled="unblockLoading"
                                class="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl
                                       bg-red-50 text-red-600 font-bold text-sm
                                       active:bg-red-100 active:scale-[0.98] transition-all
                                       disabled:opacity-50">
                                <Loader2 v-if="unblockLoading" :size="16" class="animate-spin" />
                                <span v-else>Remove Block</span>
                            </button>
                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
