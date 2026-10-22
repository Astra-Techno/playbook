<template>
  <div class="page-gutter pb-24">
    <h2 class="section-title mt-2">App Builds</h2>
    <p class="text-xs text-gray-500 mb-5">Trigger builds, track progress, and download APKs.</p>

    <!-- Build Actions -->
    <div class="space-y-3 mb-6">
      <div class="card p-4">
        <div class="flex items-center justify-between mb-3">
          <div>
            <h3 class="text-sm font-bold text-gray-900">Android Build</h3>
            <p class="text-xs text-gray-500">Player + Owner release APKs</p>
          </div>
          <button @click="triggerBuild('build')" :disabled="triggering === 'build'"
            class="btn-primary text-xs px-4 py-2">
            {{ triggering === 'build' ? 'Triggering...' : 'Build Android' }}
          </button>
        </div>
      </div>

      <div class="card p-4">
        <div class="flex items-center justify-between mb-3">
          <div>
            <h3 class="text-sm font-bold text-gray-900">iOS Build</h3>
            <p class="text-xs text-gray-500">Compile check (no signing)</p>
          </div>
          <button @click="triggerBuild('ios')" :disabled="triggering === 'ios'"
            class="btn-primary text-xs px-4 py-2">
            {{ triggering === 'ios' ? 'Triggering...' : 'Build iOS' }}
          </button>
        </div>
      </div>

      <div class="card p-4">
        <div class="flex items-center justify-between mb-3">
          <div>
            <h3 class="text-sm font-bold text-gray-900">iOS + TestFlight</h3>
            <p class="text-xs text-gray-500">Sign, build & upload to TestFlight</p>
          </div>
          <button @click="triggerBuild('ios', { upload_testflight: 'true' })" :disabled="triggering === 'ios-tf'"
            class="btn-secondary text-xs px-4 py-2">
            {{ triggering === 'ios-tf' ? 'Triggering...' : 'Build & Upload' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Deploy -->
    <div class="card p-4 mb-6">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-sm font-bold text-gray-900">Deploy to Live</h3>
          <p class="text-xs text-gray-500">Pull latest from GitHub → update server</p>
        </div>
        <button @click="deploy" :disabled="deploying" class="btn-primary text-xs px-4 py-2 !bg-green-600">
          {{ deploying ? 'Deploying...' : 'Deploy Now' }}
        </button>
      </div>
      <div v-if="deployResult" class="mt-3 text-xs p-3 rounded-lg" :class="deployResult.ok ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800'">
        {{ deployResult.message }}
      </div>
    </div>

    <!-- Downloads -->
    <h2 class="section-title">Downloads</h2>
    <div class="grid grid-cols-2 gap-3 mb-6">
      <a href="/downloads/kocourt-player.apk" class="card p-4 text-center hover:shadow-md transition-shadow">
        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center mx-auto mb-2">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        </div>
        <div class="text-xs font-bold text-gray-900">Player APK</div>
        <div class="text-[10px] text-gray-400">Android</div>
      </a>
      <a href="/downloads/kocourt-owner.apk" class="card p-4 text-center hover:shadow-md transition-shadow">
        <div class="w-10 h-10 rounded-xl bg-secondary/10 flex items-center justify-center mx-auto mb-2">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-secondary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        </div>
        <div class="text-xs font-bold text-gray-900">Owner APK</div>
        <div class="text-[10px] text-gray-400">Android</div>
      </a>
    </div>

    <!-- Recent Builds -->
    <h2 class="section-title">Recent Builds</h2>
    <div v-if="loadingRuns" class="text-xs text-gray-400 text-center py-4">Loading...</div>
    <div v-else-if="runs.length === 0" class="text-xs text-gray-400 text-center py-4">No recent builds</div>
    <div v-else class="space-y-2">
      <a v-for="run in runs" :key="run.id" :href="run.html_url" target="_blank"
        class="card p-3 flex items-center gap-3 hover:shadow-md transition-shadow">
        <div class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
          :class="{
            'bg-green-100': run.conclusion === 'success',
            'bg-red-100': run.conclusion === 'failure',
            'bg-yellow-100': run.status === 'in_progress' || run.status === 'queued',
            'bg-gray-100': !run.conclusion && run.status !== 'in_progress'
          }">
          <span v-if="run.conclusion === 'success'" class="text-green-600 text-sm">&#10003;</span>
          <span v-else-if="run.conclusion === 'failure'" class="text-red-600 text-sm">&#10007;</span>
          <span v-else-if="run.status === 'in_progress'" class="text-yellow-600 text-sm animate-spin">&#9696;</span>
          <span v-else class="text-gray-400 text-sm">&#8226;</span>
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-xs font-bold text-gray-900 truncate">{{ run.name }}</div>
          <div class="text-[10px] text-gray-500">
            {{ run.status === 'completed' ? run.conclusion : run.status }}
            &middot; {{ timeAgo(run.updated_at) }}
          </div>
        </div>
        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-gray-300 flex-shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
      </a>
    </div>

    <!-- Share link -->
    <div class="mt-6 text-center">
      <p class="text-xs text-gray-400 mb-1">Public download page</p>
      <button @click="copyLink" class="text-xs font-bold text-primary underline underline-offset-4">
        {{ copied ? 'Copied!' : 'Copy kocourt.com/download link' }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import axios from 'axios'

const triggering = ref(null)
const deploying = ref(false)
const deployResult = ref(null)
const runs = ref([])
const loadingRuns = ref(true)
const copied = ref(false)
let pollTimer = null

async function triggerBuild(workflow, inputs = {}) {
  const key = workflow === 'ios' && inputs.upload_testflight ? 'ios-tf' : workflow
  triggering.value = key
  try {
    await axios.post('admin/builds/trigger', { workflow, inputs })
    // Start polling for status updates
    setTimeout(() => loadRuns(), 3000)
    if (!pollTimer) {
      pollTimer = setInterval(() => loadRuns(), 10000)
      setTimeout(() => { clearInterval(pollTimer); pollTimer = null }, 300000) // stop after 5min
    }
  } catch (e) {
    alert(e.response?.data?.message || 'Failed to trigger build')
  } finally {
    setTimeout(() => { triggering.value = null }, 2000)
  }
}

async function deploy() {
  deploying.value = true
  deployResult.value = null
  try {
    const token = localStorage.getItem('token')
    // Fetch deploy key from config
    const configRes = await axios.get('admin/config')
    const deployKey = configRes.data.config?.find(c => c.key === 'deploy_key')?.value
    if (!deployKey) {
      deployResult.value = { ok: false, message: 'deploy_key not found in config table. Add it via Admin > Config.' }
      return
    }
    const res = await fetch(`/deploy.php?key=${deployKey}`)
    const text = await res.text()
    const ok = text.includes('Deployment successful')
    deployResult.value = { ok, message: ok ? 'Deployment successful!' : 'Deployment finished with errors. Check deploy page.' }
  } catch (e) {
    deployResult.value = { ok: false, message: 'Deploy request failed: ' + e.message }
  } finally {
    deploying.value = false
  }
}

async function loadRuns() {
  try {
    const res = await axios.get('admin/builds/status')
    runs.value = res.data.runs || []
  } catch {
    // silent
  } finally {
    loadingRuns.value = false
  }
}

function timeAgo(dateStr) {
  const diff = Date.now() - new Date(dateStr).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  return `${Math.floor(hrs / 24)}d ago`
}

function copyLink() {
  navigator.clipboard.writeText('https://www.kocourt.com/download')
  copied.value = true
  setTimeout(() => { copied.value = false }, 2000)
}

onMounted(() => loadRuns())
</script>
