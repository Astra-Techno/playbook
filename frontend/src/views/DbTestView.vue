<script setup>
import { ref, onMounted } from 'vue'
import axios from 'axios'
import {
    Database, Server, Wifi, WifiOff, RefreshCw,
    CheckCircle2, XCircle, Clock, Table2, Hash
} from 'lucide-vue-next'

const result   = ref(null)
const loading  = ref(false)
const lastRun  = ref(null)

const test = async () => {
    loading.value = true
    result.value  = null
    try {
        const res = await axios.get('/test')
        result.value = { ...res.data, ok: res.data.status === 'ok' }
    } catch (err) {
        result.value = {
            ok: false,
            status: 'error',
            message: err.response?.data?.message || err.message || 'Request failed',
            host: err.response?.data?.host || '—',
            port: err.response?.data?.port || '—',
        }
    } finally {
        loading.value = false
        lastRun.value = new Date().toLocaleTimeString()
    }
}

onMounted(test)
</script>

<template>
    <div class="min-h-full bg-slate-50 px-4 py-6">

        <!-- Header card -->
        <div class="bg-white rounded-2xl p-5 shadow-sm border border-slate-100 mb-4">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                    <div class="w-10 h-10 bg-primary-light rounded-xl flex items-center justify-center">
                        <Database :size="20" class="text-primary" />
                    </div>
                    <div>
                        <h1 class="font-extrabold text-slate-900 text-base">DB Connection Test</h1>
                        <p class="text-xs text-slate-400">{{ lastRun ? 'Last checked: ' + lastRun : 'Checking...' }}</p>
                    </div>
                </div>
                <button @click="test" :disabled="loading"
                    class="flex items-center gap-1.5 text-xs font-bold text-primary bg-primary-light px-3 py-2 rounded-xl disabled:opacity-50 active:scale-95 transition-transform">
                    <RefreshCw :size="13" :class="loading ? 'animate-spin' : ''" />
                    Retry
                </button>
            </div>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="bg-white rounded-2xl p-8 shadow-sm border border-slate-100 flex flex-col items-center gap-3">
            <RefreshCw :size="32" class="text-primary animate-spin" />
            <p class="text-sm font-semibold text-slate-500">Testing connection...</p>
        </div>

        <!-- Result -->
        <template v-else-if="result">

            <!-- Status banner -->
            <div class="rounded-2xl p-4 mb-4 flex items-center gap-3"
                :class="result.ok ? 'bg-emerald-50 border border-emerald-100' : 'bg-red-50 border border-red-100'">
                <component :is="result.ok ? CheckCircle2 : XCircle" :size="24"
                    :class="result.ok ? 'text-emerald-500' : 'text-red-500'" />
                <div>
                    <p class="font-bold text-sm" :class="result.ok ? 'text-emerald-700' : 'text-red-700'">
                        {{ result.ok ? 'Connected Successfully' : 'Connection Failed' }}
                    </p>
                    <p class="text-xs mt-0.5" :class="result.ok ? 'text-emerald-600' : 'text-red-500'">
                        {{ result.message }}
                    </p>
                </div>
            </div>

            <!-- Connection details -->
            <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden mb-4">
                <div class="px-4 py-3 border-b border-slate-50">
                    <p class="text-[11px] font-bold text-slate-400 uppercase tracking-widest">Connection Details</p>
                </div>
                <div class="divide-y divide-slate-50">
                    <div class="flex items-center justify-between px-4 py-3">
                        <div class="flex items-center gap-2 text-slate-500">
                            <Server :size="14" />
                            <span class="text-sm font-medium">Host</span>
                        </div>
                        <span class="text-sm font-bold text-slate-900 font-mono">{{ result.host || '—' }}</span>
                    </div>
                    <div class="flex items-center justify-between px-4 py-3">
                        <div class="flex items-center gap-2 text-slate-500">
                            <Wifi :size="14" />
                            <span class="text-sm font-medium">Port</span>
                        </div>
                        <span class="text-sm font-bold text-slate-900 font-mono">{{ result.port || '—' }}</span>
                    </div>
                    <div class="flex items-center justify-between px-4 py-3">
                        <div class="flex items-center gap-2 text-slate-500">
                            <Database :size="14" />
                            <span class="text-sm font-medium">Database</span>
                        </div>
                        <span class="text-sm font-bold text-slate-900 font-mono">{{ result.database || '—' }}</span>
                    </div>
                    <div v-if="result.mysql_version" class="flex items-center justify-between px-4 py-3">
                        <div class="flex items-center gap-2 text-slate-500">
                            <Hash :size="14" />
                            <span class="text-sm font-medium">MySQL Version</span>
                        </div>
                        <span class="text-sm font-bold text-slate-900 font-mono">{{ result.mysql_version }}</span>
                    </div>
                    <div v-if="result.php_version" class="flex items-center justify-between px-4 py-3">
                        <div class="flex items-center gap-2 text-slate-500">
                            <Hash :size="14" />
                            <span class="text-sm font-medium">PHP Version</span>
                        </div>
                        <span class="text-sm font-bold text-slate-900 font-mono">{{ result.php_version }}</span>
                    </div>
                    <div v-if="result.latency_ms != null" class="flex items-center justify-between px-4 py-3">
                        <div class="flex items-center gap-2 text-slate-500">
                            <Clock :size="14" />
                            <span class="text-sm font-medium">Latency</span>
                        </div>
                        <span class="text-sm font-bold font-mono"
                            :class="result.latency_ms < 50 ? 'text-emerald-600' : result.latency_ms < 200 ? 'text-amber-600' : 'text-red-500'">
                            {{ result.latency_ms }} ms
                        </span>
                    </div>
                    <div v-if="result.server_time" class="flex items-center justify-between px-4 py-3">
                        <div class="flex items-center gap-2 text-slate-500">
                            <Clock :size="14" />
                            <span class="text-sm font-medium">Server Time</span>
                        </div>
                        <span class="text-sm font-bold text-slate-900 font-mono">{{ result.server_time }}</span>
                    </div>
                </div>
            </div>

            <!-- Tables -->
            <div v-if="result.tables && Object.keys(result.tables).length" class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
                <div class="px-4 py-3 border-b border-slate-50 flex items-center justify-between">
                    <p class="text-[11px] font-bold text-slate-400 uppercase tracking-widest">Tables</p>
                    <span class="text-[11px] font-bold text-primary bg-primary-light px-2 py-0.5 rounded-full">
                        {{ Object.keys(result.tables).length }} tables
                    </span>
                </div>
                <div class="divide-y divide-slate-50">
                    <div v-for="(count, table) in result.tables" :key="table"
                        class="flex items-center justify-between px-4 py-2.5">
                        <div class="flex items-center gap-2">
                            <Table2 :size="13" class="text-slate-400" />
                            <span class="text-sm font-mono text-slate-700">{{ table }}</span>
                        </div>
                        <span class="text-xs font-bold text-slate-500 bg-slate-100 px-2 py-0.5 rounded-full">
                            {{ count }} rows
                        </span>
                    </div>
                </div>
            </div>

        </template>
    </div>
</template>
