<script setup>
// Matchday availability strip, same look as the app's DayStrip: one bar per hour from 6 AM.
import { computed } from 'vue'
import { hourLabel } from '@/utils/playTime'

const props = defineProps({
  strip: { type: String, required: true },
  tone: { type: String, default: '#047857' },
  highlight: { type: Number, default: null },
  date: { type: String, default: null },
  firstHour: { type: Number, default: 6 },
})

const pastBefore = computed(() => {
  const now = new Date()
  const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
  if (props.date === today) return now.getHours() + 1
  return props.date && props.date < today ? 99 : 0
})
const bars = computed(() => [...props.strip].map((s, i) => {
  const hour = props.firstHour + i
  return { hour, state: s, gone: hour < pastBefore.value || s === 'c' }
}))
const summary = computed(() => {
  const free = bars.value.filter((b) => (b.state === 'f' || b.state === 'p') && !b.gone).map((b) => hourLabel(b.hour))
  return free.length ? `Free at ${free.slice(0, 4).join(', ')}${free.length > 4 ? ' and more' : ''}` : 'No free hours'
})
const color = (s) => (s === 'f' ? props.tone : s === 'p' ? '#F59E0B' : '#D9D4E6')
const axis = computed(() => [props.firstHour, 12, 18, props.firstHour + props.strip.length - 1].map((h) => hourLabel(h).replace(' ', '').replace('M', '')))
</script>

<template>
  <div role="img" :aria-label="summary">
    <div class="flex h-6 items-end gap-[2px]">
      <i v-for="b in bars" :key="b.hour" class="block flex-1 rounded-[2px]"
        :style="{
          height: b.state === 't' || b.state === 'c' ? '55%' : '100%',
          background: color(b.state),
          opacity: b.gone ? 0.3 : 1,
          outline: b.hour === highlight ? '2px solid #6D28D9' : 'none',
          outlineOffset: '1px',
        }" />
    </div>
    <div class="mt-1 flex justify-between font-score text-[11px] font-semibold text-outline">
      <span v-for="a in axis" :key="a">{{ a }}</span>
    </div>
  </div>
</template>
