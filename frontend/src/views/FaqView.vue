<script setup>
import { ref } from 'vue'
import { ChevronDown } from 'lucide-vue-next'

const faqs = [
    {
        section: 'Booking',
        items: [
            {
                q: 'How do I book a court?',
                a: 'Go to Explore, tap on any court, select a date and time slot, then confirm your booking. You\'ll see it instantly in My Bookings.'
            },
            {
                q: 'Can I cancel a booking?',
                a: 'Yes. Go to My Bookings, find the booking, and tap Cancel. Cancellations are free up to 2 hours before the slot.'
            },
            {
                q: 'What happens if the court is unavailable?',
                a: 'Booked slots are shown as unavailable in real time. If a slot is greyed out, it\'s already taken — choose another time.'
            },
        ]
    },
    {
        section: 'Memberships',
        items: [
            {
                q: 'What is a membership plan?',
                a: 'Court owners offer monthly or weekly membership plans with discounted or unlimited access for morning, evening, or full-day slots.'
            },
            {
                q: 'Can I subscribe to multiple courts?',
                a: 'Yes, you can hold active memberships at multiple courts at the same time.'
            },
            {
                q: 'What happens when my membership expires?',
                a: 'You can renew by visiting the court\'s detail page and subscribing again. Expired plans appear in My Memberships under Past.'
            },
        ]
    },
    {
        section: 'Account',
        items: [
            {
                q: 'How do I log in?',
                a: 'KoCourt uses phone number + OTP verification. Enter your phone number, receive a 4-digit OTP, and you\'re in — no password needed.'
            },
            {
                q: 'How do I update my profile picture?',
                a: 'Go to Profile, tap your avatar photo, and select a new image from your gallery. It updates instantly.'
            },
            {
                q: 'Can I change my phone number?',
                a: 'Phone number is your login identity and cannot be changed. Contact support if you need to transfer your account.'
            },
        ]
    },
    {
        section: 'Court Owners',
        items: [
            {
                q: 'How do I list my court?',
                a: 'Sign up, go to My Services, and tap the + button to add a new court. Fill in the details, set your time slots and pricing.'
            },
            {
                q: 'How do I track earnings?',
                a: 'The Earnings tab in My Services shows total revenue, weekly/monthly breakdown, and payout history.'
            },
            {
                q: 'Can I delete a membership plan?',
                a: 'Yes, but only if no active subscribers are currently enrolled. If players are using the plan, it\'s protected from deletion.'
            },
        ]
    },
]

const openIndex = ref(null)

const toggle = (key) => {
    openIndex.value = openIndex.value === key ? null : key
}
</script>

<template>
    <div class="min-h-screen bg-slate-50 pb-28">

        <!-- Intro -->
        <div class="bg-white px-5 py-6 border-b border-slate-100">
            <p class="text-sm text-slate-500 leading-relaxed">
                Find answers to common questions about booking courts, memberships, and managing your account.
            </p>
        </div>

        <!-- FAQ sections -->
        <div class="px-4 pt-5 space-y-6">
            <div v-for="section in faqs" :key="section.section">
                <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">{{ section.section }}</p>
                <div class="bg-white rounded-2xl ring-1 ring-slate-100 overflow-hidden divide-y divide-slate-50">
                    <div v-for="(item, i) in section.items" :key="i">
                        <button
                            @click="toggle(section.section + i)"
                            class="w-full flex items-center justify-between gap-3 px-5 py-4 text-left active:bg-slate-50 transition-colors">
                            <span class="text-sm font-bold text-slate-800 leading-snug">{{ item.q }}</span>
                            <ChevronDown :size="16" class="text-slate-400 shrink-0 transition-transform duration-200"
                                :class="openIndex === section.section + i ? 'rotate-180' : ''" />
                        </button>
                        <Transition
                            enter-active-class="transition-all duration-200 ease-out overflow-hidden"
                            enter-from-class="max-h-0 opacity-0"
                            enter-to-class="max-h-40 opacity-100"
                            leave-active-class="transition-all duration-150 ease-in overflow-hidden"
                            leave-from-class="max-h-40 opacity-100"
                            leave-to-class="max-h-0 opacity-0">
                            <div v-if="openIndex === section.section + i"
                                class="px-5 pb-4 text-sm text-slate-500 leading-relaxed border-t border-slate-50 pt-3">
                                {{ item.a }}
                            </div>
                        </Transition>
                    </div>
                </div>
            </div>
        </div>

        <!-- Contact -->
        <div class="mx-4 mt-6 bg-primary/5 rounded-2xl px-5 py-5 text-center">
            <p class="text-sm font-black text-slate-800 mb-1">Still have questions?</p>
            <p class="text-xs text-slate-500">Reach us at <span class="text-primary font-bold">support@kocourt.com</span></p>
        </div>

    </div>
</template>
