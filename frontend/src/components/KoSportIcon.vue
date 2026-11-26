<script setup>
// Matchday sport icon (same SVGs as the apps). Unknown sports render nothing.
import { computed } from 'vue'
import { sportSvg, sportTint } from '@/utils/sport'

const props = defineProps({
  type: { type: [String, null], default: null },
  size: { type: Number, default: 24 },
  tone: { type: String, default: null },
  tint: { type: String, default: null },
})
const svg = computed(() => sportSvg(props.type))
const style = computed(() => {
  const t = sportTint(props.type)
  return { width: `${props.size}px`, height: `${props.size}px`, '--tone': props.tone ?? t.fg, '--tint': props.tint ?? t.bg, '--surface': '#fff' }
})
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -- bundled SVG from kocourt_shared, never user data -->
  <span v-if="svg" class="ko-sport-icon" :style="style" aria-hidden="true" v-html="svg" />
</template>

<style scoped>
.ko-sport-icon { display: inline-block; flex: none; line-height: 0; }
.ko-sport-icon :deep(svg) { width: 100%; height: 100%; }
</style>
