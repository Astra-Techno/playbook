<script setup>
// "When are you playing?" chips; the choice is shared across pages (utils/playTime.js).
import { PLAY_TIMES, playTime } from '@/utils/playTime'
</script>

<template>
  <div class="flex gap-2 overflow-x-auto scrollbar-hide" role="group" aria-label="When are you playing">
    <button v-for="t in PLAY_TIMES" :key="t.id" type="button" :aria-pressed="playTime === t.id"
      class="shrink-0 rounded-full border px-3.5 py-2 text-[14px] font-bold transition-colors"
      :class="playTime === t.id ? 'border-primary bg-primary text-on-primary' : 'border-outline-variant bg-white text-on-surface'"
      @click="playTime = t.id">{{ t.label }}</button>
  </div>
</template>
