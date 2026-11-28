<script setup>
import { rupees } from '../utils/format'
// "Add kit?" before paying — same rules as the app's addons_sheet.dart.
// The server prices the kit; the totals here are an estimate.
import { ref, computed, watch } from 'vue'

const props = defineProps({
  open: { type: Boolean, default: false },
  addons: { type: Array, default: () => [] }, // [{ id, name, rental_rupees, deposit_rupees }]
})
const emit = defineEmits(['done']) // counts object { [id]: qty }, or null when closed

const counts = ref({})
watch(() => props.open, (o) => { if (o) counts.value = {} })
const total = computed(() => props.addons.reduce((sum, a) => sum + (counts.value[a.id] || 0) * (a.rental_rupees || 0), 0))
const change = (id, delta) => {
  const next = Math.min(20, Math.max(0, (counts.value[id] || 0) + delta))
  counts.value = { ...counts.value, [id]: next }
}
</script>

<template>
  <Teleport to="#app-root">
    <div v-if="open" class="absolute inset-0 z-[200] flex items-end bg-black/50" @click.self="emit('done', null)">
      <div class="w-full rounded-t-3xl bg-white px-5 pb-8 pt-5" role="dialog" aria-labelledby="addons-title">
        <h3 id="addons-title" class="font-display text-xl font-extrabold text-on-surface">Add kit?</h3>
        <p class="mt-1 text-xs leading-relaxed text-on-surface-variant">Rent from the venue. Paid now with your slot; any deposit is taken at the counter.</p>
        <div class="mt-3 divide-y divide-outline-variant">
          <div v-for="a in addons" :key="a.id" class="flex items-center gap-2 py-2.5">
            <div class="min-w-0 flex-1">
              <p class="font-bold text-on-surface">{{ a.name }}</p>
              <p class="text-xs text-on-surface-variant">{{ rupees(a.rental_rupees) }} each<template v-if="a.deposit_rupees > 0"> · {{ rupees(a.deposit_rupees) }} deposit at venue</template></p>
            </div>
            <button type="button" class="h-9 w-9 rounded-full border border-outline-variant text-lg font-bold disabled:opacity-30"
              :disabled="!counts[a.id]" :aria-label="`Remove one ${a.name}`" @click="change(a.id, -1)">−</button>
            <span class="w-6 text-center font-score text-lg font-bold">{{ counts[a.id] || 0 }}</span>
            <button type="button" class="h-9 w-9 rounded-full border border-primary text-lg font-bold text-primary disabled:opacity-30"
              :disabled="(counts[a.id] || 0) >= 20" :aria-label="`Add one ${a.name}`" @click="change(a.id, 1)">+</button>
          </div>
        </div>
        <button type="button" class="mt-4 w-full rounded-[14px] bg-primary py-3.5 font-bold text-on-primary" @click="emit('done', { ...counts })">
          {{ total > 0 ? `Continue · +₹${total}` : 'Continue without kit' }}
        </button>
      </div>
    </div>
  </Teleport>
</template>
