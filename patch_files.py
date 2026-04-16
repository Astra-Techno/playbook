import os

# ── EditServiceView.vue ───────────────────────────────────────────────────────
edit_src = open('frontend/src/views/EditServiceView.vue', encoding='utf-8').read()

# Script section patches
edit_src = (edit_src
    .replace("import { ref, onMounted } from 'vue'",
             "import { ref, computed, onMounted } from 'vue'")
    .replace("const courtId = parseInt(route.params.id)\n"
             "const loading  = ref(true)",
             "const isCreate   = route.params.id === 'new' || !route.params.id\n"
             "const courtId    = isCreate ? null : parseInt(route.params.id)\n"
             "const loading    = ref(isCreate ? false : true)")
    .replace("    Sun, Moon, Lock\n} from 'lucide-vue-next'",
             "    Sun, Moon, Lock, ChevronDown\n} from 'lucide-vue-next'")
    .replace("const imagePreview = ref(null)\n",
             "const imagePreview = ref(null)\nconst showPeakHours = ref(false)\n")
)

# Add pageTitle/saveLabel before onMounted
insert_computed = (
    "\nconst pageTitle = computed(() => isCreate ? 'Add Venue' : 'Edit Venue')\n"
    "const saveLabel = computed(() => isCreate ? 'Add Venue' : 'Save Changes')\n"
)
edit_src = edit_src.replace("\nonMounted(async () => {", insert_computed + "\nonMounted(async () => {", 1)

# Guard onMounted for create mode
edit_src = edit_src.replace(
    "onMounted(async () => {\n    try {",
    "onMounted(async () => {\n    if (isCreate) return\n    try {"
)

# Fix redirect in onMounted
edit_src = edit_src.replace("router.replace('/my-services')", "router.replace('/my-venues')")

# Fix save function
edit_src = edit_src.replace(
    "    try {\n"
    "        await axios.put(`/courts/${courtId}`, { ...form.value, owner_id: auth.user?.id })\n"
    "        toast.success('Service updated!')\n"
    "        router.replace('/my-services')\n"
    "    } catch { toast.error('Update failed') }",
    "    try {\n"
    "        if (isCreate) {\n"
    "            await axios.post('/courts', { ...form.value, owner_id: auth.user?.id })\n"
    "            toast.success('Venue added!')\n"
    "        } else {\n"
    "            await axios.put(`/courts/${courtId}`, { ...form.value, owner_id: auth.user?.id })\n"
    "            toast.success('Venue updated!')\n"
    "        }\n"
    "        router.replace('/my-venues')\n"
    "    } catch { toast.error(isCreate ? 'Could not add venue' : 'Update failed') }"
)

# Template section patches
edit_src = (edit_src
    .replace('<h1 class="flex-1 font-extrabold text-slate-900 text-base truncate">Edit Service</h1>',
             '<h1 class="flex-1 font-extrabold text-slate-900 text-base truncate">{{ pageTitle }}</h1>')
    .replace('<label class="block text-xs font-semibold text-slate-500 mb-1">Service Name *</label>',
             '<label class="block text-xs font-semibold text-slate-500 mb-1">Venue Name *</label>')
    .replace('<p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Sport Type</p>',
             '<p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Primary Sport</p>')
    .replace('                Save Changes\n',
             '                {{ saveLabel }}\n')
    .replace("placeholder=\"e.g. GS Badminton Academy\"",
             "placeholder=\"e.g. GS Sports Arena\"")
    .replace("placeholder=\"Describe your court, facilities, etc.\"",
             "placeholder=\"Describe your venue, facilities, etc.\"")
    .replace('<label class="block text-xs font-semibold text-slate-500 mb-1">Rate per Hour (\u20b9) *</label>',
             '<label class="block text-xs font-semibold text-slate-500 mb-1">Base Rate per Hour (\u20b9) *</label>\n'
             '                    <p class="text-[11px] text-slate-400 mt-1.5">You can set per-court rates from the Services section</p>')
    # Make peak hours collapsible
    .replace(
        '            <!-- \u2500\u2500 Peak Hours \u2500\u2500 -->\n'
        '            <div class="bg-white rounded-2xl px-4 py-4 ring-1 ring-slate-100 shadow-sm">\n'
        '                <div class="flex items-center justify-between mb-3">\n'
        '                    <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Peak Hours</p>\n'
        '                    <!-- Toggle -->\n'
        '                    <label class="relative flex items-center gap-2 cursor-pointer">\n'
        '                        <span class="text-xs font-semibold text-slate-500">Members only</span>\n'
        '                        <div class="relative">\n'
        '                            <input type="checkbox" v-model="form.peak_members_only" class="sr-only peer" />\n'
        '                            <div class="w-10 h-5 bg-slate-200 rounded-full peer peer-checked:bg-primary transition-colors"></div>\n'
        '                            <div class="absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform peer-checked:translate-x-5"></div>\n'
        '                        </div>\n'
        '                    </label>\n'
        '                </div>\n'
        '\n'
        '                <div class="space-y-3">',
        '            <!-- \u2500\u2500 Peak Hours \u2500\u2500 -->\n'
        '            <div class="bg-white rounded-2xl ring-1 ring-slate-100 shadow-sm overflow-hidden">\n'
        '                <button @click="showPeakHours = !showPeakHours"\n'
        '                    class="w-full flex items-center justify-between px-4 py-4">\n'
        '                    <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Peak Hours</p>\n'
        '                    <ChevronDown :size="16" class="text-slate-400 transition-transform"\n'
        '                        :class="showPeakHours ? \'rotate-180\' : \'\'" />\n'
        '                </button>\n'
        '\n'
        '                <div v-if="showPeakHours" class="px-4 pb-4 space-y-3">\n'
        '                <div class="flex items-center justify-between mb-1">\n'
        '                    <p class="text-xs text-slate-500">Restrict peak slots to members only</p>\n'
        '                    <label class="relative flex items-center cursor-pointer">\n'
        '                        <input type="checkbox" v-model="form.peak_members_only" class="sr-only peer" />\n'
        '                        <div class="w-10 h-5 bg-slate-200 rounded-full peer peer-checked:bg-primary transition-colors"></div>\n'
        '                        <div class="absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform peer-checked:translate-x-5"></div>\n'
        '                    </label>\n'
        '                </div>\n'
        '\n'
        '                <div class="space-y-3">'
    )
)

# Close the new collapsible section
edit_src = edit_src.replace(
    '                </div>\n'
    '            </div>\n'
    '\n'
    '            <!-- \u2500\u2500 Amenities \u2500\u2500 -->',
    '                </div>\n'
    '                </div>\n'
    '            </div>\n'
    '\n'
    '            <!-- \u2500\u2500 Amenities \u2500\u2500 -->',
    1
)

open('frontend/src/views/EditServiceView.vue', 'w', encoding='utf-8').write(edit_src)
print('EditServiceView patched successfully')
