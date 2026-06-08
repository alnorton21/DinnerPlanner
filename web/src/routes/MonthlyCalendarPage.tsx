import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import {
  addDays,
  addMonths,
  format,
  isSameDay,
  isSameMonth,
  startOfMonth,
  startOfWeek,
} from 'date-fns'
import { supabase } from '../lib/supabase'
import { PageHeader } from '../components/PageHeader'

const DAY_HEADERS = ['M', 'T', 'W', 'T', 'F', 'S', 'S']

function weekStartOf(date: Date): Date {
  return startOfWeek(date, { weekStartsOn: 1 })
}

function dateKey(date: Date): string {
  return format(date, 'yyyy-MM-dd')
}

async function fetchPlannedDays(rangeStart: string, rangeEnd: string): Promise<Set<string>> {
  const { data, error } = await supabase
    .from('meal_plans')
    .select('week_start, day_of_week')
    .gte('week_start', rangeStart)
    .lte('week_start', rangeEnd)
  if (error) throw error

  const planned = new Set<string>()
  for (const row of data ?? []) {
    const weekStart = new Date(`${row.week_start}T00:00:00`)
    const day = addDays(weekStart, row.day_of_week as number)
    planned.add(dateKey(day))
  }
  return planned
}

function buildCalendarWeeks(displayMonth: Date): (Date | null)[][] {
  const gridStart = weekStartOf(startOfMonth(displayMonth))

  const weeks: (Date | null)[][] = []
  let cursor = gridStart
  for (let row = 0; row < 6; row++) {
    const week: (Date | null)[] = []
    for (let i = 0; i < 7; i++) {
      week.push(isSameMonth(cursor, displayMonth) ? cursor : null)
      cursor = addDays(cursor, 1)
    }
    weeks.push(week)
  }
  return weeks
}

export function MonthlyCalendarPage() {
  const navigate = useNavigate()
  const today = new Date()
  const [displayMonth, setDisplayMonth] = useState(() => startOfMonth(today))
  const [selectedWeekStart, setSelectedWeekStart] = useState(() => weekStartOf(today))

  const monthStart = startOfMonth(displayMonth)
  const gridStart = weekStartOf(monthStart)
  const gridEnd = addDays(gridStart, 41)

  const { data: plannedDays = new Set<string>(), isLoading } = useQuery({
    queryKey: ['plannedDays', dateKey(gridStart), dateKey(gridEnd)],
    queryFn: () => fetchPlannedDays(dateKey(weekStartOf(gridStart)), dateKey(weekStartOf(gridEnd))),
  })

  const weeks = buildCalendarWeeks(displayMonth)

  function weekStartForRow(row: (Date | null)[]): Date {
    const firstNonNull = row.find((d) => d !== null)
    const anchor = firstNonNull ?? row[0]
    return weekStartOf(anchor as Date)
  }

  return (
    <div>
      <PageHeader title="Monthly Calendar" />
      <div className="page-content">
        <div className="card" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <button className="icon-btn" onClick={() => setDisplayMonth((m) => addMonths(m, -1))} aria-label="Previous month">
            ‹
          </button>
          <span style={{ fontWeight: 700, fontSize: 16 }}>{format(displayMonth, 'MMMM yyyy')}</span>
          <button className="icon-btn" onClick={() => setDisplayMonth((m) => addMonths(m, 1))} aria-label="Next month">
            ›
          </button>
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 8 }}>
          <button
            className="btn-text"
            onClick={() => {
              setDisplayMonth(startOfMonth(today))
              setSelectedWeekStart(weekStartOf(today))
            }}
          >
            Today
          </button>
        </div>

        <div className="card" style={{ padding: 12, position: 'relative' }}>
          {isLoading && (
            <div style={{ position: 'absolute', top: 12, right: 12 }}>
              <span className="spinner" />
            </div>
          )}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4, marginBottom: 6 }}>
            {DAY_HEADERS.map((h, i) => (
              <div key={i} style={{ textAlign: 'center', fontSize: 12, fontWeight: 700, opacity: 0.6 }}>
                {h}
              </div>
            ))}
          </div>

          {weeks.map((row, rowIndex) => {
            const rowWeekStart = weekStartForRow(row)
            const isSelectedWeek = isSameDay(rowWeekStart, selectedWeekStart)
            return (
              <div
                key={rowIndex}
                onClick={() => setSelectedWeekStart(rowWeekStart)}
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(7, 1fr)',
                  gap: 4,
                  marginBottom: 4,
                  padding: 4,
                  borderRadius: 10,
                  cursor: 'pointer',
                  background: isSelectedWeek ? 'color-mix(in srgb, var(--color-primary) 16%, transparent)' : 'transparent',
                }}
              >
                {row.map((day, dayIndex) => {
                  if (!day) return <div key={dayIndex} />
                  const isToday = isSameDay(day, today)
                  const isPlanned = plannedDays.has(dateKey(day))
                  return (
                    <div key={dayIndex} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, padding: '4px 0' }}>
                      <span
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          width: 28,
                          height: 28,
                          borderRadius: '50%',
                          fontSize: 13,
                          fontWeight: isToday ? 700 : 400,
                          background: isToday ? 'var(--color-primary)' : 'transparent',
                          color: isToday ? 'var(--color-on-primary)' : 'inherit',
                        }}
                      >
                        {format(day, 'd')}
                      </span>
                      <span
                        style={{
                          width: 5,
                          height: 5,
                          borderRadius: '50%',
                          background: isPlanned ? 'var(--color-primary)' : 'transparent',
                        }}
                      />
                    </div>
                  )
                })}
              </div>
            )
          })}
        </div>

        <button
          className="btn btn-primary"
          style={{ width: '100%', marginTop: 16 }}
          onClick={() => navigate('/planner', { state: { weekStart: dateKey(selectedWeekStart) } })}
        >
          View Selected Week ({format(selectedWeekStart, 'MMM d')} – {format(addDays(selectedWeekStart, 6), 'MMM d')})
        </button>
      </div>
    </div>
  )
}
