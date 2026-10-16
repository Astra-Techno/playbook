<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import { useToastStore } from '../stores/toast'
import { ChevronLeft, Building2, CreditCard, Info, CheckCircle, Clock } from 'lucide-vue-next'

const router  = useRouter()
const toast   = useToastStore()

const loading     = ref(true)
const saving      = ref(false)
const accountType = ref('bank_account')
const commission  = ref(10)
const cfStatus    = ref(null)

const holder  = ref('')
const account = ref('')
const ifsc    = ref('')
const upi     = ref('')
const pan     = ref('')

onMounted(async () => {
    try {
        const res = await axios.get('/vendor/profile')
        commission.value = res.data.commission ?? 10
        const p = res.data.profile
        if (p) {
            accountType.value = p.account_type || 'bank_account'
            holder.value  = p.account_holder || ''
            ifsc.value    = p.ifsc_code || ''
            upi.value     = p.upi_vpa || ''
            pan.value     = p.pan_masked || ''
            cfStatus.value = p.cf_vendor_status
        }
    } catch {}
    loading.value = false
})

const save = async () => {
    if (accountType.value === 'bank_account') {
        if (!holder.value.trim() || !account.value.trim() || !ifsc.value.trim()) {
            toast.error('Fill account holder, account number, and IFSC'); return
        }
    } else {
        if (!upi.value.trim()) { toast.error('Enter UPI VPA'); return }
    }
    saving.value = true
    try {
        const res = await axios.post('/vendor/profile', {
            account_type: accountType.value,
            account_holder: holder.value.trim(),
            account_number: account.value.trim(),
            ifsc_code: ifsc.value.trim(),
            upi_vpa: upi.value.trim(),
            pan_number: pan.value.trim(),
        })
        cfStatus.value = res.data.cf_status
        toast.success(res.data.cf_status === 'active' ? 'Payout account verified!' : 'Saved. Verification pending.')
    } catch { toast.error('Failed to save') }
    saving.value = false
}
</script>

<template>
  <div class="min-h-screen bg-white">
    <div class="sticky top-0 z-10 bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
      <button @click="router.back()" class="text-gray-600"><ChevronLeft :size="24" /></button>
      <p class="font-bold flex-1">Payout Settings</p>
    </div>

    <div v-if="loading" class="py-20 text-center text-gray-400">Loading...</div>

    <div v-else class="page-gutter py-4 max-w-lg mx-auto">
      <!-- Status -->
      <div v-if="cfStatus" class="rounded-xl p-4 mb-5 flex items-start gap-3"
        :class="cfStatus === 'active' ? 'bg-green-50 border border-green-200' : 'bg-orange-50 border border-orange-200'">
        <component :is="cfStatus === 'active' ? CheckCircle : Clock" :size="20"
          :class="cfStatus === 'active' ? 'text-green-600' : 'text-orange-500'" class="mt-0.5 shrink-0" />
        <p class="text-sm font-semibold" :class="cfStatus === 'active' ? 'text-green-700' : 'text-orange-700'">
          {{ cfStatus === 'active'
            ? `Payout account verified. You'll receive ${100 - commission}% of each booking.`
            : 'Verification pending. Payouts will start once verified.' }}
        </p>
      </div>

      <!-- Commission info -->
      <div class="bg-gray-50 rounded-xl p-4 mb-6 flex items-center gap-3">
        <Info :size="18" class="text-gray-400 shrink-0" />
        <p class="text-sm text-gray-500">Platform fee: {{ commission }}% · You receive: {{ 100 - commission }}% per booking</p>
      </div>

      <!-- Method toggle -->
      <p class="font-bold text-sm mb-2">Payout Method</p>
      <div class="grid grid-cols-2 gap-3 mb-6">
        <button @click="accountType = 'bank_account'"
          class="rounded-xl py-4 text-center border-2 transition-all"
          :class="accountType === 'bank_account' ? 'border-primary bg-primary/5' : 'border-gray-200 bg-gray-50'">
          <Building2 :size="24" class="mx-auto mb-1" :class="accountType === 'bank_account' ? 'text-primary' : 'text-gray-400'" />
          <span class="text-xs font-bold" :class="accountType === 'bank_account' ? 'text-primary' : 'text-gray-400'">Bank Account</span>
        </button>
        <button @click="accountType = 'upi'"
          class="rounded-xl py-4 text-center border-2 transition-all"
          :class="accountType === 'upi' ? 'border-primary bg-primary/5' : 'border-gray-200 bg-gray-50'">
          <CreditCard :size="24" class="mx-auto mb-1" :class="accountType === 'upi' ? 'text-primary' : 'text-gray-400'" />
          <span class="text-xs font-bold" :class="accountType === 'upi' ? 'text-primary' : 'text-gray-400'">UPI</span>
        </button>
      </div>

      <!-- Fields -->
      <div class="space-y-4 mb-8">
        <div>
          <label class="text-sm font-semibold text-gray-700">Account Holder Name</label>
          <input v-model="holder" type="text" placeholder="Full name as per bank/UPI" class="input-field mt-1" />
        </div>
        <template v-if="accountType === 'bank_account'">
          <div>
            <label class="text-sm font-semibold text-gray-700">Account Number</label>
            <input v-model="account" type="text" placeholder="Enter account number" class="input-field mt-1" inputmode="numeric" />
          </div>
          <div>
            <label class="text-sm font-semibold text-gray-700">IFSC Code</label>
            <input v-model="ifsc" type="text" placeholder="e.g. SBIN0001234" class="input-field mt-1" />
          </div>
        </template>
        <div v-if="accountType === 'upi'">
          <label class="text-sm font-semibold text-gray-700">UPI VPA</label>
          <input v-model="upi" type="text" placeholder="e.g. yourname@upi" class="input-field mt-1" />
        </div>
        <div>
          <label class="text-sm font-semibold text-gray-700">PAN Number <span class="text-gray-400 font-normal">(optional)</span></label>
          <input v-model="pan" type="text" placeholder="For tax purposes" class="input-field mt-1" />
        </div>
      </div>

      <button @click="save" :disabled="saving" class="btn-primary w-full !py-3.5 !text-base">
        {{ saving ? 'Saving...' : 'Save & Verify' }}
      </button>
    </div>
  </div>
</template>
