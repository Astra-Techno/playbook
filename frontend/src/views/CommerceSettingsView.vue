<script setup>
import { computed, onMounted, ref } from 'vue'
import axios from 'axios'

const values = ref({})
const schema = ref({})
const revision = ref('')
const history = ref([])
const refunds = ref([])
const venues = ref([])
const refundBusy = ref(null)
const venueId = ref('')
const loading = ref(false)
const saving = ref(false)
const message = ref('')
const error = ref('')
const loadedScope = ref(null)
const groups = computed(() => {
  const result = {}
  for (const [key, field] of Object.entries(schema.value)) {
    if (venueId.value && !['venue.', 'cancellation.', 'booking.'].some(prefix => key.startsWith(prefix))) continue
    ;(result[field[0]] ||= []).push({ key, field })
  }
  return result
})
const scopeUrl = () => '/admin/settings' + (venueId.value ? `?court_id=${venueId.value}` : '')
async function load() {
  loading.value = true
  loadedScope.value = null
  error.value = ''
  message.value = ''
  try {
    const { data } = await axios.get(scopeUrl())
    values.value = data.values
    schema.value = data.schema
    revision.value = data.revision
    history.value = data.history
    loadedScope.value = venueId.value
  } catch (e) { error.value = e.response?.data?.message || 'Could not load settings' }
  finally { loading.value = false }
}
async function save() {
  saving.value = true
  error.value = ''
  message.value = ''
  try {
    const allowedKeys = Object.values(groups.value).flat().map(item => item.key)
    const changes = Object.fromEntries(allowedKeys.map(key => [key, values.value[key]]))
    const { data } = await axios.put(scopeUrl(), { values: changes, revision: revision.value })
    values.value = data.values
    revision.value = data.revision
    history.value = data.history
    message.value = 'Settings saved. Existing bookings keep their original terms.'
  } catch (e) { error.value = e.response?.data?.message || 'Could not save settings' }
  finally { saving.value = false }
}
async function resetVenue() {
  if (!window.confirm('Remove this venue override and inherit platform defaults for future bookings?')) return
  saving.value = true
  try {
    await axios.delete(scopeUrl(), { data: { revision: revision.value } })
    await load()
  } catch (e) { error.value = e.response?.data?.message || 'Could not reset venue settings' }
  finally { saving.value = false }
}
async function refreshRefunds() { refunds.value = (await axios.get('/admin/refund-requests')).data.records || [] }
async function refundAction(refund, action) {
  if (action === 'submit' && !window.confirm(`Submit the original INR ${(refund.amount_paise / 100).toFixed(2)} refund to Cashfree?`)) return
  refundBusy.value = refund.id
  try { await axios.post(`/admin/refund-requests/${refund.id}/${action}`); await refreshRefunds() }
  catch (e) { error.value = e.response?.data?.message || 'Could not process refund' }
  finally { refundBusy.value = null }
}
onMounted(async () => {
  await load()
  try { venues.value = (await axios.get('/courts')).data.records || [] } catch { error.value = 'Could not load the venue list. Reload before configuring venue taxes.' }
  try { refunds.value = (await axios.get('/admin/refund-requests')).data.records || [] } catch { error.value = 'Could not load the refund review queue' }
})
</script>

<template>
  <main class="max-w-3xl mx-auto p-5 pb-28 space-y-5">
    <RouterLink to="/admin" class="text-sm underline">Back to admin</RouterLink>
    <div><h1 class="text-2xl font-bold">Commercial settings</h1><p class="text-sm text-gray-500 mt-2">Manage prices, tax treatment and cancellation rules for new bookings.</p></div>
    <div class="rounded-xl bg-amber-50 p-4 text-sm space-y-2">
      <p>Enable GST only after confirming registration and service classification. A GSTIN format check does not verify registration.</p>
      <p>Enable automatic refunds after testing Cashfree sandbox and scheduling the refund worker. Exceptions and legacy payments require review. Easy Split uses the existing immediate split integration. Deferred settlement is not enabled by these settings.</p>
      <p>Processing rates are cost estimates only, not deductions or a Cashfree price agreement. Platform fees and venue commission are separate charges.</p>
    </div>
    <label class="block text-sm font-semibold">Settings scope
      <select v-model="venueId" :disabled="loading || saving" class="block w-full border rounded-lg p-3 mt-2" @change="load">
        <option value="">Platform defaults</option>
        <option v-for="venue in venues" :key="venue.id" :value="String(venue.id)">{{ venue.name }} (#{{ venue.id }})</option>
      </select>
    </label>
    <p v-if="venueId" class="text-sm text-gray-600">Saving pins these venue tax, booking and cancellation values for this venue. Other platform settings stay inherited.</p>
    <p v-if="loading" role="status">Loading settings...</p>
    <p v-if="error" role="alert" class="text-red-700">{{ error }}</p>
    <p v-if="message" role="status" class="text-green-700">{{ message }}</p>
    <form v-if="!loading && loadedScope === venueId" class="space-y-5" @submit.prevent="save">
      <fieldset v-for="(fields, group) in groups" :key="group" :disabled="saving" class="border rounded-xl p-4 space-y-4">
        <legend class="px-2 font-bold">{{ group }}</legend>
        <label v-for="{ key, field } in fields" :key="key" :for="key" class="block text-sm">
          <span class="block mb-1.5">{{ field[1] }}</span>
          <input v-if="field[2] === 'bool'" :id="key" v-model="values[key]" type="checkbox" class="h-5 w-5" />
          <select v-else-if="field[2] === 'enum'" :id="key" v-model="values[key]" class="w-full border rounded-lg p-2.5">
            <option v-for="choice in field[4]" :key="choice" :value="choice">{{ choice.replaceAll('_', ' ') }}</option>
          </select>
          <input v-else-if="field[2] === 'number'" :id="key" v-model.number="values[key]" type="number" :min="field[4]" :max="field[5]" step="0.01" required class="w-full border rounded-lg p-2.5" />
          <input v-else :id="key" v-model="values[key]" type="text" maxlength="250" class="w-full border rounded-lg p-2.5" />
        </label>
      </fieldset>
      <button :disabled="saving" class="bg-black text-white rounded-lg px-5 py-3 font-semibold disabled:opacity-50">{{ saving ? 'Saving...' : 'Save settings' }}</button>
      <button v-if="venueId" type="button" :disabled="saving" class="ml-3 border rounded-lg px-4 py-3" @click="resetVenue">Use platform defaults</button>
    </form>
    <section v-if="history.length" class="text-sm"><h2 class="font-bold mb-2">Recent changes</h2><p v-for="entry in history" :key="entry.id">{{ entry.created_at }} - admin #{{ entry.actor_id }}</p></section>
    <section class="border rounded-xl p-4 space-y-3">
      <h2 class="font-bold">Refund requests</h2>
      <button class="underline text-sm" @click="refreshRefunds().catch(() => error = 'Could not refresh refunds')">Refresh status</button>
      <p class="text-sm text-gray-600">Success means Cashfree confirmed the refund. Pending requests are checked by the worker. Simulated requests move no money. Review exceptions before submitting.</p>
      <p v-if="!refunds.length" class="text-sm">No refund requests.</p>
      <div v-for="refund in refunds" :key="`${refund.legacy ? 'legacy' : 'request'}-${refund.id}`" class="border-t pt-3 text-sm space-y-2">
        <p class="font-semibold">{{ refund.booking_id ? `Booking #${refund.booking_id}` : 'Unfulfilled payment' }} {{ refund.court_name || '' }}</p>
        <p>{{ refund.status.replaceAll('_', ' ') }} · INR {{ (refund.amount_paise / 100).toFixed(2) }}</p>
        <p v-if="refund.error_code">Review: {{ refund.error_code.replaceAll('_', ' ') }}</p>
        <p v-if="refund.refund_id" class="break-all">{{ refund.refund_id }}</p>
        <p v-if="refund.legacy">Legacy payment: verify original terms and process manually with reconciliation. Do not create a second refund.</p>
        <template v-else-if="!['success','simulated'].includes(refund.status)">
          <button :disabled="refundBusy !== null" class="border rounded px-3 py-2" @click="refundAction(refund, 'sync')">Check Cashfree</button>
          <button v-if="!refund.provider_status && refund.status !== 'failed'" :disabled="refundBusy !== null" class="ml-2 border rounded px-3 py-2" @click="refundAction(refund, 'submit')">Submit approved refund</button>
        </template>
      </div>
    </section>
  </main>
</template>
