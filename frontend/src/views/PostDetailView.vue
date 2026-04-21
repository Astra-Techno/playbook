<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { ChevronLeft, Heart, Trash2, X, ChevronRight, MessageCircle, Share2, MoreHorizontal, Send, Loader2 } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const post    = ref(null)
const loading = ref(true)
const submittingComment = ref(false)
const newComment = ref('')

// Lightbox
const lightbox      = ref(false)
const lightboxIndex = ref(0)

const renderContent = (text) => {
    if (!text) return ''
    const escaped = text
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/\n/g, '<br>')
    return escaped
        .replace(/@(\w+)/g, '<span class="text-primary font-semibold">@$1</span>')
        .replace(/#(\w+)/g, '<span class="text-violet-600 font-semibold">#$1</span>')
}

const timeAgo = (dt) => {
    const diff = (Date.now() - new Date(dt)) / 1000
    if (diff < 60)    return 'just now'
    if (diff < 3600)  return Math.floor(diff / 60) + 'm ago'
    if (diff < 86400) return Math.floor(diff / 3600) + 'h ago'
    return Math.floor(diff / 86400) + 'd ago'
}
const initials = (name) => (name || '?').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()

const fetchPost = async () => {
    loading.value = true
    try {
        const uid = auth.user?.id ? `?user_id=${auth.user.id}` : ''
        const res = await axios.get(`/posts/${route.params.id}${uid}`)
        post.value = res.data
    } catch {
        toast.error('Post not found')
        router.back()
    } finally {
        loading.value = false
    }
}

const toggleLike = async () => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    const wasLiked = post.value.is_liked
    post.value.is_liked = !post.value.is_liked
    post.value.likes_count += wasLiked ? -1 : 1
    
    try {
        const res = await axios.post(`/posts/${post.value.id}/like`, { user_id: auth.user.id })
        post.value.is_liked    = res.data.liked
        post.value.likes_count = res.data.likes_count
    } catch {
        post.value.is_liked = wasLiked
        post.value.likes_count += wasLiked ? 1 : -1
    }
}

const showHeartPop = ref(false)
let lastTap = 0
const handleImageTap = () => {
    const now = Date.now()
    if (now - lastTap < 300) {
        if (!post.value.is_liked) toggleLike()
        showHeartPop.value = true
        setTimeout(() => showHeartPop.value = false, 800)
    }
    lastTap = now
}

const submitComment = async () => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    if (!newComment.value.trim() || submittingComment.value) return
    
    submittingComment.value = true
    try {
        const res = await axios.post(`/posts/${post.value.id}/comment`, {
            user_id: auth.user.id,
            content: newComment.value.trim()
        })
        post.value.comments.push(res.data)
        newComment.value = ''
        toast.success('Comment added')
    } catch {
        toast.error('Could not add comment')
    } finally {
        submittingComment.value = false
    }
}

const deletePost = async () => {
    if (!confirm('Delete this post?')) return
    try {
        await axios.delete(`/posts/${post.value.id}`, { data: { user_id: auth.user.id } })
        toast.success('Post deleted')
        router.back()
    } catch { toast.error('Could not delete') }
}

const openLightbox = (i) => { lightboxIndex.value = i; lightbox.value = true }
const closeLightbox = () => { lightbox.value = false }
const prevImage = () => { lightboxIndex.value = (lightboxIndex.value - 1 + post.value.images.length) % post.value.images.length }
const nextImage = () => { lightboxIndex.value = (lightboxIndex.value + 1) % post.value.images.length }

// Swipe support
let touchStartX = 0
const onTouchStart = (e) => { touchStartX = e.touches[0].clientX }
const onTouchEnd   = (e) => {
    const dx = e.changedTouches[0].clientX - touchStartX
    if (Math.abs(dx) > 50) dx < 0 ? nextImage() : prevImage()
}

onMounted(fetchPost)
</script>

<template>
    <div class="min-h-full bg-white">

        <!-- Dynamic Header Subject -->
        <Teleport v-if="post" to="#header-subject">
            {{ post.user_name }}
        </Teleport>

        <!-- Branded Header (Teleported Actions) -->
        <Teleport v-if="post && auth.user?.id === post.user_id" to="#header-action">
            <button @click="deletePost"
                class="w-9 h-9 rounded-full bg-red-50 flex items-center justify-center active:scale-90 transition-transform">
                <Trash2 :size="16" class="text-red-500" />
            </button>
        </Teleport>

        <!-- Loading -->
        <div v-if="loading" class="p-5 space-y-4 animate-pulse">
            <div class="flex gap-3">
                <div class="w-11 h-11 rounded-full bg-slate-200 shrink-0"></div>
                <div class="flex-1 space-y-2 pt-1">
                    <div class="h-3 bg-slate-200 rounded w-1/3"></div>
                    <div class="h-3 bg-slate-200 rounded w-1/4"></div>
                </div>
            </div>
            <div class="h-4 bg-slate-200 rounded w-full"></div>
            <div class="h-4 bg-slate-200 rounded w-3/4"></div>
            <div class="h-64 bg-slate-200 rounded-2xl w-full"></div>
        </div>

        <!-- Post -->
        <div v-else-if="post" class="pb-[calc(8rem+env(safe-area-inset-bottom,0px))]">

            <!-- Author row -->
            <div class="flex items-center justify-between gap-3 px-5 py-5">
                <div class="flex items-center gap-3">
                    <div class="w-12 h-12 rounded-full p-[2.5px] ring-2 ring-primary/20 bg-white shadow-sm">
                        <div class="w-full h-full rounded-full overflow-hidden bg-primary-light flex items-center justify-center">
                            <img v-if="post.avatar_url || (post.user_id === auth.user?.id && auth.user?.avatar_url)"
                                :src="post.avatar_url || auth.user?.avatar_url"
                                class="w-full h-full object-cover" />
                            <span v-else class="text-xs font-black text-primary">{{ initials(post.user_name) }}</span>
                        </div>
                    </div>
                    <div>
                        <p class="text-sm font-black text-slate-900 leading-none mb-1">{{ post.user_name }}</p>
                        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">{{ timeAgo(post.created_at) }}</p>
                    </div>
                </div>
                <button class="w-9 h-9 rounded-full flex items-center justify-center text-slate-300 hover:text-slate-900 transition-all">
                    <MoreHorizontal :size="20" />
                </button>
            </div>

            <!-- Content -->
            <p v-if="post.content?.trim()"
                class="px-5 text-base text-slate-800 leading-relaxed mb-5"
                v-html="renderContent(post.content)"></p>

            <!-- Images -->
            <div v-if="post.images?.length" class="relative bg-slate-50 mb-6" @click="handleImageTap">
                <!-- Single image -->
                <div v-if="post.images.length === 1" class="cursor-pointer" @click="openLightbox(0)">
                    <img :src="post.images[0]" class="w-full max-h-[520px] object-cover" loading="lazy" />
                </div>

                <!-- Multi-grid -->
                <div v-else class="grid grid-cols-2 gap-0.5">
                    <div v-for="(url, i) in post.images.slice(0, 4)" :key="i"
                        class="relative cursor-pointer overflow-hidden aspect-square" @click="openLightbox(i)">
                        <img :src="url" class="w-full h-full object-cover" loading="lazy" />
                        <div v-if="i === 3 && post.images.length > 4"
                            class="absolute inset-0 bg-black/60 flex items-center justify-center">
                            <span class="text-white text-2xl font-black">+{{ post.images.length - 4 }}</span>
                        </div>
                    </div>
                </div>

                <!-- Heart Pop interaction -->
                <Transition
                    enter-active-class="transition duration-400 ease-out"
                    enter-from-class="scale-0 opacity-0"
                    enter-to-class="scale-125 opacity-100"
                    leave-active-class="transition duration-400 ease-in"
                    leave-from-class="scale-125 opacity-100"
                    leave-to-class="scale-150 opacity-0">
                    <div v-if="showHeartPop" class="absolute inset-0 flex items-center justify-center z-10 pointer-events-none">
                        <Heart :size="100" class="text-white fill-white drop-shadow-2xl" />
                    </div>
                </Transition>
            </div>

            <!-- Engagement Bar -->
            <div class="px-5">
                <div class="flex items-center justify-between pb-5 border-b border-slate-50">
                    <div class="flex items-center gap-6">
                        <button @click="toggleLike"
                            class="flex items-center gap-2 text-xs font-bold transition-all active:scale-95 group"
                            :class="post.is_liked ? 'text-red-500' : 'text-slate-600 hover:text-red-500'">
                            <div class="w-10 h-10 rounded-full flex items-center justify-center transition-colors"
                                :class="post.is_liked ? 'bg-red-50' : 'group-hover:bg-red-50'">
                                <Heart :size="22"
                                    :class="post.is_liked ? 'fill-red-500 text-red-500' : ''"
                                    :stroke-width="post.is_liked ? 0 : 2.5" />
                            </div>
                            <span class="tabular-nums">{{ post.likes_count || 'Like' }}</span>
                        </button>
                        <button class="flex items-center gap-2 text-xs font-bold text-slate-600 hover:text-primary active:scale-95 group">
                            <div class="w-10 h-10 rounded-full flex items-center justify-center group-hover:bg-primary/5 transition-colors">
                                <MessageCircle :size="22" :stroke-width="2.5" />
                            </div>
                            <span>{{ post.comments?.length || 0 }}</span>
                        </button>
                        <button class="flex items-center gap-2 text-xs font-bold text-slate-600 hover:text-slate-900 active:scale-95 group">
                            <div class="w-10 h-10 rounded-full flex items-center justify-center group-hover:bg-slate-100 transition-colors">
                                <Share2 :size="20" :stroke-width="2.5" />
                            </div>
                        </button>
                    </div>
                    <!-- Tiny like stack -->
                    <div v-if="post.likes_count > 0" class="flex -space-x-2">
                        <div v-for="i in Math.min(post.likes_count, 1)" :key="i"
                            class="w-7 h-7 rounded-full border-2 border-white bg-primary flex items-center justify-center shadow-sm">
                            <Heart :size="12" class="text-white fill-white" />
                        </div>
                    </div>
                </div>

                <!-- Comments Section -->
                <div class="mt-8 space-y-6">
                    <h3 class="text-sm font-black text-slate-900 flex items-center gap-2">
                        Comments <span class="bg-slate-100 text-slate-500 px-2 py-0.5 rounded-full text-[10px]">{{ post.comments?.length || 0 }}</span>
                    </h3>
                    
                    <div v-if="!post.comments?.length" class="py-10 text-center">
                        <div class="text-3xl mb-3 opacity-30">💭</div>
                        <p class="text-xs font-bold text-slate-400">No comments yet. Be the first to reply!</p>
                    </div>
                    
                    <div v-else class="space-y-6">
                        <div v-for="c in post.comments" :key="c.id" class="flex gap-3">
                            <div class="w-8 h-8 rounded-full overflow-hidden bg-slate-100 shrink-0 shadow-sm border border-slate-50">
                                <img v-if="c.avatar_url" :src="c.avatar_url" class="w-full h-full object-cover" />
                                <div v-else class="w-full h-full flex items-center justify-center bg-primary-light text-[10px] font-black text-primary">
                                    {{ initials(c.user_name) }}
                                </div>
                            </div>
                            <div class="flex-1 min-w-0 bg-slate-50 rounded-[20px] rounded-tl-none px-4 py-3">
                                <div class="flex items-center justify-between gap-2 mb-1">
                                    <p class="text-xs font-black text-slate-900">{{ c.user_name }}</p>
                                    <p class="text-[9px] font-bold text-slate-400 uppercase tracking-wider">{{ timeAgo(c.created_at) }}</p>
                                </div>
                                <p class="text-sm text-slate-800 leading-relaxed">{{ c.content }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Sticky Comment Input — above app bottom nav (same offset as other fixed CTAs) -->
        <div v-if="post"
            class="fixed left-1/2 z-40 w-full max-w-[430px] -translate-x-1/2 border-t border-slate-100 bg-white/95 px-4 pb-3 pt-3 backdrop-blur-md bottom-[calc(4.5rem+env(safe-area-inset-bottom,0px))]"
            style="box-shadow: 0 -4px 20px rgba(0,0,0,0.06)">
            <div class="flex items-center gap-3 pb-[max(0.25rem,env(safe-area-inset-bottom,0px))]">
                <div class="w-9 h-9 rounded-full overflow-hidden bg-primary-light flex items-center justify-center shrink-0 ring-4 ring-primary/5 shadow-sm">
                    <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                    <span v-else class="text-[10px] font-black text-primary">{{ initials(auth.user?.name) }}</span>
                </div>
                <div class="flex-1 relative">
                    <input
                        v-model="newComment"
                        @keyup.enter="submitComment"
                        placeholder="Add a comment..."
                        class="w-full bg-slate-50 border-none rounded-full px-5 py-2.5 text-sm font-bold text-slate-900 placeholder:text-slate-300 focus:ring-2 focus:ring-primary/10 transition-all"
                    />
                    <button
                        @click="submitComment"
                        :disabled="!newComment.trim() || submittingComment"
                        class="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-primary text-white flex items-center justify-center active:scale-90 transition-transform disabled:opacity-30 disabled:scale-100">
                        <Loader2 v-if="submittingComment" :size="14" class="animate-spin" />
                        <Send v-else :size="14" />
                    </button>
                </div>
            </div>
        </div>

        <!-- ── Lightbox ── -->
        <Teleport to="body">
            <Transition
                enter-active-class="transition duration-200 ease-out"
                enter-from-class="opacity-0"
                enter-to-class="opacity-100"
                leave-active-class="transition duration-150 ease-in"
                leave-from-class="opacity-100"
                leave-to-class="opacity-0">
                <div v-if="lightbox"
                    class="fixed inset-0 z-[9999] bg-black flex flex-col"
                    @touchstart="onTouchStart"
                    @touchend="onTouchEnd">

                    <!-- Top bar -->
                    <div class="flex items-center justify-between px-4 pt-12 pb-3 shrink-0">
                        <button @click="closeLightbox"
                            class="w-9 h-9 rounded-full bg-white/10 flex items-center justify-center">
                            <X :size="20" class="text-white" />
                        </button>
                        <span v-if="post.images.length > 1" class="text-white/70 text-sm font-semibold">
                            {{ lightboxIndex + 1 }} / {{ post.images.length }}
                        </span>
                        <div class="w-9"></div>
                    </div>

                    <!-- Image -->
                    <div class="flex-1 flex items-center justify-center px-2 min-h-0">
                        <img :src="post.images[lightboxIndex]"
                            class="max-w-full max-h-full object-contain rounded-lg select-none"
                            draggable="false" />
                    </div>

                    <!-- Prev / Next arrows -->
                    <template v-if="post.images.length > 1">
                        <button @click="prevImage"
                            class="absolute left-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/10 flex items-center justify-center active:scale-90">
                            <ChevronLeft :size="22" class="text-white" />
                        </button>
                        <button @click="nextImage"
                            class="absolute right-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/10 flex items-center justify-center active:scale-90">
                            <ChevronRight :size="22" class="text-white" />
                        </button>
                    </template>

                    <!-- Dot indicators -->
                    <div v-if="post.images.length > 1" class="flex justify-center gap-1.5 pb-10 shrink-0">
                        <div v-for="(_, i) in post.images" :key="i"
                            class="w-1.5 h-1.5 rounded-full transition-all"
                            :class="i === lightboxIndex ? 'bg-white w-4' : 'bg-white/30'">
                        </div>
                    </div>
                </div>
            </Transition>
        </Teleport>

    </div>
</template>
