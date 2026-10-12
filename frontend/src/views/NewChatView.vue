<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import { ChevronLeft, Search } from 'lucide-vue-next'

const router  = useRouter()
const toast   = useToastStore()

const searchQuery   = ref('')
const results       = ref([])
const selected      = ref(new Set())
const searching     = ref(false)
const creating      = ref(false)
const isGroup       = ref(false)
const groupName     = ref('')

let debounce = null
const onSearch = (q) => {
    clearTimeout(debounce)
    if (q.length < 2) { results.value = []; return }
    searching.value = true
    debounce = setTimeout(async () => {
        try {
            const res = await axios.get('/chat/users/search', { params: { q } })
            results.value = res.data.users || []
        } catch { /* ignore */ }
        searching.value = false
    }, 400)
}

const toggle = (id) => {
    const s = new Set(selected.value)
    s.has(id) ? s.delete(id) : s.add(id)
    selected.value = s
    if (s.size > 1) isGroup.value = true
}

const create = async () => {
    if (selected.value.size === 0) return
    creating.value = true

    const ids = [...selected.value]

    // DM
    if (!isGroup.value && ids.length === 1) {
        try {
            const res = await axios.post('/chat/groups', { type: 'dm', member_ids: ids })
            router.replace(`/chats/${res.data.group_id}`)
        } catch { toast.error('Failed to create chat'); creating.value = false }
        return
    }

    // Group
    if (!groupName.value.trim()) {
        toast.error('Enter a group name')
        creating.value = false
        return
    }
    try {
        const res = await axios.post('/chat/groups', { type: 'group', name: groupName.value.trim(), member_ids: ids })
        router.replace(`/chats/${res.data.group_id}`)
    } catch { toast.error('Failed to create group'); creating.value = false }
}
</script>

<template>
  <div class="min-h-screen bg-white">
    <!-- Header -->
    <div class="sticky top-0 z-10 bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
      <button @click="router.back()" class="text-gray-600"><ChevronLeft :size="24" /></button>
      <p class="font-bold flex-1">{{ isGroup ? 'New Group' : 'New Chat' }}</p>
      <button v-if="selected.size > 0" @click="create" :disabled="creating"
        class="text-primary font-bold text-sm disabled:opacity-50">
        {{ creating ? '...' : (isGroup ? 'Create' : 'Chat') }}
      </button>
    </div>

    <div class="page-gutter">
      <!-- Group name -->
      <div v-if="isGroup" class="mb-3 mt-2">
        <input v-model="groupName" type="text" placeholder="Group name" class="input-field" />
      </div>

      <!-- Selected chips -->
      <div v-if="selected.size > 0" class="flex flex-wrap gap-2 mb-3">
        <span v-for="id in selected" :key="id"
          @click="toggle(id)"
          class="bg-primary/10 text-primary text-sm font-semibold px-3 py-1 rounded-full cursor-pointer">
          {{ (results.find(u => u.id === id))?.name || 'User' }} ×
        </span>
      </div>

      <!-- Search -->
      <div class="relative mb-4">
        <Search :size="16" class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input v-model="searchQuery" @input="onSearch(searchQuery)" type="text"
          placeholder="Search by name or phone..." class="input-field !pl-10" autofocus />
      </div>

      <!-- Group checkbox -->
      <label v-if="selected.size <= 1" class="flex items-center gap-2 mb-4 cursor-pointer text-sm">
        <input type="checkbox" v-model="isGroup" class="accent-primary" />
        Create group chat
      </label>

      <!-- Results -->
      <p v-if="searching" class="text-center text-gray-400 text-sm py-8">Searching...</p>
      <p v-else-if="searchQuery.length < 2" class="text-center text-gray-400 text-sm py-8">Type to search users</p>
      <p v-else-if="results.length === 0" class="text-center text-gray-400 text-sm py-8">No users found</p>
      <div v-else class="space-y-1">
        <div v-for="u in results" :key="u.id" @click="toggle(u.id)"
          class="flex items-center gap-3 py-3 cursor-pointer rounded-xl hover:bg-gray-50 px-2">
          <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center shrink-0 overflow-hidden">
            <img v-if="u.avatar_url" :src="u.avatar_url" class="w-full h-full object-cover" />
            <span v-else class="font-bold text-primary">{{ (u.name || '?')[0].toUpperCase() }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <span class="font-semibold">{{ u.name }}</span>
            <p v-if="u.phone" class="text-xs text-gray-400">{{ u.phone }}</p>
          </div>
          <div class="w-5 h-5 rounded-full border-2 flex items-center justify-center"
            :class="selected.has(u.id) ? 'bg-primary border-primary' : 'border-gray-300'">
            <svg v-if="selected.has(u.id)" class="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
            </svg>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
