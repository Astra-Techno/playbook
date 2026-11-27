<script setup>
// Matchday "Your crew" (GET /players/crew), same as the app's crew_card.dart.
// Rebook opens the venue page with the same day/time/space picked and re-adds the squad after payment.
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import { useRouter } from 'vue-router'
import KoCard from './KoCard.vue'
import JerseyRow from './JerseyRow.vue'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth = useAuthStore()
const mates = ref([])
const rebook = ref(null)

onMounted(async () => {
  if (!auth.isLoggedIn) return
  try {
    const res = await axios.get('/players/crew')
    mates.value = res.data?.mates || []
    rebook.value = res.data?.rebook || null
  } catch { /* optional card */ }
})

const parse = (dt) => { const [d, t] = String(dt).split(' '); return new Date(`${d}T${t || '00:00:00'}`) }
const slotDay = (dt) => {
  const d = parse(dt)
  const h = d.getHours()
  const time = d.getMinutes() === 0 ? `${h % 12 === 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}` : d.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit', hour12: true }).toUpperCase()
  return `${d.toLocaleDateString('en-IN', { weekday: 'short' })} ${time}`
}
const crewWith = (names) => {
  if (!names?.length) return ''
  const first = (n) => String(n).trim().split(/\s+/)[0]
  if (names.length === 1) return `with ${first(names[0])}`
  if (names.length === 2) return `with ${first(names[0])} and ${first(names[1])}`
  return `with ${first(names[0])} +${names.length - 1}`
}
const games = computed(() => mates.value.reduce((sum, m) => sum + (Number(m.games) || 0), 0))

const doRebook = () => {
  const r = rebook.value
  const s = parse(r.start_time)
  const e = parse(r.end_time)
  router.push({
    path: `/courts/${r.court_id}`,
    query: {
      date: r.start_time.slice(0, 10),
      start: s.getHours(),
      end: e.getHours() + (e.getMinutes() > 0 ? 1 : 0),
      ...(r.sub_court_id ? { space: r.sub_court_id } : {}),
      squad: (r.player_ids || []).join(','),
    },
  })
}
</script>

<template>
  <KoCard v-if="mates.length"
    kicker="Your crew"
    :title="rebook ? rebook.court_name : `${mates.length} people you play with`"
    :meta="rebook ? `Usually ${slotDay(rebook.start_time)} · ${crewWith(rebook.player_names)}` : 'From your last 6 months of games'"
    :badge="`×${games}`"
    :action="rebook ? `Rebook ${slotDay(rebook.start_time)} · same squad` : null"
    @action="doRebook">
    <JerseyRow :names="mates.map((m) => m.name)" />
  </KoCard>
</template>
