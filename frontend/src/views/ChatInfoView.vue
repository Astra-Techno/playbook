<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { ChevronLeft, Bell, BellOff, UserPlus, Trash2, LogOut, Edit, X } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const groupId = parseInt(route.params.id)
const group    = ref(null)
const members  = ref([])
const loading  = ref(true)
const isMuted  = ref(false)

// Member picker state
const showPicker  = ref(false)
const searchQuery = ref('')
const searchResults = ref([])
const selectedIds   = ref(new Set())
const searching     = ref(false)

const load = async () => {
    try {
        const res = await axios.get(`/chat/groups/${groupId}`)
        group.value = res.data.group
        members.value = res.data.group?.members || []
        const me = members.value.find(m => m.id === auth.user?.id)
        isMuted.value = me?.muted == 1
    } catch { /* ignore */ }
    loading.value = false
}

onMounted(load)

const isAdmin = computed(() => members.value.some(m => m.id === auth.user?.id && m.role === 'admin'))
const isDm = computed(() => group.value?.type === 'dm')

const toggleMute = async () => {
    try {
        await axios.put(`/chat/groups/${groupId}/mute`, { muted: !isMuted.value })
        isMuted.value = !isMuted.value
    } catch { /* ignore */ }
}

const editGroup = async () => {
    const name = prompt('Group name', group.value?.name || '')
    if (name === null || !name.trim()) return
    const desc = prompt('Description (optional)', group.value?.description || '')
    try {
        await axios.put(`/chat/groups/${groupId}`, { name: name.trim(), description: desc?.trim() || '' })
        load()
    } catch { toast.error('Failed to update') }
}

const removeMember = async (userId, name) => {
    if (!confirm(`Remove ${name}?`)) return
    try {
        await axios.delete(`/chat/groups/${groupId}/members/${userId}`)
        load()
    } catch { toast.error('Failed to remove') }
}

const leaveGroup = async () => {
    if (!confirm('Leave this group?')) return
    try {
        await axios.delete(`/chat/groups/${groupId}/members/${auth.user?.id}`)
        router.replace('/chats')
    } catch { toast.error('Failed to leave') }
}

const deleteGroup = async () => {
    if (!confirm('Delete this group and all messages?')) return
    try {
        await axios.delete(`/chat/groups/${groupId}`)
        router.replace('/chats')
    } catch { toast.error('Failed to delete') }
}

// Member picker
let searchTimer = null
const onSearch = (q) => {
    clearTimeout(searchTimer)
    if (q.length < 2) { searchResults.value = []; return }
    searching.value = true
    searchTimer = setTimeout(async () => {
        try {
            const res = await axios.get('/chat/users/search', { params: { q } })
            const existing = new Set(members.value.map(m => m.id))
            searchResults.value = (res.data.users || []).filter(u => !existing.has(u.id))
        } catch { /* ignore */ }
        searching.value = false
    }, 400)
}

const toggleSelect = (id) => {
    const s = new Set(selectedIds.value)
    s.has(id) ? s.delete(id) : s.add(id)
    selectedIds.value = s
}

const addSelectedMembers = async () => {
    if (selectedIds.value.size === 0) return
    try {
        await axios.post(`/chat/groups/${groupId}/members`, { user_ids: [...selectedIds.value] })
        showPicker.value = false
        selectedIds.value = new Set()
        searchQuery.value = ''
        searchResults.value = []
        load()
        toast.success('Members added')
    } catch { toast.error('Failed to add') }
}
</script>

<template>
  <div class="min-h-screen bg-white">
    <!-- Header -->
    <div class="sticky top-0 z-10 bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
      <button @click="router.back()" class="text-gray-600"><ChevronLeft :size="24" /></button>
      <p class="font-bold flex-1">{{ isDm ? 'Chat Info' : 'Group Info' }}</p>
      <button v-if="isAdmin && !isDm" @click="editGroup" class="text-primary"><Edit :size="20" /></button>
    </div>

    <div v-if="loading" class="flex justify-center py-20">
      <div class="animate-spin rounded-full h-8 w-8 border-2 border-primary border-t-transparent" />
    </div>

    <div v-else class="page-gutter">
      <!-- Group header -->
      <div class="text-center py-8">
        <div class="w-20 h-20 rounded-full mx-auto flex items-center justify-center"
          :class="isDm ? 'bg-gray-100' : 'bg-primary/10'">
          <img v-if="group?.icon_url" :src="group.icon_url" class="w-20 h-20 rounded-full object-cover" />
          <span v-else class="text-3xl">{{ isDm ? '💬' : '👥' }}</span>
        </div>
        <h2 class="text-xl font-extrabold mt-4">{{ group?.name || 'Chat' }}</h2>
        <p v-if="group?.description" class="text-sm text-gray-500 mt-1">{{ group.description }}</p>
        <p class="text-xs text-gray-400 mt-1">{{ members.length }} members</p>
      </div>

      <!-- Mute -->
      <div @click="toggleMute" class="menu-row cursor-pointer">
        <component :is="isMuted ? BellOff : Bell" :size="18" class="text-gray-500" />
        <span>{{ isMuted ? 'Unmute notifications' : 'Mute notifications' }}</span>
      </div>

      <!-- Members -->
      <template v-if="!isDm">
        <div class="divider-band" />
        <div class="flex items-center justify-between mb-2">
          <h3 class="section-title !mb-0">Members</h3>
          <button v-if="isAdmin" @click="showPicker = true" class="text-sm text-primary font-semibold flex items-center gap-1">
            <UserPlus :size="14" /> Add
          </button>
        </div>
        <div v-for="m in members" :key="m.id" class="flex items-center gap-3 py-3">
          <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center shrink-0 overflow-hidden">
            <img v-if="m.avatar_url" :src="m.avatar_url" class="w-full h-full object-cover" />
            <span v-else class="font-bold text-primary">{{ (m.name || '?')[0].toUpperCase() }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="font-semibold truncate">{{ m.id === auth.user?.id ? 'You' : m.name }}</span>
              <span v-if="m.role === 'admin'" class="text-[10px] bg-primary/10 text-primary font-bold px-1.5 py-0.5 rounded">Admin</span>
            </div>
            <p v-if="m.phone" class="text-xs text-gray-400">{{ m.phone }}</p>
          </div>
          <button v-if="isAdmin && m.id !== auth.user?.id" @click="removeMember(m.id, m.name)"
            class="text-red-300 hover:text-red-500">
            <X :size="16" />
          </button>
        </div>
      </template>

      <!-- Actions -->
      <div class="divider-band" />
      <div v-if="!isDm" @click="leaveGroup" class="menu-row text-red-500 cursor-pointer">
        <LogOut :size="18" /> Leave group
      </div>
      <div v-if="isAdmin && !isDm" @click="deleteGroup" class="menu-row text-red-500 cursor-pointer">
        <Trash2 :size="18" /> Delete group
      </div>
    </div>

    <!-- Member picker modal -->
    <div v-if="showPicker" class="fixed inset-0 z-50 bg-black/50 flex items-end">
      <div class="bg-white rounded-t-2xl w-full max-h-[80vh] flex flex-col">
        <div class="p-4 border-b border-gray-100 flex items-center justify-between">
          <h3 class="font-bold">Add Members</h3>
          <div class="flex items-center gap-3">
            <button v-if="selectedIds.size > 0" @click="addSelectedMembers" class="text-primary font-bold text-sm">
              Add ({{ selectedIds.size }})
            </button>
            <button @click="showPicker = false"><X :size="20" class="text-gray-400" /></button>
          </div>
        </div>
        <div class="p-4">
          <input v-model="searchQuery" @input="onSearch(searchQuery)" type="text" placeholder="Search by name or phone..."
            class="input-field" autofocus />
        </div>
        <div class="flex-1 overflow-y-auto px-4 pb-8">
          <p v-if="searching" class="text-center text-gray-400 text-sm py-8">Searching...</p>
          <p v-else-if="searchQuery.length < 2" class="text-center text-gray-400 text-sm py-8">Type to search</p>
          <p v-else-if="searchResults.length === 0" class="text-center text-gray-400 text-sm py-8">No users found</p>
          <div v-else v-for="u in searchResults" :key="u.id" @click="toggleSelect(u.id)"
            class="flex items-center gap-3 py-3 cursor-pointer">
            <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center shrink-0">
              <img v-if="u.avatar_url" :src="u.avatar_url" class="w-full h-full rounded-full object-cover" />
              <span v-else class="font-bold text-primary">{{ (u.name || '?')[0].toUpperCase() }}</span>
            </div>
            <div class="flex-1 min-w-0">
              <span class="font-semibold">{{ u.name }}</span>
              <p v-if="u.phone" class="text-xs text-gray-400">{{ u.phone }}</p>
            </div>
            <div class="w-5 h-5 rounded-full border-2 flex items-center justify-center"
              :class="selectedIds.has(u.id) ? 'bg-primary border-primary' : 'border-gray-300'">
              <svg v-if="selectedIds.has(u.id)" class="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
              </svg>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
