<script setup>
// Matchday card, same five parts as kocourt_shared/lib/widgets/ko_card.dart:
// tinted ground, kicker + title + meta, one badge chip, up to three stats (or the default slot), one action.
import { computed } from 'vue'
import KoSportIcon from './KoSportIcon.vue'
import { sportKey, sportTint } from '@/utils/sport'

const props = defineProps({
  sport: { type: [String, null], default: null },
  kicker: { type: String, default: null },
  title: { type: String, required: true },
  meta: { type: String, default: null },
  badge: { type: String, default: null },
  stats: { type: Array, default: () => [] }, // [{ value, label }]
  action: { type: String, default: null },
  secondary: { type: Boolean, default: false },
})
const emit = defineEmits(['action'])

const hasSport = computed(() => !!sportKey(props.sport))
const colours = computed(() => (hasSport.value ? sportTint(props.sport) : { bg: '#F1EBFD', fg: '#6D28D9' }))
const shownStats = computed(() => props.stats.slice(0, 3))
</script>

<template>
  <div class="ko-card" :style="{ '--ko-tint': colours.bg, '--ko-tone': colours.fg }">
    <div class="flex items-start gap-3">
      <div class="min-w-0 flex-1">
        <div v-if="kicker" class="mb-1.5 flex items-center gap-1.5">
          <KoSportIcon v-if="hasSport" :type="sport" :size="16" tint="#ffffff" />
          <span class="truncate font-score text-[13px] font-bold uppercase tracking-[0.1em]" :style="{ color: colours.fg }">{{ kicker }}</span>
        </div>
        <h3 class="line-clamp-2 font-display text-xl font-extrabold leading-tight tracking-tight text-on-surface">{{ title }}</h3>
        <p v-if="meta" class="mt-0.5 line-clamp-2 text-[13px] text-on-surface-variant">{{ meta }}</p>
      </div>
      <slot name="badge">
        <span v-if="badge" class="shrink-0 rounded-[10px] bg-white px-2.5 py-1.5 font-score text-[21px] font-bold leading-none tabular-nums" :style="{ color: colours.fg }">{{ badge }}</span>
      </slot>
    </div>
    <div v-if="$slots.default" class="mt-3"><slot /></div>
    <div v-if="shownStats.length" class="mt-3 grid gap-2" :class="shownStats.length === 1 ? 'grid-cols-1' : shownStats.length === 2 ? 'grid-cols-2' : 'grid-cols-3'">
      <div v-for="s in shownStats" :key="s.label" class="min-w-0 rounded-xl border border-outline-variant bg-white p-2.5">
        <div class="truncate font-score text-[26px] font-bold leading-none tabular-nums text-on-surface">{{ s.value }}</div>
        <div class="mt-1 text-[11.5px] leading-tight text-on-surface-variant">{{ s.label }}</div>
      </div>
    </div>
    <button v-if="action" type="button" class="mt-3 w-full rounded-[14px] py-3.5 text-[15px] font-bold transition active:scale-[.99]"
            :class="secondary ? 'border border-outline-variant bg-white text-primary' : 'bg-primary text-on-primary'"
            @click.stop="emit('action')">{{ action }}</button>
  </div>
</template>

<style scoped>
.ko-card {
  border-radius: 20px;
  padding: 16px;
  border: 1px solid theme('colors.outline-variant');
  background: linear-gradient(160deg, var(--ko-tint), #fff 70%);
}
</style>
