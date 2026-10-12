<script setup>
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'
import { MessageCircle, Plus, Users, BellOff } from 'lucide-vue-next'

const auth   = useAuthStore()
const router = useRouter()
const groups  = ref([])
const loading = ref(true)

const loadGroups = async () => {
    try {
        const res = await axios.get('/chat/groups')
        groups.value = res.data.groups || []
    } catch { /* ignore */ }
    loading.value = false
}

onMounted(loadGroups)

const timeAgo = (dt) => {
    if (!dt) return ''
    const date = new Date(dt.replace(' ', 'T'))
    const diff = (Date.now() - date.getTime()) / 1000
    if (diff < 60) return 'now'
    if (diff < 3600) return `${Math.floor(diff / 60)}m`
    if (diff < 86400) return `${Math.floor(diff / 3600)}h`
    if (diff < 604800) return `${Math.floor(diff / 86400)}d`
    return `${date.getDate()}/${date.getMonth() + 1}`
}

const groupName = (g) => {
    if (g.type === 'dm' && g.dm_user) return g.dm_user.name || 'User'
    return g.name || 'Group'
}

const groupAvatar = (g) => {
    if (g.type === 'dm' && g.dm_user) return g.dm_user.avatar_url
    return g.icon_url
}

const groupInitial = (g) => {
    const name = groupName(g)
    return name ? name[0].toUpperCase() : '?'
}

const subtitle = (g) => {
    const msg = g.last_message || ''
    const sender = g.last_message_sender || ''
    const img = g.last_message_image
    if (msg) return g.type === 'dm' ? msg : `${sender}: ${msg}`
    if (img) return g.type === 'dm' ? '📷 Photo' : `${sender}: 📷 Photo`
    return g.type === 'dm' ? 'Start chatting' : 'No messages yet'
}
</script>

<template>
  <div class="page-gutter pb-24">
    <!-- Header -->
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-extrabold">Chats</h2>
      <button @click="router.push('/chats/new')" class="btn-primary !py-2 !px-3 flex items-center gap-1.5 text-sm">
        <Plus :size="16" /> New Chat
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex justify-center py-20">
      <div class="animate-spin rounded-full h-8 w-8 border-2 border-primary border-t-transparent" />
    </div>

    <!-- Empty -->
    <div v-else-if="groups.length === 0" class="text-center py-20">
      <MessageCircle :size="48" class="mx-auto text-gray-300 mb-4" />
      <p class="font-bold text-gray-700">No conversations yet</p>
      <p class="text-sm text-gray-400 mt-1">Tap "New Chat" to start messaging</p>
    </div>

    <!-- Groups list -->
    <div v-else class="space-y-1">
      <div v-for="g in groups" :key="g.id"
        @click="router.push(`/chats/${g.id}`)"
        class="flex items-center gap-3.5 p-3.5 rounded-2xl cursor-pointer hover:bg-gray-50 active:bg-gray-100 transition-colors">
        <!-- Avatar -->
        <div class="relative shrink-0">
          <img v-if="groupAvatar(g)" :src="groupAvatar(g)" class="w-13 h-13 rounded-full object-cover" />
          <div v-else class="w-13 h-13 rounded-full flex items-center justify-center"
            :class="g.type === 'dm' ? 'bg-gray-100' : 'bg-primary/10'">
            <span v-if="g.type === 'dm'" class="text-lg font-bold text-primary">{{ groupInitial(g) }}</span>
            <Users v-else :size="20" class="text-primary" />
          </div>
        </div>
        <!-- Content -->
        <div class="flex-1 min-w-0">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2 min-w-0">
              <span class="font-semibold truncate" :class="{ 'font-extrabold': g.unread_count > 0 }">{{ groupName(g) }}</span>
              <span v-if="g.type !== 'dm'" class="text-[10px] text-gray-400 bg-gray-100 px-1.5 py-0.5 rounded-md shrink-0">{{ g.member_count }}</span>
            </div>
            <span class="text-xs shrink-0 ml-2" :class="g.unread_count > 0 ? 'text-primary font-bold' : 'text-gray-400'">
              {{ timeAgo(g.last_message_at) }}
            </span>
          </div>
          <div class="flex items-center gap-2 mt-1">
            <BellOff v-if="g.muted == 1" :size="12" class="text-gray-400 shrink-0" />
            <p class="text-sm truncate" :class="g.unread_count > 0 ? 'text-gray-800 font-semibold' : 'text-gray-500'">
              {{ subtitle(g) }}
            </p>
            <span v-if="g.unread_count > 0"
              class="ml-auto shrink-0 bg-primary text-white text-[11px] font-bold rounded-full min-w-[20px] h-5 flex items-center justify-center px-1.5">
              {{ g.unread_count > 99 ? '99+' : g.unread_count }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
