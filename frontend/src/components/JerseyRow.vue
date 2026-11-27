<script setup>
// Matchday squad row, same as kocourt_shared/lib/widgets/jersey_row.dart:
// initials on jersey plates, open spots dashed, "+n" for the rest, optional note.
import { computed } from 'vue'

const props = defineProps({
  names: { type: Array, default: () => [] },
  open: { type: Number, default: 0 },
  tone: { type: String, default: '#6D28D9' },
  note: { type: String, default: null },
  max: { type: Number, default: 6 },
})
const initials = (name) => {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  const first = parts[0][0].toUpperCase()
  return parts.length === 1 ? first : first + parts[parts.length - 1][0].toUpperCase()
}
const shown = computed(() => props.names.slice(0, props.max))
const shownOpen = computed(() => Math.max(0, Math.min(props.open, props.max - shown.value.length)))
const hidden = computed(() => props.names.length - shown.value.length + (props.open - shownOpen.value))
const label = computed(() => `${props.names.length} in the squad${props.open > 0 ? `, ${props.open} open` : ''}`)
</script>

<template>
  <div class="flex flex-wrap items-center gap-1.5" role="img" :aria-label="label">
    <span v-for="(n, i) in shown" :key="i" class="grid h-[34px] w-[34px] place-items-center rounded-[10px] border border-outline-variant bg-white font-score text-[15px] font-bold" :style="{ color: tone }">{{ initials(n) }}</span>
    <span v-for="i in shownOpen" :key="'o' + i" class="grid h-[34px] w-[34px] place-items-center rounded-[10px] border-[1.5px] border-dashed border-outline font-bold text-outline">+</span>
    <span v-if="hidden > 0" class="grid h-[34px] w-[34px] place-items-center rounded-[10px] border border-outline-variant bg-white font-score text-[14px] font-bold text-on-surface-variant">+{{ hidden }}</span>
    <span v-if="note" class="ml-0.5 text-[12.5px] text-on-surface-variant">{{ note }}</span>
  </div>
</template>
