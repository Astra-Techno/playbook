src = open('frontend/src/views/OwnerDashboard.vue', encoding='utf-8').read()

# Fix import - remove unused icons, keep needed ones
src = src.replace(
    "    IndianRupee, LocateFixed, Loader2, Sun, Moon, Shield,\n"
    "    Camera, Trash2, TrendingUp, CalendarDays, Search, MapPin,",
    "    IndianRupee, Loader2,\n"
    "    Camera, TrendingUp, CalendarDays, Search, MapPin,"
)

# Remove showAddForm ref
src = src.replace("const showAddForm = ref(false)\n", "")

# Remove AMENITIES_LIST
src = src.replace(
    "const AMENITIES_LIST = ['Parking', 'Floodlights', 'Changing Room', 'Shower', 'Equipment Rental', 'Cafeteria', 'WiFi', 'First Aid']\n\n",
    ""
)

# Remove newCourt ref block
import re
src = re.sub(
    r"const newCourt = ref\(\{[^}]+\}\)\n\nconst imagePreview = ref\(null\)\nconst uploadLoading = ref\(false\)\n",
    "",
    src,
    flags=re.DOTALL
)

# Remove handleImageSelect function
src = re.sub(
    r"const handleImageSelect = async \(event\) => \{[^}]+\}\n    \} finally \{[^}]+\}\n\}\n\nconst clearImage = \(\) => \{[^}]+\}\n\n",
    "",
    src,
    flags=re.DOTALL
)

# Remove editImagePreview and editUploadLoading
src = src.replace(
    "// Edit court — navigate to dedicated page\n"
    "const editImagePreview = ref(null)   // kept for compat, unused\n"
    "const editUploadLoading = ref(false) // kept for compat, unused\n\n",
    ""
)

# Remove hasPeakHours, addLoading, geoLoading
src = src.replace(
    "const hasPeakHours = computed(() => newCourt.value.type !== 'turf' && newCourt.value.type !== 'cricket')\n"
    "const addLoading    = ref(false)\n"
    "const geoLoading    = ref(false)\n",
    ""
)

# Remove geocodeLocation + detectCourtLocation functions
src = re.sub(
    r"const geocodeLocation = async \(text\) => \{.*?return null\n\}\n\nconst detectCourtLocation = \(\) => \{.*?\}\n\nconst sportFilters",
    "const sportFilters",
    src,
    flags=re.DOTALL
)

# Remove addCourt function
src = re.sub(
    r"const addCourt = async \(\) => \{.*?\}\n\nconst openEdit",
    "const openEdit",
    src,
    flags=re.DOTALL
)

# Fix openEdit route
src = src.replace(
    "    router.push(`/my-services/${court.id}/edit`)",
    "    router.push(`/my-venues/${court.id}/edit`)"
)

# Remove unused saveEdit stub if present
src = src.replace(
    "const saveEdit = async () => {} // unused — handled by EditServiceView\n\n",
    ""
)

# Fix section header title
src = src.replace(
    "'My Services'",
    "'My Venues'"
)

# Fix Add Service button -> navigate to /my-venues/new
src = src.replace(
    "                    @click=\"showAddForm = true\"\n"
    "                    class=\"text-primary text-sm font-semibold\">\n"
    "                    + Add Service",
    "                    @click=\"router.push('/my-venues/new')\"\n"
    "                    class=\"text-primary text-sm font-semibold\">\n"
    "                    + Add Venue"
)

# Fix empty state
src = src.replace(
    '                    <p class="font-extrabold text-slate-700 text-lg">No services yet</p>\n'
    '                    <p class="text-sm text-slate-400 mt-1 mb-6">Services you list will appear here</p>\n'
    '                    <button @click="showAddForm = true"',
    '                    <p class="font-extrabold text-slate-700 text-lg">No venues yet</p>\n'
    '                    <p class="text-sm text-slate-400 mt-1 mb-6">Venues you list will appear here</p>\n'
    '                    <button @click="router.push(\'/my-venues/new\')"'
)

# Fix Plans RouterLink
src = src.replace(
    "                                    <RouterLink :to=\"`/my-services/${court.id}/plans`\"",
    "                                    <RouterLink :to=\"`/my-venues/${court.id}/plans`\""
)

# Remove the entire ADD COURT MODAL bottom sheet
sheet_start = "        <!-- \u2500\u2500 ADD COURT MODAL (bottom sheet) \u2500\u2500 -->"
sheet_end = "        <!-- Edit now navigates to /my-services/:id/edit (EditServiceView) -->\n\n"
idx_start = src.find(sheet_start)
idx_end = src.find(sheet_end)
if idx_start != -1 and idx_end != -1:
    src = src[:idx_start] + src[idx_end + len(sheet_end):]

open('frontend/src/views/OwnerDashboard.vue', 'w', encoding='utf-8').write(src)
print('OwnerDashboard patched successfully')
print('showAddForm remaining:', src.count('showAddForm'))
print('my-venues count:', src.count('my-venues'))
