// Matchday formats, same rules as kocourt_shared/lib/core/format.dart:
// money without stray decimals (Indian grouping), friendly days, compact clocks.
const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

/** "₹500", "₹1,200", "₹1,20,000", "₹99.50"; '' for non-numbers. */
export function rupees(value) {
  const n = Number(String(value ?? '').replaceAll(',', ''))
  if (value === null || value === undefined || value === '' || Number.isNaN(n)) return ''
  const whole = Number.isInteger(n)
  const [int, dec] = (whole ? String(Math.abs(Math.round(n))) : Math.abs(n).toFixed(2)).split('.')
  const grouped = int.length > 3 ? `${int.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ',')},${int.slice(-3)}` : int
  return `${n < 0 ? '-' : ''}₹${grouped}${dec ? `.${dec}` : ''}`
}

const parse = (v) => (v instanceof Date ? v : v ? new Date(String(v).replace(' ', 'T')) : null)

/** "Today", "Tomorrow", "Yesterday" or "Wed 26 Nov" (year added when it differs). */
export function friendlyDay(value, now = new Date()) {
  const d = parse(value)
  if (!d || Number.isNaN(d.getTime())) return ''
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const diff = Math.round((day - today) / 86400000)
  if (diff === 0) return 'Today'
  if (diff === 1) return 'Tomorrow'
  if (diff === -1) return 'Yesterday'
  const base = `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}`
  return d.getFullYear() === now.getFullYear() ? base : `${base} ${d.getFullYear()}`
}

/** "6 PM", "6:30 PM" from a Date, "18:00:00" or "2026-11-27 18:30:00". */
export function clock(value) {
  let h, m
  if (value instanceof Date) { h = value.getHours(); m = value.getMinutes() } else {
    const p = String(value ?? '').split(' ').pop().split(':')
    if (p.length < 2) return ''
    h = Number(p[0]); m = Number(p[1])
  }
  if (Number.isNaN(h) || Number.isNaN(m)) return ''
  const h12 = h % 12 === 0 ? 12 : h % 12
  return `${h12}${m ? `:${String(m).padStart(2, '0')}` : ''} ${h < 12 ? 'AM' : 'PM'}`
}

/** "6–7 PM", "11 AM–1 PM". */
export function clockRange(start, end) {
  const a = clock(start), b = clock(end)
  if (!a) return b
  if (!b) return a
  return `${a.slice(-2) === b.slice(-2) ? a.slice(0, -3) : a}–${b}`
}

/** "now", "5m", "3h", "2d", then the friendly day. */
export function timeAgo(value, now = new Date()) {
  const d = parse(value)
  if (!d || Number.isNaN(d.getTime())) return ''
  const mins = Math.floor((now - d) / 60000)
  if (mins < 1) return 'now'
  if (mins < 60) return `${mins}m`
  if (mins < 1440) return `${Math.floor(mins / 60)}h`
  if (mins < 10080) return `${Math.floor(mins / 1440)}d`
  return friendlyDay(d, now)
}
