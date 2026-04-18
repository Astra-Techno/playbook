<script setup>
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import { useRouter } from 'vue-router'
import { Heart, Send, Trash2, X, Loader2, ChevronLeft, ChevronRight, AtSign, MessageCircle, Share2, MoreHorizontal } from 'lucide-vue-next'

const auth   = useAuthStore()
const toast  = useToastStore()
const router = useRouter()

const posts          = ref([])
const stories        = ref([])
const loading        = ref(true)
const storiesLoading = ref(true)
const likeLoading    = ref(new Set())

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

const fetchStories = async () => {
    storiesLoading.value = true
    try {
        const res = await axios.get('/courts?featured=1')
        stories.value = res.data.records || res.data // Fallback to records
    } catch { stories.value = [] }
    finally { storiesLoading.value = false }
}

const fetchPosts = async () => {
    loading.value = true
    try {
        const uid = auth.user?.id ? `?user_id=${auth.user.id}` : ''
        const res = await axios.get(`/posts${uid}`)
        posts.value = res.data.records || []
    } catch { posts.value = [] }
    finally   { loading.value = false }
}

const toggleLike = async (post) => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    if (likeLoading.value.has(post.id)) return
    
    // Optimistic UI update
    const wasLiked = post.is_liked
    post.is_liked = !post.is_liked
    post.likes_count += wasLiked ? -1 : 1
    
    const s = new Set(likeLoading.value); s.add(post.id); likeLoading.value = s
    try {
        const res = await axios.post(`/posts/${post.id}/like`, { user_id: auth.user.id })
        post.is_liked    = res.data.liked
        post.likes_count = res.data.likes_count
    } catch { 
        // Revert on error
        post.is_liked = wasLiked
        post.likes_count += wasLiked ? 1 : -1
    }
    finally { const s2 = new Set(likeLoading.value); s2.delete(post.id); likeLoading.value = s2 }
}

const showHeartPop = ref(new Set())
let lastTap = 0
const handleImageTap = (post) => {
    const now = Date.now()
    const TIMESPAN = 300
    if (now - lastTap < TIMESPAN) {
        // Double tap
        if (!post.is_liked) {
            toggleLike(post)
        }
        // Show animation
        const s = new Set(showHeartPop.value); s.add(post.id); showHeartPop.value = s
        setTimeout(() => {
            const s2 = new Set(showHeartPop.value); s2.delete(post.id); showHeartPop.value = s2
        }, 800)
    }
    lastTap = now
}

const deletePost = async (post) => {
    if (!confirm('Delete this post?')) return
    try {
        await axios.delete(`/posts/${post.id}`, { data: { user_id: auth.user.id } })
        posts.value = posts.value.filter(p => p.id !== post.id)
        toast.success('Post deleted')
    } catch { toast.error('Could not delete') }
}

// Lightbox
const lightbox      = ref(false)
const lightboxImages = ref([])
const lightboxIndex = ref(0)

const openLightbox = (images, i) => { lightboxImages.value = images; lightboxIndex.value = i; lightbox.value = true }
const closeLightbox = () => { lightbox.value = false }
const prevImage = () => { lightboxIndex.value = (lightboxIndex.value - 1 + lightboxImages.value.length) % lightboxImages.value.length }
const nextImage = () => { lightboxIndex.value = (lightboxIndex.value + 1) % lightboxImages.value.length }

let touchStartX = 0
const onTouchStart = (e) => { touchStartX = e.touches[0].clientX }
const onTouchEnd   = (e) => {
    const dx = e.changedTouches[0].clientX - touchStartX
    if (Math.abs(dx) > 50) dx < 0 ? nextImage() : prevImage()
}

onMounted(() => {
    fetchPosts()
    fetchStories()
})
</script>

<template>
    <div class="min-h-full bg-slate-50">

        <!-- Stories Row -->
        <div class="bg-white border-b border-slate-100 overflow-hidden shadow-soft">
            <div class="flex gap-4 px-5 py-4 overflow-x-auto scrollbar-hide">
                <!-- User's own story "Plus" -->
                <div class="flex flex-col items-center gap-1.5 shrink-0">
                    <div class="w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center border-2 border-dashed border-slate-300 relative group">
                        <div class="w-13 h-13 rounded-full overflow-hidden bg-primary-light flex items-center justify-center">
                            <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover opacity-60" />
                            <span v-else class="text-xs font-bold text-primary opacity-60">{{ initials(auth.user?.name) }}</span>
                        </div>
                        <div class="absolute bottom-0 right-0 w-6 h-6 bg-primary rounded-full flex items-center justify-center border-2 border-white ring-2 ring-primary/5 shadow-sm group-active:scale-90 transition-transform">
                            <AtSign :size="12" class="text-white" />
                        </div>
                    </div>
                    <span class="text-[10px] font-bold text-slate-400">My Story</span>
                </div>

                <!-- Trending Stories -->
                <template v-if="storiesLoading">
                    <div v-for="i in 5" :key="i" class="flex flex-col items-center gap-1.5 shrink-0 animate-pulse">
                        <div class="w-16 h-16 rounded-full bg-slate-100"></div>
                        <div class="h-2 bg-slate-100 rounded w-10"></div>
                    </div>
                </template>
                <div v-for="item in stories" :key="item.id" 
                    @click="router.push(`/court/${item.id}`)"
                    class="flex flex-col items-center gap-1.5 shrink-0 cursor-pointer active:scale-95 transition-transform">
                    <div class="w-16 h-16 rounded-full p-[3px] ring-2 ring-primary shadow-sm">
                        <div class="w-full h-full rounded-full overflow-hidden bg-slate-200">
                            <img :src="item.image_url" class="w-full h-full object-cover" />
                        </div>
                    </div>
                    <span class="text-[10px] font-bold text-slate-900 truncate max-w-[64px]">{{ item.name }}</span>
                </div>
            </div>
        </div>

        <!-- Post CTA -->
        <div v-if="auth.isLoggedIn" class="px-4 py-3">
            <button @click="router.push('/post/create')"
                class="w-full bg-white rounded-2xl shadow-soft ring-1 ring-slate-100 px-4 py-3 flex items-center gap-3 active:scale-[0.98] transition-transform">
                <div class="w-9 h-9 rounded-full overflow-hidden bg-primary-light flex items-center justify-center shrink-0">
                    <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                    <span v-else class="text-xs font-extrabold text-primary">{{ initials(auth.user?.name) }}</span>
                </div>
                <span class="flex-1 text-sm text-slate-300 font-bold text-left">Share your match experience…</span>
                <div class="w-8 h-8 rounded-full bg-primary flex items-center justify-center shrink-0">
                    <Send :size="14" class="text-white" />
                </div>
            </button>
        </div>

        <!-- Feed -->
        <div class="pb-4">
            <div v-if="loading" class="space-y-3 p-4">
                <div v-for="i in 4" :key="i" class="bg-white rounded-2xl p-4 animate-pulse">
                    <div class="flex gap-3">
                        <div class="w-9 h-9 bg-slate-200 rounded-full shrink-0"></div>
                        <div class="flex-1 space-y-2">
                            <div class="h-3 bg-slate-200 rounded w-1/3"></div>
                            <div class="h-3 bg-slate-200 rounded w-full"></div>
                            <div class="h-24 bg-slate-200 rounded-xl w-full mt-2"></div>
                        </div>
                    </div>
                </div>
            </div>

            <div v-else-if="posts.length === 0" class="text-center py-20 px-8">
                <div class="text-5xl mb-4">🏆</div>
                <p class="font-bold text-slate-700 text-base">No posts yet</p>
                <p class="text-sm text-slate-400 mt-1">Be the first to share something with the community!</p>
            </div>

            <div v-else class="space-y-4">
                <div v-for="post in posts" :key="post.id" class="bg-white px-5 py-5 ring-1 ring-slate-100 shadow-sm">
                    <!-- Post Header -->
                    <div class="flex items-center justify-between gap-3 mb-4">
                        <div class="flex items-center gap-3 cursor-pointer" @click="router.push(`/feed/${post.id}`)">
                            <div class="w-11 h-11 rounded-full p-[2px] ring-2 ring-primary/20 bg-white">
                                <div class="w-full h-full rounded-full overflow-hidden bg-primary-light flex items-center justify-center">
                                    <img v-if="post.avatar_url || (post.user_id === auth.user?.id && auth.user?.avatar_url)"
                                        :src="post.avatar_url || auth.user?.avatar_url"
                                        class="w-full h-full object-cover" />
                                    <span v-else class="text-[10px] font-extrabold text-primary">{{ initials(post.user_name) }}</span>
                                </div>
                            </div>
                            <div class="min-w-0">
                                <p class="text-sm font-bold text-slate-900 leading-none mb-1">{{ post.user_name }}</p>
                                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">{{ timeAgo(post.created_at) }}</p>
                            </div>
                        </div>
                        <div class="flex items-center gap-2">
                            <button v-if="auth.user?.id === post.user_id"
                                @click="deletePost(post)"
                                class="w-8 h-8 rounded-full flex items-center justify-center text-slate-300 hover:text-red-500 hover:bg-red-50 transition-all active:scale-90">
                                <Trash2 :size="15" />
                            </button>
                            <button class="w-8 h-8 rounded-full flex items-center justify-center text-slate-300 hover:text-slate-900 hover:bg-slate-50 transition-all">
                                <MoreHorizontal :size="18" />
                            </button>
                        </div>
                    </div>

                    <!-- Post Content -->
                    <p v-if="post.content?.trim()"
                        class="text-sm text-slate-800 mb-4 leading-relaxed cursor-pointer"
                        v-html="renderContent(post.content)"
                        @click="router.push(`/feed/${post.id}`)"></p>

                    <!-- Image Media with Double Tap -->
                    <div v-if="post.images?.length" class="relative rounded-[24px] overflow-hidden bg-slate-100 mb-4" @click="handleImageTap(post)">
                        <!-- 1 image -->
                        <div v-if="post.images.length === 1"
                            class="cursor-pointer"
                            @click="openLightbox(post.images, 0)">
                            <img :src="post.images[0]" class="w-full max-h-[480px] object-cover" loading="lazy" />
                        </div>
                        <!-- 2 images -->
                        <div v-else-if="post.images.length === 2" class="grid grid-cols-2 gap-1">
                            <div v-for="(url, i) in post.images" :key="i"
                                class="cursor-pointer"
                                @click="openLightbox(post.images, i)">
                                <img :src="url" class="w-full h-64 object-cover" loading="lazy" />
                            </div>
                        </div>
                        <!-- 3+ images -->
                        <div v-else class="grid grid-cols-2 gap-1">
                            <div class="cursor-pointer" :class="post.images.length === 3 ? 'row-span-2 h-72' : 'h-36'"
                                @click="openLightbox(post.images, 0)">
                                <img :src="post.images[0]" class="w-full h-full object-cover" loading="lazy" />
                            </div>
                            <div v-for="(url, i) in post.images.slice(1, 4)" :key="i"
                                class="relative cursor-pointer" :class="post.images.length === 3 ? 'h-[142px]' : 'h-36'"
                                @click="openLightbox(post.images, i + 1)">
                                <img :src="url" class="w-full h-full object-cover" loading="lazy" />
                                <div v-if="i === 2 && post.images.length > 4"
                                    class="absolute inset-0 bg-black/55 flex items-center justify-center">
                                    <span class="text-white text-xl font-extrabold">+{{ post.images.length - 4 }}</span>
                                </div>
                            </div>
                        </div>

                        <!-- Heart Pop Interaction -->
                        <Transition
                            enter-active-class="transition duration-400 ease-out"
                            enter-from-class="scale-0 opacity-0"
                            enter-to-class="scale-125 opacity-100"
                            leave-active-class="transition duration-400 ease-in"
                            leave-from-class="scale-125 opacity-100"
                            leave-to-class="scale-150 opacity-0">
                            <div v-if="showHeartPop.has(post.id)" 
                                class="absolute inset-0 flex items-center justify-center z-10 pointer-events-none">
                                <Heart :size="80" class="text-white fill-white drop-shadow-2xl" />
                            </div>
                        </Transition>
                    </div>

                    <!-- Social Actions -->
                    <div class="flex items-center justify-between border-t border-slate-50 pt-4">
                        <div class="flex items-center gap-6">
                            <button @click="toggleLike(post)"
                                class="flex items-center gap-2 text-xs font-bold transition-all active:scale-95 group"
                                :class="post.is_liked ? 'text-red-500' : 'text-slate-600 hover:text-red-500'">
                                <div class="w-9 h-9 rounded-full flex items-center justify-center transition-colors"
                                    :class="post.is_liked ? 'bg-red-50' : 'group-hover:bg-red-50'">
                                    <Heart :size="20"
                                        :class="post.is_liked ? 'fill-red-500 text-red-500' : ''"
                                        :stroke-width="post.is_liked ? 0 : 2.5" />
                                </div>
                                <span class="tabular-nums">{{ post.likes_count || 'Like' }}</span>
                            </button>
                            <button @click="router.push(`/feed/${post.id}`)"
                                class="flex items-center gap-2 text-xs font-bold text-slate-600 hover:text-primary active:scale-95 group">
                                <div class="w-9 h-9 rounded-full flex items-center justify-center group-hover:bg-primary/5 transition-colors">
                                    <MessageCircle :size="20" :stroke-width="2.5" />
                                </div>
                                <span>Comment</span>
                            </button>
                            <button class="flex items-center gap-2 text-xs font-bold text-slate-600 hover:text-slate-900 active:scale-95 group">
                                <div class="w-9 h-9 rounded-full flex items-center justify-center group-hover:bg-slate-100 transition-colors">
                                    <Share2 :size="18" :stroke-width="2.5" />
                                </div>
                                <span class="hidden sm:inline">Share</span>
                            </button>
                        </div>

                        <!-- Tiny summary -->
                        <div v-if="post.likes_count > 0" class="flex -space-x-2">
                             <div class="w-6 h-6 rounded-full border-2 border-white bg-primary flex items-center justify-center shadow-sm">
                                 <Heart :size="10" class="text-white fill-white" />
                             </div>
                        </div>
                    </div>
                </div>
            </div>
       </div>

            <!-- Lightbox -->
            <Teleport to="body">
                <Transition
                    enter-active-class="transition duration-200 ease-out"
                    enter-from-class="opacity-0"
                    enter-to-class="opacity-100"
                    leave-active-class="transition duration-150"
                    leave-from-class="opacity-100"
                    leave-to-class="opacity-0">
                    <div v-if="lightbox"
                        class="fixed inset-0 z-[9999] bg-black flex flex-col"
                        @touchstart="onTouchStart" @touchend="onTouchEnd">
                        <div class="flex items-center justify-between px-4 pt-14 pb-3 shrink-0">
                            <button @click="closeLightbox"
                                class="w-9 h-9 rounded-full bg-white/10 flex items-center justify-center">
                                <X :size="20" class="text-white" />
                            </button>
                            <span v-if="lightboxImages.length > 1" class="text-white/70 text-sm font-semibold">
                                {{ lightboxIndex + 1 }} / {{ lightboxImages.length }}
                            </span>
                            <div class="w-9"></div>
                        </div>
                        <div class="flex-1 flex items-center justify-center px-2 min-h-0">
                            <img :src="lightboxImages[lightboxIndex]"
                                class="max-w-full max-h-full object-contain rounded-lg select-none"
                                draggable="false" />
                        </div>
                        <template v-if="lightboxImages.length > 1">
                            <button @click="prevImage"
                                class="absolute left-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/10 flex items-center justify-center">
                                <ChevronLeft :size="22" class="text-white" />
                            </button>
                            <button @click="nextImage"
                                class="absolute right-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/10 flex items-center justify-center">
                                <ChevronRight :size="22" class="text-white" />
                            </button>
                        </template>
                        <div v-if="lightboxImages.length > 1" class="flex justify-center gap-1.5 pb-10 shrink-0">
                            <div v-for="(_, i) in lightboxImages" :key="i"
                                class="h-1.5 rounded-full transition-all"
                                :class="i === lightboxIndex ? 'bg-white w-4' : 'bg-white/30 w-1.5'">
                            </div>
                        </div>
                    </div>
                </Transition>
            </Teleport>

    </div>
</template>
