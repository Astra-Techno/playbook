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

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')

