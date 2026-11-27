// "When are you playing?" chips and day strips. Same rules as the app's
// kocourt_flutter/lib/screens/home/home_logic.dart (playTarget, nextFreeHour, hourLabel).
import { ref } from 'vue'
import axios from 'axios'

export const PLAY_TIMES = [
  { id: 'now', label: 'Now' },
  { id: 'tonight', label: 'Tonight' },
  { id: 'tomorrow', label: 'Tomorrow 7 AM' },
]

/** The chosen time, shared by every page that shows the chips (kept for the visit). */
export const playTime = ref('now')

const sqlDate = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

/** { date: 'YYYY-MM-DD', hour } a chip asks for. */
export function playTarget(choice, now = new Date()) {
  const nextHour = now.getHours() + (now.getMinutes() > 0 || now.getSeconds() > 0 ? 1 : 0)
  if (choice === 'tonight') return { date: sqlDate(now), hour: Math.max(nextHour, 19) }
  if (choice === 'tomorrow') {
    const t = new Date(now); t.setDate(t.getDate() + 1)
    return { date: sqlDate(t), hour: 7 }
  }
  return { date: sqlDate(now), hour: nextHour }
}

/** First hour at or after fromHour that a strip marks free ('f' or 'p'). */
export function nextFreeHour(strip, fromHour, firstHour = 6) {
  if (!strip) return null
  for (let i = 0; i < strip.length; i++) {
    if (firstHour + i >= fromHour && (strip[i] === 'f' || strip[i] === 'p')) return firstHour + i
  }
  return null
}

export function hourLabel(hour) {
  const h = hour % 24
  return `${h % 12 === 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}`
}

const cache = {} // date -> { id: strip }
const asked = new Set()

/** Loads strips for ids on date (8 per call) into the returned reactive map. */
export const strips = ref({})
export function ensureStrips(date, ids) {
  const missing = ids.map(String).filter((id) => !asked.has(`${date}|${id}`))
  for (let i = 0; i < missing.length; i += 8) {
    const chunk = missing.slice(i, i + 8)
    chunk.forEach((id) => asked.add(`${date}|${id}`))
    axios.get('/courts/day-strip', { params: { ids: chunk.join(','), date } })
      .then((res) => {
        cache[date] = { ...(cache[date] || {}), ...(res.data?.strips || {}) }
        strips.value = { ...strips.value, [date]: cache[date] }
      })
      .catch(() => chunk.forEach((id) => asked.delete(`${date}|${id}`))) // a hint only; retry later
  }
}
