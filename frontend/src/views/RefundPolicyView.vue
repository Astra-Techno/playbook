<script setup>
import { useRouter } from 'vue-router'
import { ArrowLeft, BadgeIndianRupee, Clock3, CircleCheck } from 'lucide-vue-next'

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
                <h1 class="text-lg font-bold text-black">Refund & Cancellation Policy</h1>
                <p class="text-xs text-gray-400">Last updated: 15 October 2026</p>
            </div>
        </div>

        <div class="mx-auto max-w-2xl space-y-7 px-5 py-6 pb-10">
            <p class="text-sm leading-relaxed text-gray-600">
                This policy applies to court and venue bookings made through KoCourt. Please review it before making a payment.
            </p>

            <div class="rounded-2xl border border-orange-100 bg-orange-50 p-4">
                <div class="flex items-start gap-3">
                    <Clock3 :size="21" class="mt-0.5 shrink-0 text-primary" />
                    <div>
                        <p class="text-sm font-bold text-black">24-hour cancellation window</p>
                        <p class="mt-1 text-sm leading-relaxed text-gray-600">
                            Cancel at least 24 hours before your scheduled slot to receive a full refund.
                        </p>
                    </div>
                </div>
            </div>

            <section>
                <h2 class="mb-2 text-base font-bold text-black">1. Eligible cancellations</h2>
                <ul class="list-inside list-disc space-y-2 text-sm leading-relaxed text-gray-600">
                    <li>A booking cancelled at least 24 hours before its scheduled start time is eligible for a full refund.</li>
                    <li>Use the cancellation option in <strong class="text-gray-700">My Bookings</strong> to submit the request.</li>
                    <li>Refunds are returned to the original payment method; KoCourt does not issue cash refunds.</li>
                </ul>
            </section>

            <section>
                <h2 class="mb-2 text-base font-bold text-black">2. Cancellations within 24 hours</h2>
                <p class="text-sm leading-relaxed text-gray-600">
                    A booking cancelled less than 24 hours before its scheduled start time is non-refundable. This allows venue owners reasonable time to manage their availability.
                </p>
            </section>

            <section>
                <h2 class="mb-2 text-base font-bold text-black">3. Venue or technical cancellations</h2>
                <p class="text-sm leading-relaxed text-gray-600">
                    If a venue cancels your confirmed booking, or KoCourt cannot confirm a paid booking because of a technical error, you are eligible for a full refund.
                </p>
            </section>

            <section>
                <h2 class="mb-2 text-base font-bold text-black">4. Refund timing</h2>
                <div class="flex items-start gap-3 rounded-xl bg-gray-50 p-4">
                    <BadgeIndianRupee :size="20" class="mt-0.5 shrink-0 text-gray-700" />
                    <p class="text-sm leading-relaxed text-gray-600">
                        After KoCourt approves an eligible refund, it is initiated to your original payment method. Banks, card networks, and UPI providers may take 5–7 business days to reflect the amount.
                    </p>
                </div>
            </section>

            <section>
                <h2 class="mb-2 text-base font-bold text-black">5. Memberships and plans</h2>
                <p class="text-sm leading-relaxed text-gray-600">
                    Membership or subscription payments are non-refundable once the plan period has started, unless required by applicable law.
                </p>
            </section>

            <section class="rounded-2xl border border-gray-100 p-4">
                <div class="flex gap-3">
                    <CircleCheck :size="20" class="mt-0.5 shrink-0 text-green-600" />
                    <div>
                        <h2 class="text-sm font-bold text-black">Need help with a refund?</h2>
                        <p class="mt-1 text-sm leading-relaxed text-gray-600">
                            Call <a href="tel:+919994439081" class="font-semibold text-black underline">+91 99944 39081</a> or email
                            <a href="mailto:support@kocourt.com" class="font-semibold text-black underline">support@kocourt.com</a> with your booking ID.
                        </p>
                    </div>
                </div>
            </section>
        </div>
    </div>
</template>
