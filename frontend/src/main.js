import './assets/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'
import axios from 'axios'

import App from './App.vue'
import router from './router'

// Base URL for all API requests — set VITE_API_BASE in .env to override
axios.defaults.baseURL = import.meta.env.VITE_API_BASE || '/api'

// Restore auth token on page load
const token = localStorage.getItem('token')
if (token) {
    axios.defaults.headers.common['Authorization'] = `Bearer ${token}`
}

// LiteSpeed blocks DELETE/PUT at server level — tunnel them through POST
axios.interceptors.request.use(config => {
    if (['delete', 'put', 'patch'].includes(config.method)) {
        config.headers['X-HTTP-Method-Override'] = config.method.toUpperCase()
        config.method = 'post'
    }
    return config
})

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')

