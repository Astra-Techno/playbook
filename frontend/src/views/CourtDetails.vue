<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    ChevronLeft, MapPin, Star, Clock,
    Calendar, CheckCircle2, XCircle, Info,
    Wind, Flag, Target, Activity, CircleDot, Layers3, Dumbbell, Waves, Swords,
    Share2, Heart, Lock, Sun, Moon, Crown, Infinity, BadgeCheck,
    UserPlus, X, Search, Loader2, Users
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const toast = useToastStore()

const court = ref(null)
const plans = ref([])
const activeTab = ref('booking')
const loading = ref(true)
const bookingLoading = ref(false)
const subscribeLoading = ref(null)  // holds plan_id being subscribed
const paymentDemo = ref(false)   // true when Cashfree is not configured

const selectedDate  = ref('')
const selectedSlots = ref([]) // multi-select
const bookedSlots = ref([])
const activeSub = ref(null)     // user's active subscription for this court
const lockedSlotPeak = ref(null) // 'morning' | 'evening' when user taps a locked slot
const reviews = ref([])
const avgRating = ref(null)
const reviewCount = ref(0)
const isFavorited = ref(false)
const favLoading = ref(false)

// Review form
const showReviewForm  = ref(false)
const reviewRating    = ref(0)
const hoverRating     = ref(0)
const reviewComment   = ref('')
const reviewSubmitting = ref(false)
const userPastBooking = ref(null)   // past booking_id for this court
const alreadyReviewed = ref(false)

// Add Players modal — shown after a successful booking
const addPlayers = ref({
    show: false, bookingIds: [], slotLabel: '',
    regulars: [], regularsLoading: false,
    phone: '', searchResult: null, searching: false, notFound: false,
    selected: [],   // [{ id, name, phone, avatar_url }]
    submitting: false,
})

const isSelected = (id) => addPlayers.value.selected.some(p => p.id === id)

const toggleRegular = (u) => {
    if (isSelected(u.id)) {
        addPlayers.value.selected = addPlayers.value.selected.filter(p => p.id !== u.id)
    } else {
        addPlayers.value.selected.push(u)
    }
}

const searchPlayer = async () => {
    const phone = addPlayers.value.phone.trim()
    if (phone.length < 10) return
    addPlayers.value.searching = true
    addPlayers.value.searchResult = null
    addPlayers.value.notFound = false
    try {
        const res = await axios.get(`/users/search?phone=${encodeURIComponent(phone)}`)
        if (res.data.user) {
            const u = res.data.user
            if (u.id === auth.user?.id || isSelected(u.id)) {
                addPlayers.value.notFound = true
            } else {
                addPlayers.value.searchResult = u
            }
        } else {
            addPlayers.value.notFound = true
        }
    } catch { addPlayers.value.notFound = true }
    finally { addPlayers.value.searching = false }
}

const addPlayerToList = (u) => {
    if (!isSelected(u.id)) addPlayers.value.selected.push(u)
    addPlayers.value.searchResult = null
    addPlayers.value.phone = ''
    addPlayers.value.notFound = false
}

const removePlayer = (id) => {
    addPlayers.value.selected = addPlayers.value.selected.filter(p => p.id !== id)
}

const shareWhatsApp = () => {
    const { slotLabel } = addPlayers.value
    const courtName = court.value?.name || 'a court'
    const appUrl = window.location.origin
    const msg = `Hey! I've booked a slot at *${courtName}*${slotLabel ? ' on ' + slotLabel : ''}. Come join me! 🏸\n${appUrl}`
    window.open(`https://wa.me/?text=${encodeURIComponent(msg)}`, '_blank')
}

const submitPlayers = async () => {
    const { bookingIds, selected } = addPlayers.value
    if (!selected.length) { addPlayers.value.show = false; router.push('/bookings'); return }
    addPlayers.value.submitting = true
    try {
        await Promise.all(bookingIds.map(bid =>
            axios.post('/booking-players', {
                booking_id: bid,
                invited_by: auth.user?.id,
                user_ids: selected.map(p => p.id),
            })
        ))
        toast.success(`${selected.length} player${selected.length > 1 ? 's' : ''} notified!`)
    } catch { /* non-critical */ }
    finally {
        addPlayers.value.submitting = false
        addPlayers.value.show = false
        router.push('/bookings')
    }
}

const openAddPlayers = async (bookingIds, startTime) => {
    // Format slot label: "Wed, 16 Apr · 06:00 PM"
    let slotLabel = ''
    if (startTime) {
        const d = new Date(`${startTime.replace(' ', 'T')}`)
        slotLabel = d.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' }) +
                    ' · ' + d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
    }
    addPlayers.value = {
        show: true, bookingIds, slotLabel,
        regulars: [], regularsLoading: true,
        phone: '', searchResult: null, searching: false, notFound: false,
        selected: [], submitting: false,
    }
    try {
        const res = await axios.get(`/courts/${court.value.id}/regulars?exclude_user=${auth.user?.id}`)
        addPlayers.value.regulars = res.data.players || []
    } catch { addPlayers.value.regulars = [] }
    finally { addPlayers.value.regularsLoading = false }
}

// Parse "YYYY-MM-DD HH:MM:SS" as local time (avoids browser UTC timezone shift)
const parseLocal = (dt) => { const [d, t] = String(dt).split(' '); return new Date(`${d}T${t || '00:00:00'}`) }

// 14-day date options
const today = new Date()
const dateOptions = Array.from({ length: 14 }, (_, i) => {
    const d = new Date(today)
    d.setDate(today.getDate() + i)
    const value = d.toISOString().slice(0, 10)
    return {
        value,
        day: d.getDate(),
        weekday: d.toLocaleDateString('en-IN', { weekday: 'short' }),
        isToday: i === 0,
        isTomorrow: i === 1,
    }
})

// Build slot list based on court operating hours
const TIME_SLOTS = computed(() => {
    const openH  = court.value ? parseInt((court.value.open_time  || '06:00').split(':')[0]) : 6
    const closeH = court.value ? parseInt((court.value.close_time || '22:00').split(':')[0]) : 22
    return Array.from({ length: closeH - openH }, (_, i) => {
        const hour = openH + i
        const h12  = hour > 12 ? hour - 12 : (hour === 0 ? 12 : hour)
        const ampm = hour >= 12 ? 'PM' : 'AM'
        return {
            hour,
            label: `${h12}:00 ${ampm}`,
            short: `${h12}${ampm}`,
            pad:   String(hour).padStart(2, '0') + ':00',
        }
    })
})

// ── Peak hour helpers ─────────────────────────────────────────────────────────

const slotPeakType = (slot) => {
    if (!court.value) return null
    const time = slot.pad + ':00'
    const mps  = court.value.morning_peak_start || '05:00:00'
    const mpe  = court.value.morning_peak_end   || '09:00:00'
    const eps  = court.value.evening_peak_start || '17:00:00'
    const epe  = court.value.evening_peak_end   || '21:00:00'
    if (time >= mps && time < mpe) return 'morning'
    if (time >= eps && time < epe) return 'evening'
    return null
}

const subCoversSlot = (subSlotType, peakType) => {
    if (!subSlotType) return false
    if (subSlotType === 'unlimited' || subSlotType === 'full_day') return true
    return subSlotType === peakType
}

const isPeakLocked = (slot) => {
    if (!court.value?.peak_members_only) return false
    const pt = slotPeakType(slot)
    if (!pt) return false
    return !subCoversSlot(activeSub.value?.slot_type, pt)
}

// ── Slot state ────────────────────────────────────────────────────────────────

const isBooked = (slot) => {
    const s = `${selectedDate.value} ${slot.pad}:00`
    const e = `${selectedDate.value} ${String(slot.hour + 1).padStart(2, '0')}:00:00`
    return bookedSlots.value.some(b => s < b.end_time && e > b.start_time)
}

const slotState = (slot) => {
    if (!selectedDate.value) return 'idle'
    if (isBooked(slot)) return 'booked'
    if (selectedSlots.value.some(s => s.hour === slot.hour)) return 'selected'
    if (isPeakLocked(slot)) {
        return slotPeakType(slot) === 'morning' ? 'peak_morning' : 'peak_evening'
    }
    return 'free'
}

// ── Sport metadata ────────────────────────────────────────────────────────────

const sportInfo = {
    shuttle:  { label: 'Badminton',   cls: 'bg-blue-100 text-blue-700',    icon: Wind     },
    turf:     { label: 'Football',    cls: 'bg-green-100 text-green-700',   icon: Flag     },
    gym:      { label: 'Gym',         cls: 'bg-violet-100 text-violet-700', icon: Dumbbell },
    cricket:  { label: 'Cricket',     cls: 'bg-orange-100 text-orange-700', icon: Target   },
    tennis:   { label: 'Tennis',      cls: 'bg-yellow-100 text-yellow-700', icon: Activity },
    swimming: { label: 'Swimming',    cls: 'bg-cyan-100 text-cyan-700',     icon: Waves    },
    boxing:   { label: 'Boxing',      cls: 'bg-red-100 text-red-700',       icon: Swords   },
    basket:   { label: 'Basketball',  cls: 'bg-rose-100 text-rose-700',     icon: CircleDot},
    other:    { label: 'Other',       cls: 'bg-slate-100 text-slate-700',   icon: Layers3  },
}
const getSport = (t) => sportInfo[t] || sportInfo.other

const sportImages = {
    shuttle:  'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&q=80',
    turf:     'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=600&q=80',
    gym:      'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
    cricket:  'https://images.unsplash.com/photo-1540747913346-19212a4b8277?w=600&q=80',
    tennis:   'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&q=80',
    basket:   'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&q=80',
    swimming: 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=600&q=80',
    boxing:   'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=600&q=80',
}
const heroImg = computed(() =>
    court.value?.image_url || sportImages[court.value?.type] || sportImages.turf
)

const price      = computed(() => court.value ? parseFloat(court.value.hourly_rate) : 0)
const totalPrice = computed(() => price.value * selectedSlots.value.length)

// Computed slot groups for clean template rendering
const morningPeakSlots = computed(() => TIME_SLOTS.value.filter(s => slotPeakType(s) === 'morning'))
const eveningPeakSlots = computed(() => TIME_SLOTS.value.filter(s => slotPeakType(s) === 'evening'))
const offPeakSlots     = computed(() => TIME_SLOTS.value.filter(s => slotPeakType(s) === null))

// Plan slot display
const slotMeta = {
    morning:   { label: 'Morning',   icon: Sun,      cls: 'bg-amber-100 text-amber-700' },
    evening:   { label: 'Evening',   icon: Moon,     cls: 'bg-indigo-100 text-indigo-700' },
    full_day:  { label: 'Full Day',  icon: BadgeCheck,cls: 'bg-primary-light text-primary' },
    unlimited: { label: 'Unlimited', icon: Infinity, cls: 'bg-slate-100 text-slate-600' },
}

// Which plans are relevant for the locked slot type (to highlight on membership tab)
const recommendedPlanIds = computed(() => {
    if (!lockedSlotPeak.value || !plans.value.length) return []
    return plans.value
        .filter(p => {
            const st = p.slot_type || 'unlimited'
            return st === 'unlimited' || st === 'full_day' || st === lockedSlotPeak.value
        })
        .map(p => p.id)
})

// ── Data fetching ─────────────────────────────────────────────────────────────

onMounted(async () => {
    // Check if payment gateway is configured — silently ignore if endpoint missing
    try {
        const cfg = await axios.get('/payments/config')
        paymentDemo.value = cfg.data.demo === true
    } catch { paymentDemo.value = true }

    try {
        const res = await axios.get('/courts')
        court.value = (res.data.records || []).find(c => c.id == route.params.id) || null
        if (court.value) {
            const [plansRes, reviewsRes] = await Promise.all([
                axios.get(`/plans?court_id=${court.value.id}`),
                axios.get(`/reviews?court_id=${court.value.id}`),
            ])
            plans.value = plansRes.data.records || []
            reviews.value = reviewsRes.data.records || []
            avgRating.value = reviewsRes.data.avg_rating || null
            reviewCount.value = reviewsRes.data.count || 0

            // Check user's active subscription + favorites + past bookings
            if (auth.isLoggedIn) {
                try {
                    const [subRes, favRes, bkRes] = await Promise.all([
                        axios.get(`/subscriptions?user_id=${auth.user?.id}&court_id=${court.value.id}`),
                        axios.get(`/favorites?user_id=${auth.user?.id}`),
                        axios.get(`/bookings?user_id=${auth.user?.id}`),
                    ])
                    activeSub.value   = subRes.data.active || null
                    isFavorited.value = (favRes.data.ids || []).includes(court.value.id)
                    // Find a past booking for this court
                    const now = new Date()
                    const past = (bkRes.data.records || []).find(b =>
                        b.court_id == court.value.id && parseLocal(b.start_time) <= now
                    )
                    userPastBooking.value = past || null
                    // Check if user already left a review
                    alreadyReviewed.value = reviews.value.some(r => r.user_name === auth.user?.name)
                } catch { activeSub.value = null }
            }
        }
    } catch { court.value = null }
    finally { loading.value = false }
})

watch(selectedDate, async (date) => {
    selectedSlots.value = []
    lockedSlotPeak.value = null
    bookedSlots.value = []
    if (date && court.value) {
        try {
            const r = await axios.get(`/bookings?court_id=${court.value.id}&date=${date}`)
            bookedSlots.value = r.data.records || []
        } catch { bookedSlots.value = [] }
    }
})

// ── Reviews ───────────────────────────────────────────────────────────────────

const submitReview = async () => {
    if (!reviewRating.value) { toast.error('Please select a rating'); return }
    reviewSubmitting.value = true
    try {
        await axios.post('/reviews', {
            court_id:   court.value.id,
            user_id:    auth.user.id,
            booking_id: userPastBooking.value.id,
            rating:     reviewRating.value,
            comment:    reviewComment.value.trim(),
        })
        toast.success('Review submitted!')
        // Refresh reviews
        const res = await axios.get(`/reviews?court_id=${court.value.id}`)
        reviews.value     = res.data.records || []
        avgRating.value   = res.data.avg_rating || null
        reviewCount.value = res.data.count || 0
        alreadyReviewed.value = true
        showReviewForm.value  = false
        reviewRating.value    = 0
        reviewComment.value   = ''
    } catch (e) {
        const msg = e.response?.data?.message || 'Could not submit review'
        toast.error(msg)
        if (e.response?.status === 409) alreadyReviewed.value = true
    } finally {
        reviewSubmitting.value = false
    }
}

// ── Favorites ─────────────────────────────────────────────────────────────────

const toggleFavorite = async () => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    favLoading.value = true
    try {
        const res = await axios.post('/favorites', { user_id: auth.user?.id, court_id: court.value.id })
        isFavorited.value = res.data.favorited
        toast.success(isFavorited.value ? 'Added to saved!' : 'Removed from saved')
    } catch { toast.error('Could not update favorites') }
    finally { favLoading.value = false }
}

// ── Cashfree helpers ──────────────────────────────────────────────────────────

const loadCashfreeScript = () =>
    new Promise((resolve) => {
        if (window.Cashfree) { resolve(true); return }
        const s = document.createElement('script')
        s.src     = 'https://sdk.cashfree.com/js/v3/cashfree.js'
        s.onload  = () => resolve(true)
        s.onerror = () => resolve(false)
        document.head.appendChild(s)
    })

/**
 * Create a Cashfree order, open the checkout modal, then call onSuccess.
 * @param {number}   amount    - amount in ₹
 * @param {string}   type      - 'booking' | 'subscription'
 * @param {object}   payload   - stored in DB for the verify step
 * @param {Function} onSuccess - called with { order_id } after payment succeeds
 */
const openCashfree = async (amount, type, payload, onSuccess) => {
    // 1. Create order on our backend
    let orderData
    try {
        const res = await axios.post('/payments/create-order', {
            user_id: auth.user?.id, amount, type, payload,
        })
        orderData = res.data
    } catch {
        toast.error('Could not initiate payment. Try again.')
        return
    }

    // 2a. Demo mode — Cashfree not configured, skip payment UI
    if (orderData.demo) {
        toast.info(`Demo mode — ₹${amount} payment simulated`)
        await onSuccess({ order_id: orderData.order_id })
        return
    }

    // 2b. Real Cashfree checkout
    const loaded = await loadCashfreeScript()
    if (!loaded) { toast.error('Payment gateway unavailable. Check your internet.'); return }

    const cashfree = window.Cashfree({ mode: orderData.env })

    cashfree.checkout({
        paymentSessionId: orderData.payment_session_id,
        redirectTarget:   '_modal',
    }).then(async (result) => {
        if (result.error) {
            toast.error(result.error.message || 'Payment failed or cancelled')
            return
        }
        if (result.paymentDetails || result.redirect) {
            await onSuccess({ order_id: orderData.order_id })
        }
    }).catch(() => {
        toast.error('Payment window closed')
    })
}

// ── Actions ───────────────────────────────────────────────────────────────────

const handleSlotClick = (slot) => {
    const state = slotState(slot)
    if (state === 'booked') return

    if (state === 'peak_morning' || state === 'peak_evening') {
        const pt = slotPeakType(slot)
        lockedSlotPeak.value = pt
        // Switch to membership tab to show subscribe options
        activeTab.value = 'membership'
        toast.error(`${pt === 'morning' ? 'Morning' : 'Evening'} peak is members only. Subscribe below!`)
        return
    }

    lockedSlotPeak.value = null
    const idx = selectedSlots.value.findIndex(s => s.hour === slot.hour)
    if (idx >= 0) {
        selectedSlots.value.splice(idx, 1)
    } else {
        selectedSlots.value.push(slot)
        selectedSlots.value.sort((a, b) => a.hour - b.hour)
    }
}

const confirmBooking = async () => {
    if (!selectedDate.value || !selectedSlots.value.length) { toast.error('Choose a date and time slot'); return }
    if (!auth.isLoggedIn) { router.push('/login'); return }

    // Group consecutive selected hours into continuous time ranges.
    // e.g. [8,9,10, 12] → [{8:00–11:00}, {12:00–13:00}]
    const sorted = [...selectedSlots.value].sort((a, b) => a.hour - b.hour)
    const groups = sorted.reduce((acc, slot) => {
        const last = acc[acc.length - 1]
        if (last && slot.hour === last[last.length - 1].hour + 1) {
            last.push(slot)
        } else {
            acc.push([slot])
        }
        return acc
    }, [])

    const hourPrice = parseFloat(court.value.hourly_rate) || 0
    const slots = groups.map(group => ({
        start_time:  `${selectedDate.value} ${group[0].pad}:00`,
        end_time:    `${selectedDate.value} ${String(group[group.length - 1].hour + 1).padStart(2, '0')}:00:00`,
        total_price: group.length * hourPrice,
    }))

    bookingLoading.value = true

    // Demo mode — no payment gateway configured, book directly
    if (paymentDemo.value) {
        try {
            const results = await Promise.all(slots.map(s =>
                axios.post('/bookings', {
                    user_id:     auth.user?.id,
                    court_id:    court.value.id,
                    start_time:  s.start_time,
                    end_time:    s.end_time,
                    type:        'hourly',
                    total_price: s.total_price,
                })
            ))
            const bookingIds = results.map(r => r.data.id).filter(Boolean)
            toast.success(`${selectedSlots.value.length} slot${selectedSlots.value.length > 1 ? 's' : ''} booked!`)
            openAddPlayers(bookingIds, slots[0]?.start_time)
        } catch (err) {
            if (err.response?.status === 409) {
                toast.error('One or more slots were just taken — please reselect')
                const r = await axios.get(`/bookings?court_id=${court.value.id}&date=${selectedDate.value}`)
                bookedSlots.value = r.data.records || []
                selectedSlots.value = []
            } else {
                toast.error(err.response?.data?.message || 'Booking failed')
            }
        } finally { bookingLoading.value = false }
        return
    }

    await openCashfree(
        totalPrice.value,
        'booking',
        {
            user_id: auth.user?.id, court_id: court.value.id,
            slots, type: 'hourly', total_price: totalPrice.value,
        },
        async ({ order_id }) => {
            try {
                const vRes = await axios.post('/payments/verify', { order_id })
                const bookingIds = (vRes.data.booking_ids || [])
                toast.success(`${selectedSlots.value.length} slot${selectedSlots.value.length > 1 ? 's' : ''} booked!`)
                openAddPlayers(bookingIds, slots[0]?.start_time)
            } catch (err) {
                if (err.response?.status === 409) {
                    toast.error('One or more slots were just taken — please reselect')
                    const r = await axios.get(`/bookings?court_id=${court.value.id}&date=${selectedDate.value}`)
                    bookedSlots.value = r.data.records || []
                    selectedSlots.value = []
                } else {
                    toast.error(err.response?.data?.message || 'Booking failed after payment')
                }
            } finally { bookingLoading.value = false }
        }
    )

    bookingLoading.value = false
}

const subscribePlan = async (plan) => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    subscribeLoading.value = plan.id

    // Demo mode — activate subscription directly
    if (paymentDemo.value) {
        try {
            await axios.post('/subscriptions', {
                user_id:       auth.user?.id,
                plan_id:       plan.id,
                court_id:      court.value.id,
                slot_type:     plan.slot_type || 'unlimited',
                duration_days: plan.duration_days,
            })
            toast.success(`Subscribed to ${plan.name}!`)
            const subRes = await axios.get(`/subscriptions?user_id=${auth.user?.id}&court_id=${court.value.id}`)
            activeSub.value = subRes.data.active || null
            lockedSlotPeak.value = null
            activeTab.value = 'booking'
        } catch (err) {
            toast.error(err.response?.data?.message || 'Subscription failed')
        } finally { subscribeLoading.value = null }
        return
    }

    await openCashfree(
        parseFloat(plan.price),
        'subscription',
        {
            user_id:       auth.user?.id,
            plan_id:       plan.id,
            court_id:      court.value.id,
            slot_type:     plan.slot_type || 'unlimited',
            duration_days: plan.duration_days,
        },
        async ({ order_id }) => {
            try {
                await axios.post('/payments/verify', { order_id })
                toast.success(`Subscribed to ${plan.name}!`)
                const subRes = await axios.get(`/subscriptions?user_id=${auth.user?.id}&court_id=${court.value.id}`)
                activeSub.value = subRes.data.active || null
                lockedSlotPeak.value = null
                activeTab.value = 'booking'
            } catch (err) {
                toast.error(err.response?.data?.message || 'Subscription failed after payment')
            } finally { subscribeLoading.value = null }
        }
    )

    subscribeLoading.value = null
}
</script>

<template>
    <div class="min-h-full bg-slate-50">

        <!-- Dynamic Header Subject -->
        <Teleport v-if="court" to="#header-subject">
            {{ court.name }}
        </Teleport>

        <!-- Loading -->
        <div v-if="loading" class="flex items-center justify-center h-64">
            <div class="w-8 h-8 border-2 border-primary/20 border-t-primary rounded-full animate-spin"></div>
        </div>

        <!-- Not found -->
        <div v-else-if="!court" class="flex flex-col items-center justify-center py-24 gap-3">
            <XCircle :size="48" class="text-slate-300" />
            <p class="text-slate-500 font-medium">Court not found</p>
            <button @click="router.push('/')" class="mt-2 bg-primary text-white font-semibold px-6 py-2.5 rounded-xl">
                Go Home
            </button>
        </div>

        <template v-else>
            <!-- Hero Image -->
            <div class="relative h-60 bg-slate-200">
                <img :src="heroImg" :alt="court.name" class="w-full h-full object-cover"
                    onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80'" />
                <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent"></div>


                <!-- Action buttons -->
                <div class="absolute top-12 right-4 flex gap-2">
                    <button @click="toggleFavorite" :disabled="favLoading"
                        class="w-9 h-9 bg-white/90 backdrop-blur-sm rounded-full flex items-center justify-center shadow-md active:scale-90 transition-transform">
                        <Heart :size="16" :class="isFavorited ? 'fill-red-500 text-red-500' : 'text-slate-600'" />
                    </button>
                    <button class="w-9 h-9 bg-white/90 backdrop-blur-sm rounded-full flex items-center justify-center shadow-md">
                        <Share2 :size="16" class="text-slate-600" />
                    </button>
                </div>

                <!-- Sport badge -->
                <div class="absolute bottom-4 left-4 flex items-center gap-2">
                    <span :class="[getSport(court.type).cls, 'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-bold shadow-sm']">
                        <component :is="getSport(court.type).icon" :size="12" />
                        {{ getSport(court.type).label }}
                    </span>
                    <!-- Active subscription badge -->
                    <span v-if="activeSub" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-bold bg-primary text-white shadow-sm">
                        <Crown :size="11" />
                        Member
                    </span>
                </div>
            </div>

            <!-- Court Info Card -->
            <div class="bg-white px-5 py-4 border-b border-slate-100">
                <div class="flex items-start justify-between gap-2 mb-2">
                    <h1 class="text-xl font-extrabold text-slate-900">{{ court.name }}</h1>
                    <div class="flex items-center gap-1 bg-amber-50 px-2.5 py-1.5 rounded-xl shrink-0">
                        <Star :size="13" class="text-amber-500 fill-amber-400" />
                        <span class="text-sm font-bold text-amber-700">{{ avgRating || '—' }}</span>
                        <span v-if="reviewCount" class="text-[11px] text-amber-600">({{ reviewCount }})</span>
                    </div>
                </div>
                <div class="flex items-center gap-1.5 text-slate-500 text-sm mb-3">
                    <MapPin :size="13" class="text-slate-400" />
                    {{ court.location || 'Location not set' }}
                </div>
                <div class="flex items-center justify-between">
                    <span class="flex items-center gap-1.5 text-slate-500 text-sm">
                        <Clock :size="13" class="text-slate-400" />
                        {{ court.open_time?.slice(0,5) || '06:00' }} – {{ court.close_time?.slice(0,5) || '22:00' }}
                    </span>
                    <span class="text-xl font-extrabold text-primary">
                        ₹{{ court.hourly_rate }}<span class="text-sm font-semibold text-slate-400">/hr</span>
                    </span>
                </div>

                <!-- Peak hours info strip (if applicable) -->
                <div v-if="court.peak_members_only" class="mt-3 bg-amber-50 border border-amber-100 rounded-xl px-3 py-2.5 flex items-center gap-2.5 shadow-sm">
                    <Lock :size="14" :stroke-width="2.5" class="text-amber-600 shrink-0" />
                    <p class="text-xs text-amber-800 font-semibold leading-snug">
                        Peak hours are members only: <span class="text-amber-600/80">{{ court.morning_peak_start?.slice(0,5) }}–{{ court.morning_peak_end?.slice(0,5) }}</span> &amp;
                        <span class="text-amber-600/80">{{ court.evening_peak_start?.slice(0,5) }}–{{ court.evening_peak_end?.slice(0,5) }}</span>
                    </p>
                </div>
            </div>

            <!-- Tabs -->
            <div class="bg-white border-b border-slate-100 flex px-5 sticky top-0 z-30">
                <button @click="activeTab = 'booking'"
                    class="flex-1 py-3.5 text-sm font-bold border-b-2 transition-colors"
                    :class="activeTab === 'booking' ? 'border-primary text-primary' : 'border-transparent text-slate-400'">
                    Book a Slot
                </button>
                <button @click="activeTab = 'membership'"
                    class="flex-1 py-3.5 text-sm font-bold border-b-2 transition-colors relative"
                    :class="activeTab === 'membership' ? 'border-primary text-primary' : 'border-transparent text-slate-400'">
                    Memberships
                    <span v-if="activeSub" class="absolute top-2.5 right-3 w-2 h-2 bg-primary-light0 rounded-full"></span>
                </button>
            </div>

            <!-- Tab Content -->
            <div class="px-4 py-5 pb-48">

                <!-- BOOKING TAB -->
                <div v-if="activeTab === 'booking'">
                    <!-- Date Picker -->
                    <h3 class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">Select Date</h3>
                    <div class="flex gap-2 overflow-x-auto scrollbar-hide pb-1 mb-6">
                        <button
                            v-for="d in dateOptions" :key="d.value"
                            @click="selectedDate = d.value"
                            class="flex flex-col items-center px-3.5 py-3 rounded-2xl border-2 min-w-[58px] transition-all shrink-0"
                            :class="selectedDate === d.value
                                ? 'bg-primary border-primary text-white'
                                : 'bg-white border-slate-200 text-slate-600'">
                            <span class="text-[10px] font-bold uppercase tracking-wider leading-none mb-1"
                                :class="selectedDate === d.value ? 'text-white/70' : 'text-slate-400'">
                                {{ d.weekday }}
                            </span>
                            <span class="text-xl font-extrabold leading-none">{{ d.day }}</span>
                            <span v-if="d.isToday || d.isTomorrow"
                                class="text-[9px] font-bold mt-1 leading-none"
                                :class="selectedDate === d.value ? 'text-white/70' : 'text-primary'">
                                {{ d.isToday ? 'TODAY' : 'TMR' }}
                            </span>
                        </button>
                    </div>

                    <!-- Slot Grid -->
                    <div class="flex items-center justify-between mb-3 flex-wrap gap-1">
                        <h3 class="text-xs font-bold text-slate-500 uppercase tracking-widest">Select Time</h3>
                        <div v-if="selectedDate" class="flex items-center gap-2 text-[10px] font-semibold flex-wrap">
                            <span class="flex items-center gap-1 text-primary">
                                <span class="w-3 h-3 rounded-sm bg-primary inline-block"></span> Chosen
                            </span>
                            <span class="flex items-center gap-1 text-slate-400">
                                <span class="w-3 h-3 rounded-sm bg-slate-200 inline-block"></span> Booked
                            </span>
                            <span v-if="court.peak_members_only" class="flex items-center gap-1 text-amber-600">
                                <span class="w-3 h-3 rounded-sm bg-amber-200 inline-block border border-amber-300"></span>
                                <Lock :size="10" /> Peak
                            </span>
                        </div>
                    </div>

                    <div v-if="!selectedDate"
                        class="bg-slate-100 rounded-2xl flex flex-col items-center py-10 mb-6">
                        <Calendar :size="30" class="text-slate-300 mb-2" />
                        <p class="text-sm text-slate-400 font-medium">Select a date first</p>
                    </div>

                    <!-- Slot Grid -->
                    <div v-else class="mb-6 space-y-4">

                        <!-- Non-peak court: single flat grid -->
                        <template v-if="!court.peak_members_only">
                            <div class="grid grid-cols-4 gap-2">
                                <button
                                    v-for="slot in TIME_SLOTS" :key="slot.hour"
                                    @click="handleSlotClick(slot)"
                                    class="py-3 rounded-xl text-xs font-bold border-2 transition-all text-center"
                                    :class="{
                                        'bg-primary border-primary text-white shadow-sm': slotState(slot) === 'selected',
                                        'bg-slate-100 border-slate-100 text-slate-300 cursor-not-allowed': slotState(slot) === 'booked',
                                        'bg-white border-slate-200 text-slate-700 hover:border-primary/40 hover:bg-primary-light active:scale-95 cursor-pointer': slotState(slot) === 'free',
                                    }">
                                    {{ slot.short }}
                                </button>
                            </div>
                        </template>

                        <!-- Peak court: grouped sections -->
                        <template v-else>
                            <!-- Morning peak -->
                            <div v-if="morningPeakSlots.length">
                                <div class="flex items-center gap-1.5 mb-2 text-[11px] font-semibold text-amber-600">
                                    <Sun :size="12" />
                                    Morning peak · {{ court.morning_peak_start?.slice(0,5) }} – {{ court.morning_peak_end?.slice(0,5) }}
                                    <span v-if="activeSub && subCoversSlot(activeSub.slot_type, 'morning')" class="text-primary font-bold ml-1">✓ Access granted</span>
                                    <Lock v-else :size="11" class="ml-0.5" />
                                </div>
                                <div class="grid grid-cols-4 gap-2">
                                    <button v-for="slot in morningPeakSlots" :key="slot.hour"
                                        @click="handleSlotClick(slot)"
                                        class="py-3 rounded-xl text-xs font-bold border-2 transition-all text-center relative"
                                        :class="{
                                            'bg-primary border-primary text-white shadow-sm': slotState(slot) === 'selected',
                                            'bg-slate-100 border-slate-100 text-slate-300 cursor-not-allowed': slotState(slot) === 'booked',
                                            'bg-amber-100 border-amber-200 text-amber-700 cursor-pointer': slotState(slot) === 'peak_morning',
                                            'bg-white border-slate-200 text-slate-700 hover:border-primary/40 hover:bg-primary-light active:scale-95 cursor-pointer': slotState(slot) === 'free',
                                        }">
                                        {{ slot.short }}
                                        <Lock v-if="slotState(slot) === 'peak_morning'" :size="8" class="absolute top-1 right-1 opacity-60" />
                                    </button>
                                </div>
                            </div>

                            <!-- Evening peak -->
                            <div v-if="eveningPeakSlots.length">
                                <div class="flex items-center gap-1.5 mb-2 text-[11px] font-semibold text-indigo-600">
                                    <Moon :size="12" />
                                    Evening peak · {{ court.evening_peak_start?.slice(0,5) }} – {{ court.evening_peak_end?.slice(0,5) }}
                                    <span v-if="activeSub && subCoversSlot(activeSub.slot_type, 'evening')" class="text-primary font-bold ml-1">✓ Access granted</span>
                                    <Lock v-else :size="11" class="ml-0.5" />
                                </div>
                                <div class="grid grid-cols-4 gap-2">
                                    <button v-for="slot in eveningPeakSlots" :key="slot.hour"
                                        @click="handleSlotClick(slot)"
                                        class="py-3 rounded-xl text-xs font-bold border-2 transition-all text-center relative"
                                        :class="{
                                            'bg-primary border-primary text-white shadow-sm': slotState(slot) === 'selected',
                                            'bg-slate-100 border-slate-100 text-slate-300 cursor-not-allowed': slotState(slot) === 'booked',
                                            'bg-indigo-100 border-indigo-200 text-indigo-700 cursor-pointer': slotState(slot) === 'peak_evening',
                                            'bg-white border-slate-200 text-slate-700 hover:border-primary/40 hover:bg-primary-light active:scale-95 cursor-pointer': slotState(slot) === 'free',
                                        }">
                                        {{ slot.short }}
                                        <Lock v-if="slotState(slot) === 'peak_evening'" :size="8" class="absolute top-1 right-1 opacity-60" />
                                    </button>
                                </div>
                            </div>

                            <!-- Off-peak (open to all) -->
                            <div v-if="offPeakSlots.length">
                                <p class="text-[11px] font-semibold text-slate-400 mb-2">Off-peak · open to all</p>
                                <div class="grid grid-cols-4 gap-2">
                                    <button v-for="slot in offPeakSlots" :key="slot.hour"
                                        @click="handleSlotClick(slot)"
                                        class="py-3 rounded-xl text-xs font-bold border-2 transition-all text-center"
                                        :class="{
                                            'bg-primary border-primary text-white shadow-sm': slotState(slot) === 'selected',
                                            'bg-slate-100 border-slate-100 text-slate-300 cursor-not-allowed': slotState(slot) === 'booked',
                                            'bg-white border-slate-200 text-slate-700 hover:border-primary/40 hover:bg-primary-light active:scale-95 cursor-pointer': slotState(slot) === 'free',
                                        }">
                                        {{ slot.short }}
                                    </button>
                                </div>
                            </div>
                        </template>
                    </div>

                    <!-- Booking Summary -->
                    <div v-if="selectedSlots.length && selectedDate"
                        class="bg-primary-light border border-primary/20 rounded-2xl p-4">
                        <div class="flex items-center gap-2 mb-3">
                            <CheckCircle2 :size="16" class="text-primary" />
                            <span class="text-sm font-bold text-primary">Booking Summary</span>
                        </div>
                        <div class="space-y-1.5 text-sm">
                            <div class="flex justify-between">
                                <span class="text-slate-500">Date</span>
                                <span class="font-semibold text-slate-800">
                                    {{ new Date(selectedDate + 'T00:00:00').toLocaleDateString('en-IN', { dateStyle: 'medium' }) }}
                                </span>
                            </div>
                            <div class="flex justify-between items-start">
                                <span class="text-slate-500">Slots</span>
                                <div class="flex flex-wrap gap-1 justify-end max-w-[60%]">
                                    <span v-for="s in selectedSlots" :key="s.hour"
                                        class="bg-primary/10 text-primary text-xs font-semibold px-2 py-0.5 rounded-full">
                                        {{ s.short }}
                                    </span>
                                </div>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-slate-500">Duration</span>
                                <span class="font-semibold text-slate-800">{{ selectedSlots.length }} hour{{ selectedSlots.length > 1 ? 's' : '' }}</span>
                            </div>
                            <div v-if="selectedSlots.length > 1" class="flex justify-between text-xs text-slate-400">
                                <span>₹{{ price }} × {{ selectedSlots.length }} slots</span>
                                <span>₹{{ totalPrice }}</span>
                            </div>
                        </div>
                        <div class="flex justify-between items-center pt-3 mt-3 border-t border-primary/20">
                            <span class="font-bold text-slate-700">Total payable</span>
                            <span class="text-xl font-extrabold text-primary">₹{{ totalPrice }}</span>
                        </div>
                    </div>

                    <!-- REVIEWS SECTION -->
                    <div class="mt-6">
                        <div class="flex items-center justify-between mb-3">
                            <h3 class="section-title">Reviews</h3>
                            <div v-if="reviewCount > 0" class="flex items-center gap-1.5">
                                <Star :size="14" class="fill-amber-400 text-amber-400" />
                                <span class="font-bold text-slate-800 text-sm">{{ avgRating }}</span>
                                <span class="text-xs text-slate-400">({{ reviewCount }})</span>
                            </div>
                        </div>

                        <!-- Write a Review button -->
                        <div v-if="auth.isLoggedIn && userPastBooking && !alreadyReviewed && !showReviewForm"
                            class="mb-4">
                            <button @click="showReviewForm = true"
                                class="w-full flex items-center justify-center gap-2 py-3 rounded-2xl border-2 border-dashed border-primary/30 text-primary text-sm font-bold active:scale-[0.98] transition-transform hover:bg-primary/5">
                                <Star :size="15" class="fill-primary" />
                                Write a Review
                            </button>
                        </div>

                        <!-- Already reviewed badge -->
                        <div v-if="alreadyReviewed" class="mb-4 flex items-center gap-2 text-xs font-bold text-emerald-600 bg-emerald-50 px-4 py-2.5 rounded-xl">
                            <CheckCircle2 :size="14" />
                            You've reviewed this court
                        </div>

                        <!-- Review Form -->
                        <div v-if="showReviewForm"
                            class="mb-4 bg-primary/5 rounded-2xl p-4 ring-1 ring-primary/20">
                            <p class="text-sm font-black text-slate-800 mb-3">Your Rating</p>

                            <!-- Star selector -->
                            <div class="flex gap-2 mb-4">
                                <button v-for="n in 5" :key="n"
                                    @click="reviewRating = n"
                                    @mouseenter="hoverRating = n"
                                    @mouseleave="hoverRating = 0"
                                    class="active:scale-110 transition-transform">
                                    <Star :size="32"
                                        :class="n <= (hoverRating || reviewRating) ? 'fill-amber-400 text-amber-400' : 'fill-slate-200 text-slate-200'" />
                                </button>
                            </div>

                            <!-- Comment -->
                            <textarea v-model="reviewComment"
                                placeholder="Share your experience (optional)…"
                                rows="3"
                                class="w-full text-sm rounded-xl bg-white border border-slate-200 px-4 py-3 resize-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 outline-none placeholder:text-slate-300 mb-3">
                            </textarea>

                            <div class="flex gap-2">
                                <button @click="showReviewForm = false; reviewRating = 0; reviewComment = ''"
                                    class="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-bold text-slate-500 active:scale-95 transition-transform">
                                    Cancel
                                </button>
                                <button @click="submitReview"
                                    :disabled="!reviewRating || reviewSubmitting"
                                    class="flex-1 py-2.5 rounded-xl bg-primary text-white text-sm font-bold disabled:opacity-40 active:scale-95 transition-transform flex items-center justify-center gap-1.5">
                                    <span v-if="reviewSubmitting">Submitting…</span>
                                    <span v-else>Submit Review</span>
                                </button>
                            </div>
                        </div>

                        <div v-if="reviews.length === 0" class="text-center py-8">
                            <Star :size="32" class="text-slate-200 mx-auto mb-2" />
                            <p class="text-sm text-slate-400">No reviews yet. Be the first!</p>
                        </div>

                        <div v-else class="space-y-3">
                            <div v-for="review in reviews" :key="review.id"
                                class="bg-white rounded-2xl p-4 border border-slate-100">
                                <div class="flex items-start justify-between gap-2 mb-2">
                                    <div class="flex items-center gap-2">
                                        <div class="w-8 h-8 rounded-full bg-primary-light flex items-center justify-center shrink-0">
                                            <span class="text-xs font-bold text-primary">
                                                {{ (review.user_name || 'U').charAt(0).toUpperCase() }}
                                            </span>
                                        </div>
                                        <div>
                                            <span class="text-sm font-semibold text-slate-800">{{ review.user_name || 'Player' }}</span>
                                            <p class="text-[10px] text-slate-400">{{ review.created_at ? new Date(review.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '' }}</p>
                                        </div>
                                    </div>
                                    <div class="flex gap-0.5">
                                        <Star v-for="n in 5" :key="n" :size="12"
                                            :class="n <= review.rating ? 'fill-amber-400 text-amber-400' : 'fill-slate-200 text-slate-200'" />
                                    </div>
                                </div>
                                <p v-if="review.comment" class="text-sm text-slate-500 leading-relaxed">{{ review.comment }}</p>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- MEMBERSHIP TAB -->
                <div v-else>

                    <!-- Active subscription banner -->
                    <div v-if="activeSub"
                        class="bg-primary-light border border-primary/20 rounded-2xl p-4 mb-5 flex items-start gap-3">
                        <div class="w-9 h-9 bg-primary rounded-xl flex items-center justify-center shrink-0">
                            <Crown :size="17" class="text-white" />
                        </div>
                        <div class="flex-1 min-w-0">
                            <p class="font-bold text-primary text-sm">Active Membership</p>
                            <p class="text-xs text-primary mt-0.5">
                                <span class="font-semibold capitalize">{{ activeSub.slot_type?.replace('_', ' ') }}</span> access
                                · expires {{ new Date(activeSub.end_date).toLocaleDateString('en-IN', { dateStyle: 'medium' }) }}
                            </p>
                        </div>
                        <span class="text-[10px] font-bold bg-primary text-white px-2 py-1 rounded-full capitalize">Active</span>
                    </div>

                    <!-- Prompt when coming from locked slot -->
                    <div v-if="lockedSlotPeak && !activeSub"
                        class="bg-amber-50 border border-amber-200 rounded-2xl p-4 mb-5 flex items-start gap-3">
                        <Lock :size="18" class="text-amber-600 shrink-0 mt-0.5" />
                        <div>
                            <p class="font-bold text-amber-800 text-sm">Subscription needed</p>
                            <p class="text-xs text-amber-700 mt-0.5">
                                {{ lockedSlotPeak === 'morning' ? 'Morning' : 'Evening' }} peak slots require a membership.
                                Choose a plan below to unlock access.
                            </p>
                        </div>
                    </div>

                    <div v-if="plans.length === 0" class="flex flex-col items-center py-12 text-center">
                        <Info :size="40" class="text-slate-300 mb-3" />
                        <p class="font-bold text-slate-600">No plans yet</p>
                        <p class="text-sm text-slate-400 mt-1">This court hasn't set up membership plans yet.</p>
                    </div>

                    <div v-else class="space-y-4">
                        <div v-for="(plan, i) in plans" :key="plan.id"
                            class="bg-white rounded-2xl p-5 border-2 relative overflow-hidden transition-all"
                            :class="[
                                recommendedPlanIds.includes(plan.id) && !activeSub ? 'border-amber-400 ring-2 ring-amber-200' :
                                (i === 0 ? 'border-primary' : 'border-slate-200')
                            ]">
                            <!-- Tags -->
                            <div class="absolute top-0 right-0 flex gap-1 flex-col items-end">
                                <div v-if="i === 0" class="bg-primary text-white text-[10px] font-extrabold px-3 py-1 rounded-bl-xl tracking-wider">
                                    POPULAR
                                </div>
                                <div v-if="recommendedPlanIds.includes(plan.id) && !activeSub"
                                    class="bg-amber-500 text-white text-[10px] font-extrabold px-3 py-1 rounded-bl-xl tracking-wider mr-0 mt-0">
                                    RECOMMENDED
                                </div>
                            </div>

                            <div class="flex items-start justify-between mb-3 pr-2">
                                <div>
                                    <h3 class="font-extrabold text-slate-900">{{ plan.name }}</h3>
                                    <p v-if="plan.description" class="text-sm text-slate-500 mt-0.5">{{ plan.description }}</p>
                                    <!-- Slot type badge -->
                                    <span v-if="plan.slot_type"
                                        class="inline-flex items-center gap-1 mt-2 text-[11px] font-bold px-2 py-0.5 rounded-full"
                                        :class="(slotMeta[plan.slot_type] || slotMeta.unlimited).cls">
                                        <component :is="(slotMeta[plan.slot_type] || slotMeta.unlimited).icon" :size="11" />
                                        {{ (slotMeta[plan.slot_type] || slotMeta.unlimited).label }}
                                    </span>
                                </div>
                                <div class="text-right shrink-0">
                                    <p class="text-2xl font-extrabold text-primary">₹{{ plan.price }}</p>
                                    <p class="text-xs text-slate-400">{{ plan.duration_days }} days</p>
                                </div>
                            </div>

                            <button
                                @click="!auth.isLoggedIn ? router.push('/login') : subscribePlan(plan)"
                                :disabled="subscribeLoading === plan.id || (activeSub && subCoversSlot(activeSub.slot_type, plan.slot_type || 'unlimited'))"
                                class="w-full font-bold py-3 rounded-xl text-sm active:scale-95 transition-all flex items-center justify-center gap-2"
                                :class="activeSub && subCoversSlot(activeSub.slot_type, plan.slot_type || 'unlimited')
                                    ? 'bg-slate-100 text-slate-400 cursor-not-allowed'
                                    : 'bg-primary text-white'">
                                <span v-if="subscribeLoading === plan.id" class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                                <template v-else>
                                    <CheckCircle2 v-if="activeSub && subCoversSlot(activeSub.slot_type, plan.slot_type || 'unlimited')" :size="15" />
                                    <Crown v-else :size="15" />
                                    {{ activeSub && subCoversSlot(activeSub.slot_type, plan.slot_type || 'unlimited') ? 'Already subscribed' : 'Subscribe Now' }}
                                </template>
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Sticky Bottom Button -->
            <div class="fixed bottom-[72px] left-1/2 -translate-x-1/2 w-full max-w-[430px] bg-white border-t border-slate-100 px-4 py-3 z-40"
                style="box-shadow: 0 -4px 20px rgba(0,0,0,0.06)">

                <!-- Booking tab button -->
                <button v-if="activeTab === 'booking'"
                    @click="confirmBooking"
                    :disabled="!selectedSlots.length || !selectedDate || bookingLoading"
                    class="w-full bg-primary text-white font-bold py-4 rounded-2xl flex items-center justify-center gap-2 transition-all shadow-sm active:scale-95 disabled:opacity-50 disabled:scale-100">
                    <span v-if="bookingLoading" class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                    <span v-else-if="selectedSlots.length && selectedDate">
                        Confirm {{ selectedSlots.length > 1 ? selectedSlots.length + ' Slots' : 'Booking' }} · ₹{{ totalPrice }}
                    </span>
                    <span v-else>Select a date &amp; time slot</span>
                </button>

                <!-- Membership tab: Go back to booking when subscribed -->
                <button v-else-if="activeSub"
                    @click="activeTab = 'booking'"
                    class="w-full bg-primary text-white font-bold py-4 rounded-2xl flex items-center justify-center gap-2">
                    <Crown :size="17" />
                    Book a Slot (Member Access)
                </button>
            </div>
        </template>
    </div>

    <!-- Add Players Bottom Sheet ──────────────────────────────────────────── -->
    <Transition
        enter-active-class="transition duration-300 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-200 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0">
        <div v-if="addPlayers.show" class="fixed inset-0 bg-black/50 z-50 flex items-end" @click.self="submitPlayers">
            <div class="bg-white w-full rounded-t-3xl px-5 pt-5 pb-10 max-h-[90dvh] flex flex-col">

                <!-- Header -->
                <div class="flex items-center justify-between mb-1 shrink-0">
                    <div>
                        <p class="text-[10px] font-bold text-primary uppercase tracking-wider mb-0.5">Booking Confirmed!</p>
                        <h3 class="font-bold text-slate-900 text-base">Invite Players</h3>
                    </div>
                    <button @click="submitPlayers" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                        <X :size="16" class="text-slate-500" />
                    </button>
                </div>
                <!-- Slot info -->
                <p v-if="addPlayers.slotLabel" class="text-xs text-slate-400 mb-4 shrink-0">{{ court?.name }} · {{ addPlayers.slotLabel }}</p>
                <div v-else class="mb-4"></div>

                <!-- Scrollable body -->
                <div class="flex-1 overflow-y-auto scrollbar-hide space-y-5 min-h-0">

                    <!-- ① Regular players -->
                    <div class="shrink-0">
                        <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Regular Players</p>
                        <!-- Loading -->
                        <div v-if="addPlayers.regularsLoading" class="flex gap-3">
                            <div v-for="i in 4" :key="i" class="flex flex-col items-center gap-1.5 animate-pulse">
                                <div class="w-12 h-12 rounded-full bg-slate-100"></div>
                                <div class="w-10 h-2.5 rounded bg-slate-100"></div>
                            </div>
                        </div>
                        <!-- Players -->
                        <div v-else-if="addPlayers.regulars.length" class="flex gap-3 flex-wrap">
                            <button v-for="p in addPlayers.regulars" :key="p.id"
                                @click="toggleRegular(p)"
                                class="flex flex-col items-center gap-1 active:scale-90 transition-transform">
                                <div class="relative w-12 h-12 rounded-full flex items-center justify-center text-sm font-bold border-2 transition-all"
                                    :class="isSelected(p.id)
                                        ? 'bg-primary text-white border-primary'
                                        : 'bg-primary/10 text-primary border-transparent'">
                                    <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full rounded-full object-cover" />
                                    <span v-else>{{ p.name?.[0]?.toUpperCase() }}</span>
                                    <div v-if="isSelected(p.id)"
                                        class="absolute -top-1 -right-1 w-4 h-4 bg-primary rounded-full border-2 border-white flex items-center justify-center">
                                        <CheckCircle2 :size="10" class="text-white" />
                                    </div>
                                </div>
                                <span class="text-[10px] font-semibold text-slate-600 max-w-[48px] truncate">{{ p.name?.split(' ')[0] }}</span>
                            </button>
                        </div>
                        <p v-else class="text-xs text-slate-400 italic">No regulars found for this court yet</p>
                    </div>

                    <!-- ② Phone search -->
                    <div class="shrink-0">
                        <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Search by Phone</p>
                        <div class="flex gap-2">
                            <div class="flex-1 relative">
                                <input v-model="addPlayers.phone" @keyup.enter="searchPlayer"
                                    type="tel" placeholder="Enter phone number"
                                    class="input-field pr-10 w-full" maxlength="15" />
                                <Loader2 v-if="addPlayers.searching" :size="16"
                                    class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 animate-spin" />
                            </div>
                            <button @click="searchPlayer"
                                class="w-11 h-11 rounded-xl bg-primary flex items-center justify-center shrink-0 active:scale-95 transition-transform">
                                <Search :size="18" class="text-white" />
                            </button>
                        </div>
                        <!-- Result -->
                        <div v-if="addPlayers.searchResult"
                            class="mt-2 p-3 rounded-xl bg-slate-50 border border-slate-100 flex items-center gap-3">
                            <div class="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center shrink-0 text-sm font-bold text-primary">
                                {{ addPlayers.searchResult.name?.[0]?.toUpperCase() }}
                            </div>
                            <div class="flex-1 min-w-0">
                                <p class="font-semibold text-slate-800 text-sm truncate">{{ addPlayers.searchResult.name }}</p>
                                <p class="text-xs text-slate-400">{{ addPlayers.searchResult.phone }}</p>
                            </div>
                            <button @click="addPlayerToList(addPlayers.searchResult)"
                                class="flex items-center gap-1 text-xs font-bold px-3 py-1.5 rounded-lg bg-primary text-white active:scale-95 transition-transform">
                                <UserPlus :size="13" /> Add
                            </button>
                        </div>
                        <p v-else-if="addPlayers.notFound" class="text-xs text-slate-400 mt-2">No registered player found with that number</p>
                    </div>

                    <!-- ③ Selected list -->
                    <div v-if="addPlayers.selected.length" class="shrink-0">
                        <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">
                            Invited ({{ addPlayers.selected.length }})
                        </p>
                        <div class="space-y-2">
                            <div v-for="p in addPlayers.selected" :key="p.id"
                                class="flex items-center gap-3 p-2.5 rounded-xl bg-primary/5 border border-primary/10">
                                <div class="w-8 h-8 rounded-full bg-primary/15 flex items-center justify-center shrink-0 text-xs font-bold text-primary">
                                    <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full rounded-full object-cover" />
                                    <span v-else>{{ p.name?.[0]?.toUpperCase() }}</span>
                                </div>
                                <span class="flex-1 text-sm font-semibold text-slate-700 truncate">{{ p.name }}</span>
                                <button @click="removePlayer(p.id)"
                                    class="w-6 h-6 rounded-full bg-red-50 flex items-center justify-center active:scale-90 transition-transform">
                                    <X :size="11" class="text-red-400" />
                                </button>
                            </div>
                        </div>
                    </div>

                </div><!-- end scroll -->

                <!-- Actions -->
                <div class="flex gap-2 mt-4 shrink-0">
                    <!-- WhatsApp share -->
                    <button @click="shareWhatsApp"
                        class="flex items-center justify-center gap-1.5 px-4 py-3 rounded-xl bg-[#25D366]/10 text-[#25D366] font-bold text-sm active:scale-95 transition-transform shrink-0">
                        <svg class="w-4 h-4 fill-current" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/></svg>
                        Share
                    </button>
                    <button @click="submitPlayers" :disabled="addPlayers.submitting"
                        class="btn-primary flex-1 flex items-center justify-center gap-2 text-sm">
                        <Loader2 v-if="addPlayers.submitting" :size="15" class="animate-spin" />
                        <template v-else>
                            <UserPlus :size="15" />
                            {{ addPlayers.selected.length ? `Notify ${addPlayers.selected.length} Player${addPlayers.selected.length > 1 ? 's' : ''}` : 'Skip' }}
                        </template>
                    </button>
                </div>

            </div>
        </div>
    </Transition>

</template>
