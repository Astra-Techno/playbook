import './assets/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'
import axios from 'axios'

import App from './App.vue'
import router from './router'

// Base URL for all API requests — set VITE_API_BASE in .env to override
axios.defaults.baseURL = import.meta.env.VITE_API_BASE || '/api'

const applyAuthHeaders = (token) => {
    if (token) {
        axios.defaults.headers.common['Authorization'] = `Bearer ${token}`
        axios.defaults.headers.common['X-Authorization'] = `Bearer ${token}`
        axios.defaults.headers.common['X-Auth-Token'] = token
    } else {
        delete axios.defaults.headers.common['Authorization']
        delete axios.defaults.headers.common['X-Authorization']
        delete axios.defaults.headers.common['X-Auth-Token']
    }
}

// Restore auth token on page load (Authorization is often stripped by LiteSpeed)
const token = localStorage.getItem('token')
applyAuthHeaders(token)

// Prevent browser from caching API responses
axios.interceptors.request.use(config => {
    config.headers['Cache-Control'] = 'no-cache, no-store'
    config.headers['Pragma'] = 'no-cache'

    const liveToken = localStorage.getItem('token')
    if (liveToken) {
        config.headers['Authorization'] = `Bearer ${liveToken}`
        config.headers['X-Authorization'] = `Bearer ${liveToken}`
        config.headers['X-Auth-Token'] = liveToken
    }

    // LiteSpeed blocks DELETE/PUT at server level — tunnel them through POST
    if (['delete', 'put', 'patch'].includes(config.method)) {
        config.headers['X-HTTP-Method-Override'] = config.method.toUpperCase()
        config.method = 'post'
    }
    return config
})

// Expose for the auth store so login/logout stay in sync
window.__kocourtApplyAuthHeaders = applyAuthHeaders

// Embedded WebViews sometimes report innerHeight === 0 before layout; never set height to 0
// or the whole app collapses. CSS (main.css #app) provides fallbacks; JS only reinforces when h > 0.
const setAppHeight = () => {
    const el = document.getElementById('app')
    if (!el) return
    const vv = window.visualViewport
    const h = Math.round(
        (vv && vv.height > 0 ? vv.height : 0) ||
            (typeof window.innerHeight === 'number' && window.innerHeight > 0 ? window.innerHeight : 0) ||
            (document.documentElement && document.documentElement.clientHeight > 0
                ? document.documentElement.clientHeight
                : 0)
    )
    if (h > 0) {
        el.style.minHeight = `${h}px`
        el.style.height = `${h}px`
    } else {
        el.style.removeProperty('height')
        el.style.removeProperty('min-height')
    }
}
setAppHeight()
window.addEventListener('resize', setAppHeight)
if (window.visualViewport) window.visualViewport.addEventListener('resize', setAppHeight)
requestAnimationFrame(() => {
    setAppHeight()
    setTimeout(setAppHeight, 50)
    setTimeout(setAppHeight, 250)
})

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')

