<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import {
    ChevronLeft, ChevronRight, CalendarDays, Loader2,
    Plus, Ban, X, RefreshCw
} from 'lucide-vue-next'
import BookingDetailSheet from '../components/BookingDetailSheet.vue'
import BlockDetailSheet   from '../components/BlockDetailSheet.vue'

// ── Layout constants ────────────────────────────────────────────────────────
const HOUR_HEIGHT = 64     // px per 1-hour row
const TIME_COL_W  = 48     // px — sticky time label column

// ── Route / state ───────────────────────────────────────────────────────────
const route   = useRoute()
const router  = useRouter()
const toast   = useToastStore()

const courtId = computed(() => Number(route.params.id))

const todayStr = () => new Date().toISOString().slice(0, 10)

const view       = ref('day')            // 'day' | 'week'
const activeDate = ref(todayStr())
const filterSpaceId = ref(null)          // null = all spaces

const calendarData  = ref(null)
const loading       = ref(false)

const bookingDetail = ref({ show: false, booking: null })
const blockDetail   = ref({ show: false, block: null })
const cellSheet     = ref({ show: false, hour: null, spaceId: null })

const timelineRef = ref(null)
const dateInputRef = ref(null)

// Screen width for responsive column sizing
const screenW = ref(typeof window !== 'undefined' ? window.innerWidth : 390)
const onResize = () => { screenW.value = window.innerWidth }
onMounted(() => window.addEventListener('resize', onResize))
onUnmounted(() => window.removeEventListener('resize', onResize))

// ── Column width (responsive) ────────────────────────────────────────────────
const colWidth = computed(() => {
    const n = visibleSpaces.value.length || 1
    const available = screenW.value - TIME_COL_W
    return Math.max(130, Math.floor(available / n))
})

// ── Computed from API data ───────────────────────────────────────────────────
const court      = computed(() => calendarData.value?.court ?? null)
const subCourts  = computed(() => calendarData.value?.sub_courts ?? [])

const openHour  = computed(() => {
    const t = court.value?.open_time ?? '06:00:00'
    return parseInt(t.split(':')[0])
})
const closeHour = computed(() => {
    const t = court.value?.close_time ?? '22:00:00'
    return parseInt(t.split(':')[0])
})
const hoursList = computed(() => {
    const list = []
    for (let h = openHour.value; h < closeHour.value; h++) list.push(h)
    return list
})

const visibleSpaces = computed(() => {
    const spaces = subCourts.value
    if (!spaces.length) return [{ id: null, name: court.value?.name ?? 'Venue' }]
    if (!filterSpaceId.value) return spaces
    return spaces.filter(s => String(s.id) === String(filterSpaceId.value))
})

// ── Time helpers ─────────────────────────────────────────────────────────────
const parseToMins = (dtStr) => {
    if (!dtStr) return 0
    const t = dtStr.includes(' ') ? dtStr.split(' ')[1] : dtStr
    const [h, m] = t.split(':').map(Number)
    return h * 60 + (m || 0)
}
const minutesFromOpen = (dtStr) => parseToMins(dtStr) - openHour.value * 60

const formatHour = (h) => {
    const suffix = h >= 12 ? 'PM' : 'AM'
    return `${h % 12 || 12}${suffix}`
}
const shortTime = (dtStr) => {
    if (!dtStr) return ''
    const t = dtStr.includes(' ') ? dtStr.split(' ')[1] : dtStr
    const [h, m] = t.split(':').map(Number)
    const suffix = h >= 12 ? 'PM' : 'AM'
    return `${h % 12 || 12}:${String(m).padStart(2,'0')}${suffix}`
}

const formatNavDate = (iso) => {
    const d = new Date(iso + 'T00:00:00')
    const today = todayStr()
    const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10)
    if (iso === today)    return 'Today'
    if (iso === tomorrow) return 'Tomorrow'
    return d.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })
}

const formatDayLabel = (iso) => {
    const d = new Date(iso + 'T00:00:00')
    return { dow: d.toLocaleDateString('en-IN', { weekday: 'short' }).toUpperCase(), day: d.getDate() }
}

// ── Block layout helpers ─────────────────────────────────────────────────────
const eventStyle = (item, colIdx) => {
    const startMins = minutesFromOpen(item.start_time)
    const endMins   = minutesFromOpen(item.end_time)
    const top    = Math.max(0, startMins / 60 * HOUR_HEIGHT) + 2
    const height = Math.max((endMins - startMins) / 60 * HOUR_HEIGHT - 4, 22)
    const left   = TIME_COL_W + colIdx * colWidth.value + 3
    const width  = colWidth.value - 6
    return `position:absolute;top:${top}px;height:${height}px;left:${left}px;width:${width}px;z-index:10;`
}

const venueWideBlockStyle = (bl) => {
    const startMins = minutesFromOpen(bl.start_time)
    const endMins   = minutesFromOpen(bl.end_time)
    const top    = Math.max(0, startMins / 60 * HOUR_HEIGHT) + 2
    const height = Math.max((endMins - startMins) / 60 * HOUR_HEIGHT - 4, 22)
    const left   = TIME_COL_W + 3
    const width  = visibleSpaces.value.length * colWidth.value - 6
    return `position:absolute;top:${top}px;height:${height}px;left:${left}px;width:${width}px;z-index:11;`
}

// ── Booking / block filters per space column ─────────────────────────────────
const bookingsForSpace = (spaceId) => {
    const all = calendarData.value?.bookings ?? []
    if (spaceId === null) return all
    return all.filter(b => String(b.sub_court_id) === String(spaceId))
}

// Space-specific blocks per column (venue-wide handled separately as overlay)
const spaceOnlyBlocks = (spaceId) => {
    const all = calendarData.value?.blocked_slots ?? []
    if (spaceId === null) return all
    return all.filter(b => b.sub_court_id !== null && String(b.sub_court_id) === String(spaceId))
}

// Venue-wide blocks — rendered once spanning all columns
const venueWideBlocks = computed(() => {
    if (visibleSpaces.value.length <= 1) return []
    return (calendarData.value?.blocked_slots ?? []).filter(b => b.sub_court_id === null)
})

// When single column is visible, merge venue-wide blocks into it
const singleColBlocks = (spaceId) => {
    if (visibleSpaces.value.length > 1) return spaceOnlyBlocks(spaceId)
    const all = calendarData.value?.blocked_slots ?? []
    if (spaceId === null) return all
    return all.filter(b => b.sub_court_id === null || String(b.sub_court_id) === String(spaceId))
}

// ── Booking style ─────────────────────────────────────────────────────────────
const bookingClass = (status) => {
    if (status === 'confirmed') return 'bg-emerald-500 text-white shadow-sm shadow-emerald-200'
    if (status === 'pending')   return 'bg-amber-400 text-white shadow-sm shadow-amber-200'
    return 'bg-slate-200 text-slate-400 opacity-60'
}

// ── Current time indicator ────────────────────────────────────────────────────
const currentTimeTop = computed(() => {
    if (!calendarData.value || activeDate.value !== todayStr()) return null
    const now = new Date()
    const mins = (now.getHours() - openHour.value) * 60 + now.getMinutes()
    if (mins < 0 || mins > (closeHour.value - openHour.value) * 60) return null
    return (mins / 60) * HOUR_HEIGHT
})

// ── Week view helpers ─────────────────────────────────────────────────────────
const weekDates = computed(() => {
    return (calendarData.value?.dates ?? []).map(iso => {
        const count = (calendarData.value?.bookings ?? []).filter(b => b.start_time.startsWith(iso)).length
        const blockCount = (calendarData.value?.blocked_slots ?? []).filter(b => b.start_time.startsWith(iso)).length
        return { iso, ...formatDayLabel(iso), count, blockCount }
    })
})

const spaceNameById = (id) => {
    if (!id) return ''
    return subCourts.value.find(s => String(s.id) === String(id))?.name ?? ''
}

const weekBookingsByDate = computed(() => {
    const dates = calendarData.value?.dates ?? []
    return dates.map(d => ({
        date: d,
        label: formatNavDate(d),
        bookings: (calendarData.value?.bookings ?? []).filter(b => b.start_time.startsWith(d)),
        blocks:   (calendarData.value?.blocked_slots ?? []).filter(b => b.start_time.startsWith(d)),
    })).filter(g => g.bookings.length > 0 || g.blocks.length > 0)
})

// ── Fetch ────────────────────────────────────────────────────────────────────
const fetchCalendar = async () => {
    if (!courtId.value) return
    loading.value = true
    try {
        const res = await axios.get(`/courts/${courtId.value}/calendar`, {
            params: { date: activeDate.value, view: view.value }
        })
        calendarData.value = res.data
    } catch {
        toast.error('Failed to load calendar')
    } finally {
        loading.value = false
        if (view.value === 'day') scrollToNow()
    }
}

const scrollToNow = () => {
    nextTick(() => {
        if (!timelineRef.value) return
        const now = new Date()
        const targetHour = activeDate.value === todayStr()
            ? Math.max(now.getHours() - 1, openHour.value)
            : openHour.value
        timelineRef.value.scrollTop = (targetHour - openHour.value) * HOUR_HEIGHT
    })
}

onMounted(() => {
    // Pre-filter by space if query param provided
    if (route.query.space) filterSpaceId.value = Number(route.query.space)
    fetchCalendar()
})

watch([activeDate, view], fetchCalendar)

// ── Navigation ────────────────────────────────────────────────────────────────
const shiftDate = (delta) => {
    const d = new Date(activeDate.value + 'T00:00:00')
    d.setDate(d.getDate() + (view.value === 'week' ? delta * 7 : delta))
    activeDate.value = d.toISOString().slice(0, 10)
}

const openDatePicker = () => {
    if (dateInputRef.value) {
        try { dateInputRef.value.showPicker() }
        catch { dateInputRef.value.click() }
    }
}

// ── Cell tap → action sheet ───────────────────────────────────────────────────
const handleCellTap = (hour, spaceId) => {
    cellSheet.value = { show: true, hour, spaceId }
}

const goToBlockSlots = () => {
    const { spaceId } = cellSheet.value
    cellSheet.value.show = false
    if (spaceId) router.push(`/my-venues/${courtId.value}/spaces/${spaceId}/block`)
    else         router.push(`/my-venues/${courtId.value}/block`)
}

const goToBookings = () => {
    const { spaceId } = cellSheet.value
    cellSheet.value.show = false
    if (spaceId) router.push(`/my-venues/${courtId.value}/spaces/${spaceId}/bookings`)
    else         router.push(`/my-venues/${courtId.value}/spaces`)
}

// ── Booking detail ────────────────────────────────────────────────────────────
const openBookingDetail = (b) => { bookingDetail.value = { show: true, booking: b } }

const onBookingCancelled = (id) => {
    if (!calendarData.value?.bookings) return
    const b = calendarData.value.bookings.find(x => x.id === id)
    if (b) b.status = 'cancelled'
}

// ── Block detail ──────────────────────────────────────────────────────────────
const openBlockDetail = (bl) => { blockDetail.value = { show: true, block: bl } }

const onUnblocked = (id) => {
    if (!calendarData.value?.blocked_slots) return
    calendarData.value.blocked_slots = calendarData.value.blocked_slots.filter(b => b.id !== id)
}
</script>

<template>
    <!-- Header teleport -->
    <Teleport to="#header-subject">{{ court?.name ?? 'Calendar' }}</Teleport>
    <Teleport to="#header-subtitle">Booking Calendar</Teleport>

    <div class="bg-slate-50 flex flex-col" style="height: calc(100vh - 120px)">

        <!-- ── Sticky control bar ──────────────────────────────────────── -->
        <div class="bg-white border-b border-slate-100 shrink-0">

            <!-- View toggle + date nav -->
            <div class="flex items-center gap-2 px-4 py-2.5">
                <!-- Day / Week toggle -->
                <div class="flex bg-slate-100 rounded-xl p-0.5 shrink-0">
                    <button @click="view='day'"
                        class="px-3 py-1.5 rounded-lg text-[11px] font-bold transition-all"
                        :class="view==='day' ? 'bg-white shadow-sm text-slate-900' : 'text-slate-500'">
                        Day
                    </button>
                    <button @click="view='week'"
                        class="px-3 py-1.5 rounded-lg text-[11px] font-bold transition-all"
                        :class="view==='week' ? 'bg-white shadow-sm text-slate-900' : 'text-slate-500'">
                        Week
                    </button>
                </div>

                <!-- Prev -->
                <button @click="shiftDate(-1)"
                    class="w-8 h-8 bg-slate-100 rounded-full flex items-center justify-center shrink-0 active:scale-90 transition-transform">
                    <ChevronLeft :size="15" class="text-slate-600" />
                </button>

                <!-- Date label (tappable) -->
                <button @click="openDatePicker" class="flex-1 text-center">
                    <span class="text-sm font-bold text-slate-800">{{ formatNavDate(activeDate) }}</span>
                </button>

                <!-- Hidden native date picker -->
                <input ref="dateInputRef" type="date" :value="activeDate"
                    @change="activeDate = $event.target.value"
                    class="sr-only" />

                <!-- Next -->
                <button @click="shiftDate(1)"
                    class="w-8 h-8 bg-slate-100 rounded-full flex items-center justify-center shrink-0 active:scale-90 transition-transform">
                    <ChevronRight :size="15" class="text-slate-600" />
                </button>

                <!-- Today -->
                <button @click="activeDate = todayStr()"
                    class="shrink-0 text-[11px] font-bold text-primary bg-primary/10 px-2.5 py-1.5 rounded-lg active:scale-95 transition-transform"
                    :class="activeDate === todayStr() ? 'opacity-40 pointer-events-none' : ''">
                    Today
                </button>
            </div>

            <!-- Space filter chips (only if multiple spaces) -->
            <div v-if="subCourts.length > 1"
                class="flex gap-2 px-4 pb-3 overflow-x-auto scrollbar-hide">
                <button @click="filterSpaceId = null"
                    class="shrink-0 px-3 py-1.5 rounded-full text-xs font-bold transition-all"
                    :class="!filterSpaceId ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'">
                    All
                </button>
                <button v-for="sp in subCourts" :key="sp.id"
                    @click="filterSpaceId = sp.id"
                    class="shrink-0 px-3 py-1.5 rounded-full text-xs font-bold transition-all"
                    :class="String(filterSpaceId) === String(sp.id) ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600'">
                    {{ sp.name }}
                </button>
            </div>
        </div>

        <!-- ── Loading ──────────────────────────────────────────────────── -->
        <div v-if="loading" class="flex-1 flex items-center justify-center">
            <Loader2 :size="32" class="text-primary animate-spin" />
        </div>

        <!-- ── WEEK VIEW ────────────────────────────────────────────────── -->
        <template v-else-if="view === 'week'">
            <!-- 7-day chips -->
            <div class="bg-white border-b border-slate-100 shrink-0">
                <div class="flex px-2 py-2 gap-1.5">
                    <button v-for="d in weekDates" :key="d.iso"
                        @click="activeDate = d.iso; view = 'day'"
                        class="flex-1 flex flex-col items-center py-2 rounded-xl transition-all active:scale-95"
                        :class="d.iso === activeDate
                            ? 'bg-primary text-white'
                            : d.iso === todayStr()
                                ? 'bg-primary/10 text-primary ring-1 ring-primary/20'
                                : 'bg-slate-50 text-slate-700'">
                        <span class="text-[9px] font-bold uppercase tracking-wide leading-none mb-1">{{ d.dow }}</span>
                        <span class="text-base font-extrabold leading-none">{{ d.day }}</span>
                        <div class="mt-1 h-1.5 flex items-center gap-0.5">
                            <span v-if="d.count"
                                class="w-1.5 h-1.5 rounded-full"
                                :class="d.iso === activeDate ? 'bg-white/70' : 'bg-emerald-500'">
                            </span>
                            <span v-if="d.blockCount"
                                class="w-1.5 h-1.5 rounded-full"
                                :class="d.iso === activeDate ? 'bg-white/50' : 'bg-red-400'">
                            </span>
                        </div>
                    </button>
                </div>
            </div>

            <!-- Week booking list -->
            <div class="flex-1 overflow-y-auto px-4 py-3 space-y-4 pb-8">
                <div v-if="weekBookingsByDate.length === 0"
                    class="flex flex-col items-center py-16 text-center">
                    <CalendarDays :size="40" class="text-slate-200 mb-3" />
                    <p class="font-bold text-slate-500">No bookings this week</p>
                    <p class="text-xs text-slate-400 mt-1">Tap a day to see the full schedule</p>
                </div>

                <template v-for="group in weekBookingsByDate" :key="group.date">
                    <div>
                        <p class="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest mb-2">
                            {{ group.label }}
                        </p>
                        <!-- Bookings -->
                        <div class="space-y-2">
                            <button v-for="b in group.bookings" :key="b.id"
                                @click="openBookingDetail(b)"
                                class="w-full flex items-center gap-3 bg-white rounded-2xl px-4 py-3 shadow-sm ring-1 ring-slate-100 active:scale-[0.98] transition-transform text-left">
                                <!-- Status dot -->
                                <div class="w-2.5 h-2.5 rounded-full shrink-0"
                                    :class="b.status==='confirmed' ? 'bg-emerald-500' : b.status==='pending' ? 'bg-amber-400' : 'bg-slate-300'">
                                </div>
                                <div class="flex-1 min-w-0">
                                    <p class="text-sm font-bold text-slate-900 truncate">{{ b.guest_name || b.user_name || 'Player' }}</p>
                                    <p class="text-xs text-slate-400">{{ shortTime(b.start_time) }} – {{ shortTime(b.end_time) }}
                                        <span v-if="spaceNameById(b.sub_court_id)"> · {{ spaceNameById(b.sub_court_id) }}</span>
                                    </p>
                                </div>
                                <span class="text-[10px] font-bold px-2 py-1 rounded-full"
                                    :class="b.status==='confirmed' ? 'bg-emerald-100 text-emerald-700' : b.status==='pending' ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-500'">
                                    {{ b.status }}
                                </span>
                            </button>
                            <!-- Blocked slots -->
                            <button v-for="bl in group.blocks" :key="`bl-${bl.id}`"
                                @click="openBlockDetail(bl)"
                                class="w-full flex items-center gap-3 bg-red-50 rounded-2xl px-4 py-3 ring-1 ring-red-100 active:scale-[0.98] transition-transform text-left">
                                <div class="w-2.5 h-2.5 rounded-full shrink-0 bg-red-400"></div>
                                <div class="flex-1 min-w-0">
                                    <p class="text-sm font-bold text-red-700 truncate">{{ bl.reason || 'Blocked' }}</p>
                                    <p class="text-xs text-red-400">{{ shortTime(bl.start_time) }} – {{ shortTime(bl.end_time) }}</p>
                                </div>
                                <span class="text-[10px] font-bold text-red-500">Block</span>
                            </button>
                        </div>
                    </div>
                </template>
            </div>
        </template>

        <!-- ── DAY VIEW ─────────────────────────────────────────────────── -->
        <div v-else-if="calendarData" class="flex-1 overflow-hidden">

            <!-- No data empty state -->
            <div v-if="!court" class="flex flex-col items-center justify-center h-full text-center px-8">
                <CalendarDays :size="40" class="text-slate-200 mb-3" />
                <p class="font-bold text-slate-500">No data available</p>
                <button @click="fetchCalendar" class="mt-4 flex items-center gap-2 text-sm font-bold text-primary bg-primary/10 px-4 py-2 rounded-xl active:scale-95 transition-transform">
                    <RefreshCw :size="14" /> Retry
                </button>
            </div>

            <!-- Timeline -->
            <div v-else class="overflow-x-auto overflow-y-auto h-full" ref="timelineRef">
                <div class="relative"
                     :style="`min-width: ${TIME_COL_W + visibleSpaces.length * colWidth}px`">

                    <!-- ── Sticky column headers ── -->
                    <div class="sticky top-0 z-20 flex bg-white border-b border-slate-100 shadow-sm">
                        <!-- Time gutter header -->
                        <div :style="`width:${TIME_COL_W}px;min-width:${TIME_COL_W}px`"
                             class="sticky left-0 z-30 bg-white shrink-0 h-11 border-r border-slate-100"></div>
                        <!-- Space headers -->
                        <div v-for="sp in visibleSpaces" :key="`hdr-${sp.id}`"
                             :style="`width:${colWidth}px;min-width:${colWidth}px`"
                             class="shrink-0 h-11 flex items-center justify-center border-r border-slate-100 px-2">
                            <span class="text-xs font-bold text-slate-700 truncate">{{ sp.name }}</span>
                        </div>
                    </div>

                    <!-- ── Grid rows (background) + overlay blocks ── -->
                    <div class="relative">
                        <!-- Hour rows -->
                        <div v-for="h in hoursList" :key="h"
                             class="flex border-b border-slate-50"
                             :style="`height:${HOUR_HEIGHT}px`">
                            <!-- Sticky time label -->
                            <div :style="`width:${TIME_COL_W}px;min-width:${TIME_COL_W}px`"
                                 class="sticky left-0 z-10 bg-white shrink-0 flex items-start
                                        justify-end pr-2 pt-1.5 border-r border-slate-100">
                                <span class="text-[10px] font-semibold text-slate-400 leading-none">{{ formatHour(h) }}</span>
                            </div>
                            <!-- Tappable cells -->
                            <div v-for="sp in visibleSpaces" :key="`cell-${h}-${sp.id}`"
                                 :style="`width:${colWidth}px;min-width:${colWidth}px`"
                                 class="shrink-0 border-r border-slate-50 cursor-pointer
                                        transition-colors active:bg-primary/5 hover:bg-slate-50/80"
                                 @click="handleCellTap(h, sp.id)">
                            </div>
                        </div>

                        <!-- ── Current time line ── -->
                        <div v-if="currentTimeTop !== null"
                             class="absolute pointer-events-none z-20 flex items-center"
                             :style="`top:${currentTimeTop}px;left:0;right:0`">
                            <div :style="`width:${TIME_COL_W}px`" class="shrink-0 flex justify-end pr-1">
                                <div class="w-2 h-2 rounded-full bg-red-500 ring-2 ring-white"></div>
                            </div>
                            <div class="flex-1 h-px bg-red-400 opacity-80"></div>
                        </div>

                        <!-- ── Per-column: bookings + space-specific blocks ── -->
                        <template v-for="(sp, colIdx) in visibleSpaces" :key="`col-${sp.id}`">
                            <!-- Bookings -->
                            <div v-for="b in bookingsForSpace(sp.id)" :key="`b-${b.id}-${sp.id}`"
                                 :style="eventStyle(b, colIdx)"
                                 class="absolute rounded-xl px-2 py-1 overflow-hidden cursor-pointer
                                        select-none active:opacity-75 transition-opacity"
                                 :class="bookingClass(b.status)"
                                 @click.stop="openBookingDetail(b)">
                                <p class="text-[10px] font-extrabold truncate leading-tight">
                                    {{ b.guest_name || b.user_name || 'Player' }}
                                </p>
                                <p class="text-[9px] opacity-80 truncate leading-tight mt-0.5">
                                    {{ shortTime(b.start_time) }}–{{ shortTime(b.end_time) }}
                                </p>
                            </div>
                            <!-- Space-specific blocks -->
                            <div v-for="bl in singleColBlocks(sp.id)" :key="`bl-${bl.id}-${sp.id}`"
                                 :style="eventStyle(bl, colIdx)"
                                 class="absolute rounded-xl px-2 py-1 overflow-hidden cursor-pointer
                                        select-none active:opacity-75 transition-opacity
                                        blocked-hatch border border-red-200"
                                 @click.stop="openBlockDetail(bl)">
                                <p class="text-[9px] font-bold text-red-700 truncate leading-tight">
                                    {{ bl.reason || 'Blocked' }}
                                </p>
                            </div>
                        </template>

                        <!-- ── Venue-wide blocks (span all columns) ── -->
                        <div v-for="bl in venueWideBlocks" :key="`vw-${bl.id}`"
                             :style="venueWideBlockStyle(bl)"
                             class="absolute rounded-xl px-2 py-1 overflow-hidden cursor-pointer
                                    select-none active:opacity-75 transition-opacity
                                    blocked-hatch border border-red-200"
                             @click.stop="openBlockDetail(bl)">
                            <p class="text-[9px] font-bold text-red-700 truncate leading-tight">
                                {{ bl.reason || 'Venue blocked' }}
                            </p>
                        </div>

                    </div><!-- /relative rows container -->
                </div><!-- /min-width container -->
            </div><!-- /overflow scroll -->
        </div><!-- /day view -->

    </div><!-- /outer flex col -->

    <!-- ── FAB: Add action ─────────────────────────────────────────────── -->
    <div class="fixed bottom-20 right-4 z-30 flex flex-col gap-2 items-end">
        <button @click="router.push(`/my-venues/${courtId}/block`)"
            class="flex items-center gap-2 bg-white text-slate-700 font-bold text-xs px-4 py-2.5
                   rounded-full shadow-lg ring-1 ring-slate-200 active:scale-95 transition-transform">
            <Ban :size="14" class="text-red-500" />
            Block Slots
        </button>
        <button @click="router.push(subCourts.length ? `/my-venues/${courtId}/spaces` : `/my-venues/${courtId}/spaces`)"
            class="w-14 h-14 bg-primary text-white rounded-full shadow-lg shadow-primary/30
                   flex items-center justify-center active:scale-95 transition-transform">
            <Plus :size="22" />
        </button>
    </div>

    <!-- ── Cell action sheet ───────────────────────────────────────────── -->
    <Teleport to="#app-root">
        <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0" enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100" leave-to-class="opacity-0">
            <div v-if="cellSheet.show" class="absolute inset-0 bg-black/40 z-[200]"
                 @click.self="cellSheet.show = false">
                <Transition
                    enter-active-class="transition duration-300 ease-out"
                    enter-from-class="translate-y-full" enter-to-class="translate-y-0"
                    leave-active-class="transition duration-200 ease-in"
                    leave-from-class="translate-y-0" leave-to-class="translate-y-full">
                    <div v-if="cellSheet.show"
                         class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl px-5 pt-4 pb-10">
                        <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-5"></div>
                        <p class="text-xs font-bold text-slate-400 uppercase tracking-widest mb-4 text-center">
                            {{ formatHour(cellSheet.hour) }} slot
                        </p>
                        <div class="space-y-3">
                            <button @click="goToBookings"
                                class="w-full flex items-center gap-3 bg-primary text-white font-bold
                                       py-4 px-5 rounded-2xl active:scale-[0.98] transition-transform">
                                <Plus :size="18" />
                                <span>Add Walk-in Booking</span>
                            </button>
                            <button @click="goToBlockSlots"
                                class="w-full flex items-center gap-3 bg-red-50 text-red-700 font-bold
                                       py-4 px-5 rounded-2xl active:scale-[0.98] transition-transform">
                                <Ban :size="18" />
                                <span>Block This Slot</span>
                            </button>
                            <button @click="cellSheet.show = false"
                                class="w-full flex items-center justify-center gap-2 bg-slate-100
                                       text-slate-600 font-bold py-3.5 rounded-2xl active:scale-[0.98] transition-transform">
                                <X :size="16" />
                                Cancel
                            </button>
                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>

    <!-- ── Booking detail sheet ────────────────────────────────────────── -->
    <BookingDetailSheet
        v-model="bookingDetail.show"
        :booking="bookingDetail.booking"
        :space-name="spaceNameById(bookingDetail.booking?.sub_court_id)"
        @cancelled="onBookingCancelled"
    />

    <!-- ── Block detail sheet ──────────────────────────────────────────── -->
    <BlockDetailSheet
        v-model="blockDetail.show"
        :block="blockDetail.block"
        @unblocked="onUnblocked"
    />
</template>
