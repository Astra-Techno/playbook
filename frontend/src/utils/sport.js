// Sport colours, labels and icons: same mapping as kocourt_shared/lib/widgets/sport_tags.dart and sport_icon.dart.
const icons = import.meta.glob('../../../kocourt_shared/assets/sports/*.svg', { query: '?raw', import: 'default', eager: true })

const SVGS = Object.fromEntries(
  Object.entries(icons).map(([path, svg]) => [path.split('/').pop().replace('.svg', ''), svg.trim()])
)

const TINTS = {
  football: ['#E7F8F0', '#047857'],
  cricket: ['#F3EEFF', '#5521B5'],
  badminton: ['#FFF4E5', '#B45309'],
  tennis: ['#E8F0FE', '#1D4ED8'],
  swimming: ['#E0F2FE', '#0369A1'],
  basketball: ['#FFEDE5', '#C2410C'],
  boxing: ['#FEECEC', '#B91C1C'],
  gym: ['#F1F2F6', '#374151'],
  pickleball: ['#F2F9E1', '#4D7C0F'],
  table_tennis: ['#FDECF3', '#BE185D'],
  volleyball: ['#E6F7F5', '#0F766E'],
}
const ALIASES = { turf: 'football', shuttle: 'badminton', basket: 'basketball', 'table tennis': 'table_tennis', tt: 'table_tennis' }

/** Icon key for a venue or match type ("turf" -> "football"); null when unknown. */
export function sportKey(type) {
  const id = String(type ?? '').trim().toLowerCase()
  const key = ALIASES[id] ?? id
  return SVGS[key] ? key : null
}

/** { bg, fg } for a sport; violet when unknown (matches the app). */
export function sportTint(type) {
  const [bg, fg] = TINTS[sportKey(type)] ?? ['#F3EEFF', '#5521B5']
  return { bg, fg }
}

/** Raw SVG; colours come from the --tone / --tint / --surface CSS variables. */
export function sportSvg(type) {
  const key = sportKey(type)
  return key ? SVGS[key] : null
}
