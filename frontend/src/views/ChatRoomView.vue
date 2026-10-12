<script setup>
import { ref, onMounted, onBeforeUnmount, nextTick, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { Send, Image, Reply, X, ChevronLeft, Info, SmilePlus, Copy } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const groupId = parseInt(route.params.id)
const group    = ref(null)
const messages = ref([])
const loading  = ref(true)
const sending  = ref(false)
const msgText  = ref('')
const replyTo  = ref(null)
const msgEnd   = ref(null)
const showReactions = ref(null)

let pollTimer = null

const loadGroup = async () => {
    try {
        const res = await axios.get(`/chat/groups/${groupId}`)
        group.value = res.data.group
    } catch { /* ignore */ }
}

const loadMessages = async () => {
    try {
        const res = await axios.get(`/chat/groups/${groupId}/messages`)
        const prev = messages.value.length
        messages.value = res.data.messages || []
        if (messages.value.length !== prev) {
            nextTick(() => scrollToBottom())
        }
    } catch { /* ignore */ }
    loading.value = false
}

const sendMessage = async () => {
    const text = msgText.value.trim()
    if (!text && !sending.value) return
    sending.value = true
    msgText.value = ''
    try {
        await axios.post(`/chat/groups/${groupId}/messages`, {
            content: text,
            reply_to: replyTo.value?.id || undefined,
        })
        replyTo.value = null
        await loadMessages()
        scrollToBottom()
    } catch { toast.error('Failed to send') }
    sending.value = false
}

const sendImage = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    try {
        const form = new FormData()
        form.append('image', file)
        const up = await axios.post('/upload', form, { headers: { 'Content-Type': 'multipart/form-data' } })
        const url = up.data.url
        if (!url) return
        await axios.post(`/chat/groups/${groupId}/messages`, { content: '', image_url: url })
        await loadMessages()
        scrollToBottom()
    } catch { toast.error('Failed to upload image') }
    e.target.value = ''
}

const toggleReaction = async (msgId, emoji) => {
    try {
        await axios.post(`/chat/messages/${msgId}/reactions`, { emoji })
        showReactions.value = null
        loadMessages()
    } catch { /* ignore */ }
}

const scrollToBottom = () => {
    nextTick(() => msgEnd.value?.scrollIntoView({ behavior: 'smooth' }))
}

const formatTime = (dt) => {
    if (!dt) return ''
    const d = new Date(dt.replace(' ', 'T'))
    const h = d.getHours()
    const m = String(d.getMinutes()).padStart(2, '0')
    const period = h >= 12 ? 'PM' : 'AM'
    const hour = h === 0 ? 12 : h > 12 ? h - 12 : h
    return `${hour}:${m} ${period}`
}

const dateBadge = (dt) => {
    if (!dt) return ''
    const d = new Date(dt.replace(' ', 'T'))
    const now = new Date()
    const diff = Math.floor((now - d) / 86400000)
    if (diff === 0) return 'Today'
    if (diff === 1) return 'Yesterday'
    return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`
}

const differentDay = (a, b) => {
    if (!a || !b) return true
    const da = new Date(a.replace(' ', 'T'))
    const db = new Date(b.replace(' ', 'T'))
    return da.toDateString() !== db.toDateString()
}

const isDm = () => group.value?.type === 'dm'

const title = () => {
    if (!group.value) return 'Chat'
    if (isDm()) {
        const other = (group.value.members || []).find(m => m.id !== auth.user?.id)
        return other?.name || 'Chat'
    }
    return group.value.name || 'Group Chat'
}

const reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏']

const groupReactions = (reactions) => {
    const map = {}
    for (const r of reactions || []) {
        if (!map[r.emoji]) map[r.emoji] = []
        map[r.emoji].push(r.user_name || '')
    }
    return map
}

const copyText = (text) => {
    navigator.clipboard.writeText(text)
    toast.success('Copied')
}

onMounted(() => {
    loadGroup()
    loadMessages()
    pollTimer = setInterval(loadMessages, 5000)
})

onBeforeUnmount(() => {
    clearInterval(pollTimer)
})
</script>

<template>
  <div class="flex flex-col h-full bg-gray-50">
    <!-- Header -->
    <div class="sticky top-0 z-10 bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
      <button @click="router.back()" class="text-gray-600"><ChevronLeft :size="24" /></button>
      <div class="flex-1 min-w-0 cursor-pointer" @click="router.push(`/chats/${groupId}/info`)">
        <p class="font-bold truncate">{{ title() }}</p>
        <p v-if="!isDm() && group" class="text-xs text-gray-400">{{ (group.members || []).length }} members</p>
      </div>
      <button @click="router.push(`/chats/${groupId}/info`)" class="text-gray-500">
        <Info :size="20" />
      </button>
    </div>

    <!-- Messages -->
    <div class="flex-1 overflow-y-auto px-4 py-4 scrollbar-hide">
      <div v-if="loading" class="flex justify-center py-20">
        <div class="animate-spin rounded-full h-8 w-8 border-2 border-primary border-t-transparent" />
      </div>
      <div v-else-if="messages.length === 0" class="text-center py-20 text-gray-400">
        <p class="text-sm">No messages yet. Say hello!</p>
      </div>
      <template v-else>
        <template v-for="(msg, i) in messages" :key="msg.id">
          <!-- Date badge -->
          <div v-if="i === 0 || differentDay(messages[i-1].created_at, msg.created_at)" class="text-center my-4">
            <span class="text-[11px] font-semibold text-gray-500 bg-gray-200 px-3 py-1 rounded-full">
              {{ dateBadge(msg.created_at) }}
            </span>
          </div>
          <!-- Message -->
          <div class="mb-1.5" :class="msg.sender_id == auth.user?.id ? 'flex justify-end' : 'flex justify-start'">
            <div class="max-w-[75%] relative group"
              @contextmenu.prevent="showReactions = showReactions === msg.id ? null : msg.id">
              <div class="px-3.5 py-2.5 rounded-2xl"
                :class="msg.sender_id == auth.user?.id
                  ? 'bg-primary text-white rounded-br-sm'
                  : 'bg-white shadow-sm rounded-bl-sm'">
                <!-- Sender name (group only) -->
                <p v-if="!isDm() && msg.sender_id != auth.user?.id && (i === 0 || messages[i-1].sender_id !== msg.sender_id)"
                  class="text-[11px] font-bold mb-1 text-primary">
                  {{ msg.sender_name }}
                </p>
                <!-- Reply quote -->
                <div v-if="msg.reply_content" class="mb-2 p-2 rounded-lg border-l-[3px]"
                  :class="msg.sender_id == auth.user?.id ? 'bg-white/15 border-white/50' : 'bg-gray-50 border-primary'">
                  <p class="text-[11px] font-bold" :class="msg.sender_id == auth.user?.id ? 'text-white/70' : 'text-primary'">
                    {{ msg.reply_sender_name }}
                  </p>
                  <p class="text-xs truncate" :class="msg.sender_id == auth.user?.id ? 'text-white/60' : 'text-gray-500'">
                    {{ msg.reply_content }}
                  </p>
                </div>
                <!-- Image -->
                <img v-if="msg.image_url" :src="msg.image_url" class="rounded-lg max-w-full mb-1.5" loading="lazy" />
                <!-- Text -->
                <p v-if="msg.content" class="text-sm leading-relaxed whitespace-pre-wrap">{{ msg.content }}</p>
                <p class="text-[10px] mt-1" :class="msg.sender_id == auth.user?.id ? 'text-white/60' : 'text-gray-400'">
                  {{ formatTime(msg.created_at) }}
                </p>
              </div>
              <!-- Reactions -->
              <div v-if="msg.reactions?.length" class="flex flex-wrap gap-1 mt-0.5" :class="msg.sender_id == auth.user?.id ? 'justify-end' : ''">
                <button v-for="(users, emoji) in groupReactions(msg.reactions)" :key="emoji"
                  @click="toggleReaction(msg.id, emoji)"
                  class="text-xs bg-gray-100 border border-gray-200 rounded-full px-1.5 py-0.5 hover:bg-gray-200">
                  {{ emoji }} {{ users.length }}
                </button>
              </div>
              <!-- Action menu (hover/long-press) -->
              <div v-if="showReactions === msg.id"
                class="absolute z-20 bg-white rounded-2xl shadow-lg border border-gray-100 p-2 flex gap-1.5"
                :class="msg.sender_id == auth.user?.id ? 'right-0 -top-14' : 'left-0 -top-14'">
                <button v-for="e in reactionEmojis" :key="e" @click="toggleReaction(msg.id, e)"
                  class="w-9 h-9 flex items-center justify-center rounded-full hover:bg-gray-100 text-lg">{{ e }}</button>
                <button @click="replyTo = msg; showReactions = null"
                  class="w-9 h-9 flex items-center justify-center rounded-full hover:bg-gray-100">
                  <Reply :size="16" class="text-gray-600" />
                </button>
                <button v-if="msg.content" @click="copyText(msg.content); showReactions = null"
                  class="w-9 h-9 flex items-center justify-center rounded-full hover:bg-gray-100">
                  <Copy :size="16" class="text-gray-600" />
                </button>
              </div>
            </div>
          </div>
        </template>
        <div ref="msgEnd" />
      </template>
    </div>

    <!-- Reply preview -->
    <div v-if="replyTo" class="px-4 py-2 bg-gray-50 border-t border-gray-200 flex items-center gap-3">
      <div class="w-[3px] h-9 bg-primary rounded-full shrink-0" />
      <div class="flex-1 min-w-0">
        <p class="text-xs font-bold text-primary">{{ replyTo.sender_name }}</p>
        <p class="text-xs text-gray-500 truncate">{{ replyTo.content || '📷 Photo' }}</p>
      </div>
      <button @click="replyTo = null"><X :size="16" class="text-gray-400" /></button>
    </div>

    <!-- Input bar -->
    <div class="bg-white border-t border-gray-100 px-3 py-2 flex items-end gap-2">
      <label class="cursor-pointer p-2 text-gray-500 hover:text-gray-700">
        <Image :size="22" />
        <input type="file" accept="image/*" class="hidden" @change="sendImage" />
      </label>
      <div class="flex-1 bg-gray-100 rounded-full px-4 py-2.5">
        <textarea v-model="msgText" @keydown.enter.exact.prevent="sendMessage" rows="1"
          placeholder="Type a message..." class="w-full bg-transparent resize-none outline-none text-sm max-h-24" />
      </div>
      <button @click="sendMessage" :disabled="sending || !msgText.trim()"
        class="w-10 h-10 rounded-full bg-primary text-white flex items-center justify-center shrink-0 disabled:opacity-50">
        <Send :size="18" />
      </button>
    </div>
  </div>
</template>
