<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
const route = useRoute()
const policy = ref(null)
const error = ref(false)
onMounted(async () => {
  try { policy.value = (await axios.get('/payments/config', { params: { court_id: route.query.court_id || undefined } })).data.commerce }
  catch { error.value = true }
})
</script>

<template>
  <main class="max-w-2xl mx-auto p-5 pb-24 space-y-5">
    <h1 class="text-2xl font-bold">Cancellation &amp; Refund Policy</h1>
    <p>The terms accepted at checkout apply to your booking. Later policy changes do not change those terms. Venue-specific terms may differ from the platform defaults below.</p>
    <p v-if="error" role="alert">Current defaults could not be loaded. Contact support and refer to your booking's accepted terms.</p>
    <p v-else-if="!policy" role="status">Loading current policy...</p>
    <section v-else class="border rounded-xl p-4 space-y-3">
      <h2 class="font-bold">Current {{ route.query.court_id ? 'venue' : 'platform default' }} terms</h2>
      <template v-if="policy['cancellation.enabled']">
        <p>Cancel at least {{ policy['cancellation.full_hours'] }} hours before play: 100% of the venue charge is refundable.</p>
        <p>Cancel at least {{ policy['cancellation.partial_hours'] }} hours before play, but inside the full-refund window: {{ policy['cancellation.partial_percent'] }}% of the venue charge is refundable.</p>
        <p>Cancel with less notice: {{ policy['cancellation.late_percent'] }}% of the venue charge is refundable. Customer cancellation is unavailable after the session starts.</p>
        <p>KoCourt fee refund rule: {{ policy['cancellation.fee_refund'].replaceAll('_', ' ') }}.</p>
      </template>
      <p v-else>Customer cancellation is disabled. Contact support for exceptional cases.</p>
      <p>Venue cancellations and paid bookings that cannot be fulfilled are eligible for a full refund, including the KoCourt fee.</p>
      <p>Eligible refunds return to the original payment method. Automatic processing is subject to payment verification; exceptions require support review. Expected credit time: {{ policy['refund.expected_days'] }} business days after initiation; provider and bank processing can vary.</p>
    </section>
    <section class="space-y-2"><h2 class="font-bold">Memberships and subscriptions</h2><p>Contact support to review subscription refund eligibility. Cancelling renewal does not automatically refund a payment.</p></section>
    <RouterLink to="/contact" class="inline-block underline font-semibold">Contact support with your booking ID</RouterLink>
  </main>
</template>
