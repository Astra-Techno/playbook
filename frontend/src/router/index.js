import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'

const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    scrollBehavior: () => ({ top: 0 }),
    routes: [
        {
            path: '/',
            name: 'home',
            component: HomeView,
            meta: { title: 'Home', showGreeting: true }
        },
        {
            path: '/login',
            name: 'login',
            component: () => import('../views/LoginView.vue'),
            meta: { guestOnly: true, title: 'Welcome' },
        },
        {
            path: '/bookings',
            name: 'my-bookings',
            component: () => import('../views/MyBookingsView.vue'),
            meta: { title: 'KoCourt', subtitle: 'Reservations' }
        },
        {
            path: '/courts/:id',
            name: 'court-details',
            component: () => import('../views/CourtDetails.vue'),
            meta: { title: 'Service Details' }
        },
        {
            path: '/profile',
            name: 'profile',
            component: () => import('../views/ProfileView.vue'),
            meta: { title: 'KoCourt', subtitle: 'Account' }
        },
        {
            path: '/feed',
            name: 'feed',
            component: () => import('../views/FeedView.vue'),
            meta: { title: 'Community Feed', subtitle: 'Live Updates' }
        },
        {
            path: '/db-test',
            name: 'db-test',
            component: () => import('../views/DbTestView.vue'),
            meta: { title: 'DB Connection Test' }
        },
        {
            path: '/my-services',
            name: 'my-services',
            component: () => import('../views/OwnerDashboard.vue'),
            meta: { requiresAuth: true, title: 'My Services', showGreeting: true },
        },
        {
            path: '/my-services/:id/plans',
            name: 'manage-plans',
            component: () => import('../views/ManagePlansView.vue'),
            meta: { requiresAuth: true, title: 'Manage Plans' },
        },
        {
            path: '/feed/:id',
            name: 'post-detail',
            component: () => import('../views/PostDetailView.vue'),
            meta: { title: 'Post Detail', subtitle: 'Community Feed' },
        },
        {
            path: '/map',
            name: 'map',
            component: () => import('../views/MapView.vue'),
            meta: { title: 'Map View', fullScreen: true },
        },
        {
            path: '/faq',
            name: 'faq',
            component: () => import('../views/FaqView.vue'),
            meta: { title: 'Help & FAQ' },
        },
        {
            path: '/terms',
            name: 'terms',
            component: () => import('../views/TermsView.vue'),
            meta: { title: 'Terms & Conditions' },
        },
        {
            path: '/privacy',
            name: 'privacy',
            component: () => import('../views/PrivacyView.vue'),
            meta: { title: 'Privacy Policy' },
        },
        {
            path: '/subscriptions',
            name: 'subscriptions',
            component: () => import('../views/SubscriptionsView.vue'),
            meta: { requiresAuth: true, title: 'My Memberships' },
        },
        {
            path: '/post/create',
            name: 'create-post',
            component: () => import('../views/CreatePostView.vue'),
            meta: { requiresAuth: true, title: 'Share Experience' },
        },
        {
            path: '/ledger',
            name: 'ledger',
            component: () => import('../views/LedgerView.vue'),
            meta: { requiresAuth: true, title: 'Ledger' },
        },
        // legacy redirects
        { path: '/owner/dashboard', redirect: '/my-services' },
        { path: '/owner/court/:id/plans', redirect: to => `/my-services/${to.params.id}/plans` },
    ],
})

const safeGetUser = () => {
    try {
        const str = localStorage.getItem('user')
        if (!str || str === 'undefined' || str === 'null') return null
        return JSON.parse(str)
    } catch {
        localStorage.removeItem('user')
        return null
    }
}

router.beforeEach((to, from, next) => {
    const token = localStorage.getItem('token')
    const user = safeGetUser()
    const isLoggedIn = !!token && !!user

    if (to.meta.requiresAuth && !isLoggedIn) {
        return next({ name: 'login' })
    }

    if (to.meta.guestOnly && isLoggedIn) {
        return next({ name: 'home' })
    }

    next()
})

export default router
