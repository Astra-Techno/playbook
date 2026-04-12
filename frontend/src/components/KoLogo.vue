<script setup>
defineProps({
    size: {
        type: [Number, String],
        default: 36
    },
    showText: {
        type: Boolean,
        default: false
    }
})
</script>

<template>
    <div class="flex items-center gap-2">
        <img
            src="/logo.png"
            :style="{ width: size + 'px', height: size + 'px' }"
            class="shrink-0 rounded-[22%] object-cover"
            alt="KoCourt"
        />
        <span v-if="showText" class="text-sm font-black text-primary tracking-widest uppercase">
            KoCourt
        </span>
    </div>
</template>
