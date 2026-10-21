<script setup>
import { useRouter } from 'vue-router'
import { ArrowLeft, Headphones, Mail, Phone } from 'lucide-vue-next'

const router = useRouter()
</script>

<template>
    <div class="min-h-full bg-white">
        <div class="sticky top-0 z-10 flex items-center gap-3 border-b border-gray-100 bg-white px-5 pb-4 pt-5">
            <button @click="router.back()" aria-label="Go back"
                class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gray-100">
                <ArrowLeft :size="20" :stroke-width="2.5" class="text-gray-500" />
            </button>
            <div>
                <h1 class="text-lg font-bold text-black">Contact KoCourt</h1>
                <p class="text-xs text-gray-400">Customer support</p>
            </div>
        </div>

        <div class="mx-auto max-w-2xl space-y-5 px-5 py-6 pb-10">
            <div class="rounded-2xl bg-black p-5 text-white">
                <Headphones :size="28" class="mb-3 text-orange-300" />
                <h2 class="text-lg font-bold">We are here to help</h2>
                <p class="mt-1 text-sm leading-relaxed text-white/75">
                    For booking, payment, cancellation, or account support, contact us through either channel below.
                </p>
            </div>

            <a href="tel:+919994439081" class="flex items-center gap-4 rounded-2xl border border-gray-100 p-5 shadow-sm transition active:scale-[0.99]">
                <span class="flex h-11 w-11 items-center justify-center rounded-xl bg-orange-50 text-primary"><Phone :size="21" /></span>
                <span>
                    <span class="block text-xs font-bold uppercase tracking-wider text-gray-400">Call support</span>
                    <span class="mt-1 block text-base font-bold text-black">+91 99944 39081</span>
                </span>
            </a>

            <a href="mailto:support@kocourt.com" class="flex items-center gap-4 rounded-2xl border border-gray-100 p-5 shadow-sm transition active:scale-[0.99]">
                <span class="flex h-11 w-11 items-center justify-center rounded-xl bg-orange-50 text-primary"><Mail :size="21" /></span>
                <span>
                    <span class="block text-xs font-bold uppercase tracking-wider text-gray-400">Email support</span>
                    <span class="mt-1 block text-base font-bold text-black">support@kocourt.com</span>
                </span>
            </a>

            <p class="px-1 text-xs leading-relaxed text-gray-500">
                To help us resolve a booking or payment issue quickly, include your registered phone number and booking ID in your message.
            </p>
        </div>
    </div>
</template>
