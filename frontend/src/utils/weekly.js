// Dates for a weekly booking: every chosen weekday (0 = Sunday) from start to end, at most 12 weeks.
export function weeklyDates(start, end, weekdays, maxWeeks = 12) {
  if (!start || !end || !weekdays?.length) return []
  const pad = (n) => String(n).padStart(2, '0')
  const d = new Date(`${start}T00:00:00`)
  const last = new Date(`${end}T00:00:00`)
  const cap = new Date(d)
  cap.setDate(cap.getDate() + maxWeeks * 7 - 1)
  const stop = last < cap ? last : cap
  const out = []
  for (; d <= stop; d.setDate(d.getDate() + 1)) {
    if (weekdays.includes(d.getDay())) out.push(`${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`)
  }
  return out
}
