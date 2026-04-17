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
            path: '/onboarding',
            name: 'onboarding',
            component: () => import('../views/OnboardingView.vue'),
            meta: { guestOnly: false, title: 'Welcome to KoCourt' },
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
            path: '/my-venues',
            name: 'my-venues',
            component: () => import('../views/OwnerDashboard.vue'),
            meta: { requiresAuth: true, title: 'My Venues', showGreeting: true },
        },
        {
            path: '/my-venues/new',
            name: 'add-venue',
            component: () => import('../views/EditServiceView.vue'),
            meta: { requiresAuth: true, title: 'Add Venue' },
        },
        {
            path: '/my-venues/:id/plans',
            name: 'manage-plans',
            component: () => import('../views/ManagePlansView.vue'),
            meta: { requiresAuth: true, title: 'Manage Plans' },
        },
        {
            path: '/my-venues/:id',
            name: 'venue-detail',
            component: () => import('../views/VenueDetailView.vue'),
            meta: { requiresAuth: true, title: 'Venue Detail' },
        },
        {
            path: '/my-venues/:id/edit',
            name: 'edit-venue',
            component: () => import('../views/EditServiceView.vue'),
            meta: { requiresAuth: true, title: 'Edit Venue' },
        },
        {
            path: '/my-venues/:id/spaces',
            name: 'venue-spaces',
            component: () => import('../views/SpacesView.vue'),
            meta: { requiresAuth: true, title: 'Spaces' },
        },
        {
            path: '/my-venues/:id/spaces/:spaceId',
            name: 'space-detail',
            component: () => import('../views/SpaceDetailView.vue'),
            meta: { requiresAuth: true, title: 'Space Settings' },
        },
        {
            path: '/my-venues/:id/spaces/:spaceId/pricing',
            name: 'space-pricing',
            component: () => import('../views/PricingView.vue'),
            meta: { requiresAuth: true, title: 'Space Pricing' },
        },
        {
            path: '/my-venues/:id/spaces/:spaceId/plans',
            name: 'space-plans',
            component: () => import('../views/ManagePlansView.vue'),
            meta: { requiresAuth: true, title: 'Space Plans' },
        },
        {
            path: '/my-venues/:id/spaces/:spaceId/block',
            name: 'space-block',
            component: () => import('../views/BlockSlotsView.vue'),
            meta: { requiresAuth: true, title: 'Block Space Slots' },
        },
        {
            path: '/my-venues/:id/spaces/:spaceId/bookings',
            name: 'space-bookings',
            component: () => import('../views/SpaceBookingsView.vue'),
            meta: { requiresAuth: true, title: 'Space Bookings' },
        },
        {
            path: '/my-venues/:id/staff',
            name: 'venue-staff',
            component: () => import('../views/StaffView.vue'),
            meta: { requiresAuth: true, title: 'Staff' },
        },
        {
            path: '/my-venues/:id/pricing',
            name: 'venue-pricing',
            component: () => import('../views/PricingView.vue'),
            meta: { requiresAuth: true, title: 'Pricing' },
        },
        {
            path: '/my-venues/:id/block',
            name: 'venue-block',
            component: () => import('../views/BlockSlotsView.vue'),
            meta: { requiresAuth: true, title: 'Block Slots' },
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
        {
            path: '/admin',
            name: 'admin',
            component: () => import('../views/AdminView.vue'),
            meta: { requiresAdmin: true, title: 'Admin Panel' },
        },
        // legacy redirects
        { path: '/my-services', redirect: '/my-venues' },
        { path: '/my-services/:id/plans', redirect: to => `/my-venues/${to.params.id}/plans` },
        { path: '/my-services/:id/edit', redirect: to => `/my-venues/${to.params.id}/edit` },
        { path: '/owner/dashboard', redirect: '/my-venues' },
        { path: '/owner/court/:id/plans', redirect: to => `/my-venues/${to.params.id}/plans` },
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

    // Onboarding — show once per device, only for first visit to home/root
    if (to.name === 'home' && !localStorage.getItem('kocourt_onboarding')) {
        return next({ name: 'onboarding' })
    }

    if (to.meta.requiresAdmin && (!isLoggedIn || user?.role !== 'admin')) {
        return next({ name: 'home' })
    }

    if (to.meta.requiresAuth && !isLoggedIn) {
        return next({ name: 'login' })
    }

    if (to.meta.guestOnly && isLoggedIn) {
        return next({ name: 'home' })
    }

    next()
})

export default router
