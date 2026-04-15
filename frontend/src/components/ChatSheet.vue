<script setup>
import { ref, watch, nextTick, onUnmounted } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { X, Send, Loader2, MessageCircle } from 'lucide-vue-next'

const props = defineProps({
    modelValue: Boolean,
    bookingId:  { type: Number, required: true },
    receiverId: { type: Number, required: true },
    receiverName: { type: String, default: 'Owner' },
    courtName:  { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue'])

const auth     = useAuthStore()
const messages = ref([])
const text     = ref('')
const loading  = ref(false)
const sending  = ref(false)
const listRef  = ref(null)
let   pollTimer = null

const close = () => emit('update:modelValue', false)

const scrollBottom = () => nextTick(() => {
    if (listRef.value) listRef.value.scrollTop = listRef.value.scrollHeight
})

const fetchMessages = async () => {
    if (!props.bookingId || !auth.user?.id) return
    try {
        const res = await axios.get(`/messages?booking_id=${props.bookingId}&user_id=${auth.user.id}`)
        const fetched = res.data.messages || []
        // Only scroll if new messages arrived
        const hadNew = fetched.length !== messages.value.length
        messages.value = fetched
        if (hadNew) scrollBottom()
    } catch {}
}

const send = async () => {
    const body = text.value.trim()
    if (!body || sending.value) return
    sending.value = true
    try {
        await axios.post('/messages', {
            booking_id:  props.bookingId,
            sender_id:   auth.user?.id,
            receiver_id: props.receiverId,
            body,
        })
        text.value = ''
        await fetchMessages()
    } catch {} finally { sending.value = false }
}

watch(() => props.modelValue, async (open) => {
    if (open) {
        loading.value = true
        await fetchMessages()
        loading.value = false
        scrollBottom()
        // Poll every 5s while sheet is open
        pollTimer = setInterval(fetchMessages, 5000)
    } else {
        clearInterval(pollTimer)
        pollTimer = null
        messages.value = []
    }
})

onUnmounted(() => clearInterval(pollTimer))

const isMine = (msg) => msg.sender_id === auth.user?.id

const fmtTime = (dt) => {
    const d = new Date(dt)
    const today = new Date()
    const sameDay = d.toDateString() === today.toDateString()
    if (sameDay) return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
    return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) + ' · ' +
           d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
}
</script>

<template>
    <Teleport to="#app-root">
        <Transition
            enter-active-class="transition duration-250 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-150 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="modelValue" class="absolute inset-0 bg-black/50 z-[200] flex items-end" @click.self="close">
                <div class="bg-white w-full rounded-t-3xl flex flex-col" style="max-height: 80vh;">

                    <!-- Header -->
                    <div class="flex items-center gap-3 px-5 pt-5 pb-4 border-b border-slate-100 shrink-0">
                        <div class="w-9 h-9 rounded-full bg-primary flex items-center justify-center shrink-0">
                            <MessageCircle :size="16" class="text-white" />
                        </div>
                        <div class="flex-1 min-w-0">
                            <p class="font-bold text-slate-900 text-sm truncate">{{ receiverName }}</p>
                            <p v-if="courtName" class="text-[11px] text-slate-400 truncate">{{ courtName }}</p>
                        </div>
                        <button @click="close" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center shrink-0">
                            <X :size="16" class="text-slate-500" />
                        </button>
                    </div>

                    <!-- Messages -->
                    <div ref="listRef" class="flex-1 overflow-y-auto px-4 py-4 space-y-3 min-h-0">
                        <div v-if="loading" class="flex items-center justify-center py-8">
                            <Loader2 :size="24" class="animate-spin text-primary" />
                        </div>
                        <div v-else-if="messages.length === 0"
                            class="flex flex-col items-center justify-center py-10 text-slate-400">
                            <MessageCircle :size="36" class="mb-2 text-slate-200" />
                            <p class="text-sm">No messages yet</p>
                            <p class="text-xs mt-1">Start the conversation below</p>
                        </div>
                        <template v-else>
                            <div v-for="msg in messages" :key="msg.id"
                                class="flex"
                                :class="isMine(msg) ? 'justify-end' : 'justify-start'">
                                <div class="max-w-[75%]">
                                    <div class="px-3.5 py-2.5 rounded-2xl text-sm leading-relaxed"
                                        :class="isMine(msg)
                                            ? 'bg-primary text-white rounded-br-sm'
                                            : 'bg-slate-100 text-slate-800 rounded-bl-sm'">
                                        {{ msg.body }}
                                    </div>
                                    <p class="text-[10px] text-slate-400 mt-1"
                                        :class="isMine(msg) ? 'text-right' : 'text-left'">
                                        {{ fmtTime(msg.created_at) }}
                                    </p>
                                </div>
                            </div>
                        </template>
                    </div>

                    <!-- Input -->
                    <div class="px-4 py-3 border-t border-slate-100 shrink-0 flex items-end gap-2">
                        <textarea
                            v-model="text"
                            rows="1"
                            placeholder="Type a message..."
                            class="flex-1 min-h-[42px] max-h-24 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-primary/30 placeholder:text-slate-400"
                            @keydown.enter.exact.prevent="send"
                            style="field-sizing: content;"
                        />
                        <button @click="send" :disabled="!text.trim() || sending"
                            class="w-10 h-10 rounded-full bg-primary flex items-center justify-center shrink-0 active:scale-90 transition-all disabled:opacity-40">
                            <Loader2 v-if="sending" :size="16" class="animate-spin text-white" />
                            <Send v-else :size="16" class="text-white" />
                        </button>
                    </div>

                </div>
            </div>
        </Transition>
    </Teleport>
</template>
