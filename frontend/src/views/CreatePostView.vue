<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    ImagePlus, X, Loader2, Send, Globe, Lock, Users, AtSign, MapPin
} from 'lucide-vue-next'

const router = useRouter()
const route  = useRoute()
const auth   = useAuthStore()
const toast  = useToastStore()

// Booking context from query params
const bookingId  = route.query.booking_id  ? parseInt(route.query.booking_id)  : null
const courtId    = route.query.court_id    ? parseInt(route.query.court_id)    : null
const courtName  = route.query.court_name  ? decodeURIComponent(route.query.court_name) : null

// Form state
const postText       = ref('')
const visibility     = ref('public')
const submitting     = ref(false)
const selectedFiles  = ref([])
const imagePreviews  = ref([])
const uploadingImages = ref(false)
const MAX_IMAGES = 4

// Mention / tag state
const textareaRef     = ref(null)
const triggerChar     = ref(null)
const mentionQuery    = ref('')
const suggestions     = ref([])
const mentionLoading  = ref(false)
const showSuggestions = ref(false)
const postTags        = ref([])

let mentionDebounce = null

const visibilityOptions = [
    { value: 'public',   label: 'Public',   desc: 'Everyone can see this',         icon: Globe,  cls: 'text-primary' },
    { value: 'only_me',  label: 'Only Me',  desc: 'Only you can see this',         icon: Lock,   cls: 'text-slate-500' },
    { value: 'tagged',   label: 'Tagged',   desc: 'You and tagged people can see', icon: Users,  cls: 'text-violet-500' },
]

const initials = (name) => (name || '?').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()

// ── Mention logic ────────────────────────────────────────────────────────────

const handleTextInput = (e) => {
    postText.value = e.target.value
    const val = e.target.value
    const cur = e.target.selectionStart
    let triggerPos = -1
    let tc = null
    for (let i = cur - 1; i >= 0; i--) {
        if (val[i] === '@' || val[i] === '#') {
            if (i === 0 || /\s/.test(val[i - 1])) { triggerPos = i; tc = val[i] }
            break
        }
        if (/\s/.test(val[i])) break
    }
    if (tc && triggerPos >= 0) {
        triggerChar.value     = tc
        mentionQuery.value    = val.slice(triggerPos + 1, cur)
        showSuggestions.value = true
        clearTimeout(mentionDebounce)
        if (mentionQuery.value.length >= 1) {
            mentionDebounce = setTimeout(searchMentions, 280)
        } else {
            suggestions.value = []
        }
    } else {
        dismissMentions()
    }
}

const searchMentions = async () => {
    if (!mentionQuery.value) return
    mentionLoading.value = true
    try {
        const type = triggerChar.value === '@' ? 'users' : 'courts'
        const res = await axios.get(`/tag-search?q=${encodeURIComponent(mentionQuery.value)}&type=${type}`)
        suggestions.value = res.data.results || []
    } catch { suggestions.value = [] }
    finally { mentionLoading.value = false }
}

const selectMention = (item) => {
    const val = postText.value
    const el  = textareaRef.value
    const cur = el ? el.selectionStart : val.length
    let triggerPos = cur - 1
    while (triggerPos >= 0 && val[triggerPos] !== '@' && val[triggerPos] !== '#') triggerPos--
    if (triggerPos < 0) { dismissMentions(); return }
    const slug  = item.name.replace(/\s+/g, '_')
    const label = (item.kind === 'user' ? '@' : '#') + slug
    postText.value = val.slice(0, triggerPos) + label + ' ' + val.slice(cur)
    if (!postTags.value.find(t => t.kind === item.kind && t.id === item.id)) {
        postTags.value.push({ kind: item.kind, id: item.id, name: item.name })
    }
    dismissMentions()
    nextTick(() => {
        if (el) {
            el.selectionStart = el.selectionEnd = triggerPos + label.length + 1
            el.focus()
        }
    })
}

const insertTrigger = (char) => {
    const space = postText.value && !postText.value.endsWith(' ') ? ' ' : ''
    postText.value += space + char
    showSuggestions.value = true
    triggerChar.value = char
    mentionQuery.value = ''
    suggestions.value = []
    nextTick(() => textareaRef.value?.focus())
}

const dismissMentions = () => {
    showSuggestions.value = false
    triggerChar.value     = null
    mentionQuery.value    = ''
    suggestions.value     = []
}

// ── Image handling ────────────────────────────────────────────────────────────

const handleImageSelect = (e) => {
    const files = Array.from(e.target.files || [])
    const remaining = MAX_IMAGES - selectedFiles.value.length
    const toAdd = files.slice(0, remaining)
    toAdd.forEach(file => {
        selectedFiles.value.push(file)
        const reader = new FileReader()
        reader.onload = (ev) => imagePreviews.value.push(ev.target.result)
        reader.readAsDataURL(file)
    })
    e.target.value = ''
    if (files.length > remaining) toast.error(`Max ${MAX_IMAGES} images allowed`)
}

const removeImage = (i) => {
    selectedFiles.value.splice(i, 1)
    imagePreviews.value.splice(i, 1)
}

// ── Submit ────────────────────────────────────────────────────────────────────

const canSubmit = computed(() => postText.value.trim() || selectedFiles.value.length > 0)

const submitPost = async () => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    if (!canSubmit.value) return
    submitting.value = true
    try {
        let imageUrls = []
        if (selectedFiles.value.length > 0) {
            uploadingImages.value = true
            const uploads = selectedFiles.value.map(file => {
                const fd = new FormData()
                fd.append('image', file)
                return axios.post('/upload', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
            })
            const results = await Promise.all(uploads)
            imageUrls = results.map(r => r.data.url)
            uploadingImages.value = false
        }

        await axios.post('/posts', {
            user_id:    auth.user.id,
            content:    postText.value.trim() || ' ',
            images:     imageUrls,
            court_id:   courtId  || undefined,
            booking_id: bookingId || undefined,
            visibility: visibility.value,
            tags:       postTags.value,
        })

        toast.success('Posted to community!')
        router.push('/feed')
    } catch {
        toast.error('Could not post')
        uploadingImages.value = false
    } finally {
        submitting.value = false
    }
}

onMounted(() => {
    if (!auth.isLoggedIn) router.push('/login')
})
</script>

<template>
    <div class="min-h-full bg-slate-50">

        <!-- Booking context badge -->
        <div v-if="courtName" class="px-4 pt-4">
            <div class="bg-primary/5 border border-primary/15 rounded-2xl px-4 py-3 flex items-center gap-3">
                <div class="w-8 h-8 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                    <MapPin :size="16" class="text-primary" />
                </div>
                <div class="flex-1 min-w-0">
                    <p class="text-xs font-black text-primary leading-none">Sharing about</p>
                    <p class="text-sm font-bold text-slate-800 truncate mt-0.5">{{ courtName }}</p>
                </div>
            </div>
        </div>

        <!-- Compose area -->
        <div class="px-4 pt-4">
            <div class="bg-white rounded-3xl shadow-soft ring-1 ring-slate-100 overflow-visible p-4">
                <div class="flex gap-3 items-start">
                    <!-- Avatar -->
                    <div class="w-10 h-10 rounded-full overflow-hidden bg-primary-light flex items-center justify-center shrink-0 ring-2 ring-primary/20">
                        <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                        <span v-else class="text-xs font-extrabold text-primary">{{ initials(auth.user?.name) }}</span>
                    </div>
                    <div class="flex-1 min-w-0 relative">
                        <p class="text-sm font-black text-slate-800 leading-none mb-0.5">{{ auth.user?.name }}</p>
                        <textarea
                            ref="textareaRef"
                            :value="postText"
                            @input="handleTextInput"
                            @keydown.escape="dismissMentions"
                            placeholder="How was your game? Share with the community…"
                            rows="4"
                            class="w-full text-sm bg-transparent border-none focus:ring-0 resize-none placeholder:text-slate-300 text-slate-900 mt-2"
                        />

                        <!-- Mention suggestions dropdown -->
                        <div v-if="showSuggestions"
                            class="absolute left-0 right-0 bottom-full mb-2 bg-white rounded-2xl shadow-xl ring-1 ring-slate-200 z-30 overflow-hidden max-h-52 overflow-y-auto">
                            <div v-if="mentionLoading" class="flex items-center gap-2 px-4 py-3 text-xs text-slate-400">
                                <Loader2 :size="12" class="animate-spin" /> Searching…
                            </div>
                            <div v-else-if="suggestions.length === 0 && mentionQuery.length >= 1"
                                class="px-4 py-3 text-xs text-slate-400">No results</div>
                            <button v-for="item in suggestions" :key="item.kind + item.id"
                                @mousedown.prevent="selectMention(item)"
                                class="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-slate-50 transition-colors text-left border-b border-slate-50 last:border-0">
                                <div class="w-9 h-9 rounded-full overflow-hidden shrink-0 bg-primary-light flex items-center justify-center">
                                    <img v-if="item.avatar_url || item.image_url" :src="item.avatar_url || item.image_url" class="w-full h-full object-cover" />
                                    <span v-else class="text-xs font-extrabold text-primary">
                                        {{ item.kind === 'user' ? item.name[0].toUpperCase() : '🏟' }}
                                    </span>
                                </div>
                                <div class="flex-1 min-w-0">
                                    <p class="text-sm font-bold text-slate-900 truncate">
                                        <span class="text-primary">{{ triggerChar }}</span>{{ item.name }}
                                    </p>
                                    <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                                        {{ item.kind === 'user' ? 'Player' : item.subtype }}
                                    </p>
                                </div>
                            </button>
                        </div>

                        <!-- Image previews -->
                        <div v-if="imagePreviews.length" class="mt-3 grid gap-2"
                            :class="imagePreviews.length === 1 ? 'grid-cols-1' : 'grid-cols-2'">
                            <div v-for="(src, i) in imagePreviews" :key="i"
                                class="relative rounded-2xl overflow-hidden shadow-sm">
                                <img :src="src" class="w-full object-cover" :class="imagePreviews.length === 1 ? 'max-h-64' : 'h-32'" />
                                <button @click="removeImage(i)"
                                    class="absolute top-2 right-2 w-7 h-7 bg-black/40 backdrop-blur-md rounded-full flex items-center justify-center text-white active:scale-90 transition-transform">
                                    <X :size="14" />
                                </button>
                            </div>
                        </div>

                        <div v-if="uploadingImages" class="flex items-center gap-2 mt-2 text-[10px] font-bold text-primary uppercase tracking-wider">
                            <Loader2 :size="12" class="animate-spin" />
                            Uploading images…
                        </div>
                    </div>
                </div>

                <!-- Tag chips -->
                <div v-if="postTags.length" class="flex flex-wrap gap-1.5 mt-3 pl-13">
                    <span v-for="(tag, i) in postTags" :key="i"
                        class="inline-flex items-center gap-1 text-[10px] font-bold px-3 py-1.5 rounded-full ring-1 ring-slate-100"
                        :class="tag.kind === 'user' ? 'bg-primary/5 text-primary' : 'bg-violet-50 text-violet-600'">
                        {{ tag.kind === 'user' ? '@' : '#' }}{{ tag.name }}
                        <button @click="postTags.splice(i, 1)" class="ml-1 opacity-40 hover:opacity-100"><X :size="10" /></button>
                    </span>
                </div>

                <!-- Bottom toolbar -->
                <div class="flex items-center gap-2 mt-4 pt-3 border-t border-slate-50">
                    <label class="cursor-pointer flex items-center gap-1.5 text-[11px] font-bold text-slate-500 hover:text-primary px-3 py-2 rounded-xl hover:bg-primary/5 transition-all active:scale-95"
                        :class="selectedFiles.length >= MAX_IMAGES ? 'opacity-30 pointer-events-none' : ''">
                        <ImagePlus :size="16" class="text-primary" />
                        <span>Photo</span>
                        <span v-if="selectedFiles.length" class="inline-flex items-center justify-center bg-primary text-white text-[9px] font-extrabold w-4 h-4 rounded-full">
                            {{ selectedFiles.length }}
                        </span>
                        <input type="file" accept="image/*" multiple class="hidden" @change="handleImageSelect" />
                    </label>
                    <button @click="insertTrigger('@')"
                        class="flex items-center gap-1.5 text-[11px] font-bold text-slate-500 hover:text-violet-600 px-3 py-2 rounded-xl hover:bg-violet-50 transition-all active:scale-95">
                        <AtSign :size="16" class="text-violet-500" />
                        <span>Tag</span>
                    </button>
                </div>
            </div>
        </div>

        <!-- Visibility selector -->
        <div class="px-4 mt-4">
            <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2 px-1">Who can see this?</p>
            <div class="bg-white rounded-2xl ring-1 ring-slate-100 overflow-hidden shadow-soft">
                <button v-for="opt in visibilityOptions" :key="opt.value"
                    @click="visibility = opt.value"
                    class="w-full flex items-center gap-3 px-4 py-3.5 transition-colors border-b border-slate-50 last:border-0"
                    :class="visibility === opt.value ? 'bg-primary/3' : 'hover:bg-slate-50'">
                    <div class="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                        :class="visibility === opt.value ? 'bg-primary/10' : 'bg-slate-100'">
                        <component :is="opt.icon" :size="18" :class="visibility === opt.value ? opt.cls : 'text-slate-400'" />
                    </div>
                    <div class="flex-1 text-left">
                        <p class="text-sm font-bold" :class="visibility === opt.value ? 'text-slate-900' : 'text-slate-600'">{{ opt.label }}</p>
                        <p class="text-[11px] text-slate-400">{{ opt.desc }}</p>
                    </div>
                    <div v-if="visibility === opt.value"
                        class="w-5 h-5 rounded-full bg-primary flex items-center justify-center shrink-0">
                        <svg :size="10" viewBox="0 0 12 12" fill="none" class="w-3 h-3">
                            <path d="M2 6l3 3 5-5" stroke="white" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </div>
                </button>
            </div>
        </div>

        <!-- Submit button -->
        <div class="fixed bottom-[72px] left-1/2 -translate-x-1/2 w-full max-w-[430px] px-4 z-30">
            <button
                @click="submitPost"
                :disabled="!canSubmit || submitting"
                class="w-full h-14 rounded-2xl bg-primary text-white font-black text-base shadow-xl active:scale-[0.97] disabled:opacity-40 transition-all flex items-center justify-center gap-3">
                <Loader2 v-if="submitting" :size="20" class="animate-spin" />
                <template v-else>
                    <Send :size="18" />
                    Post to Community
                </template>
            </button>
        </div>
    </div>
</template>
