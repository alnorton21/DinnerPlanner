import { useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { addDays, addWeeks, format, parseISO, startOfWeek } from 'date-fns'
import { supabase } from '../lib/supabase'
import { useAuth } from '../hooks/useAuth'
import { type Meal, mealFromJson } from '../types/meal'
import { type MealPlan, DAY_NAMES, MEAL_SLOTS } from '../types/mealPlan'
import { addMealPlanEntry, clearMealPlanSlot, getMealPlan } from '../services/supabaseService'
import { PageHeader } from '../components/PageHeader'

const DAY_ABBR = ['M', 'T', 'W', 'T', 'F', 'S', 'S']
const MACRO_COLORS = { calories: '#fb8c00', protein: '#1e88e5', carbs: '#43a047', fat: '#e53935' }

function weekStartOf(date: Date): Date {
  return startOfWeek(date, { weekStartsOn: 1 })
}

function weekStartKey(date: Date): string {
  return format(date, 'yyyy-MM-dd')
}

async function fetchAllMeals(): Promise<Meal[]> {
  const { data, error } = await supabase.from('meals').select().order('id', { ascending: false })
  if (error) throw error
  return (data ?? []).map(mealFromJson)
}

interface DayNutrition {
  calories: number
  protein: number
  carbs: number
  fat: number
}

function sumDayNutrition(plans: MealPlan[], dayIndex: number): DayNutrition {
  return plans
    .filter((p) => p.dayOfWeek === dayIndex && p.mealId != null)
    .reduce(
      (acc, p) => ({
        calories: acc.calories + p.mealCalories,
        protein: acc.protein + p.mealProtein,
        carbs: acc.carbs + p.mealCarbs,
        fat: acc.fat + p.mealFat,
      }),
      { calories: 0, protein: 0, carbs: 0, fat: 0 },
    )
}

export function MealPlannerPage() {
  const location = useLocation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { session } = useAuth()
  const userId = session!.user.id

  const initialWeekStart = (location.state as { weekStart?: string } | null)?.weekStart
  const [currentWeekStart, setCurrentWeekStart] = useState(() =>
    initialWeekStart ? weekStartOf(parseISO(initialWeekStart)) : weekStartOf(new Date()),
  )
  const [summaryExpanded, setSummaryExpanded] = useState(true)
  const [slotPicker, setSlotPicker] = useState<{ dayIndex: number; slot: (typeof MEAL_SLOTS)[number] } | null>(null)

  const weekStartStr = weekStartKey(currentWeekStart)
  const weekEnd = addDays(currentWeekStart, 6)
  const weekLabel = `${format(currentWeekStart, 'MMM d')} – ${format(weekEnd, 'MMM d')}`

  const { data: plans = [], isLoading } = useQuery({
    queryKey: ['mealPlan', weekStartStr],
    queryFn: () => getMealPlan(weekStartStr),
  })

  const { data: goals } = useQuery({
    queryKey: ['userGoals', userId],
    queryFn: async () => {
      const { data } = await supabase
        .from('user_profiles')
        .select('calorie_goal, protein_goal, carb_goal, fat_goal')
        .eq('user_id', userId)
        .maybeSingle()
      return data
    },
  })
  const calTarget = Number(goals?.calorie_goal ?? 2000)
  const proTarget = Number(goals?.protein_goal ?? 150)
  const carbTarget = Number(goals?.carb_goal ?? 250)
  const fatTarget = Number(goals?.fat_goal ?? 65)

  const { data: allMeals = [] } = useQuery({
    queryKey: ['meals'],
    queryFn: fetchAllMeals,
    enabled: !!slotPicker,
  })

  function navigateWeek(direction: number) {
    setCurrentWeekStart((prev) => addWeeks(prev, direction))
  }

  function getMealsForSlot(dayIndex: number, slot: string) {
    return plans.filter((p) => p.dayOfWeek === dayIndex && p.mealSlot === slot && p.mealId != null)
  }

  async function assignMeal(dayIndex: number, slot: (typeof MEAL_SLOTS)[number], meal: Meal) {
    const plan: MealPlan = {
      userId,
      weekStart: weekStartStr,
      dayOfWeek: dayIndex,
      mealSlot: slot,
      mealId: meal.id,
      mealName: meal.name,
      mealImageUrl: meal.imageUrl,
      mealCalories: 0,
      mealProtein: 0,
      mealCarbs: 0,
      mealFat: 0,
    }
    await addMealPlanEntry(plan)
    setSlotPicker(null)
    queryClient.invalidateQueries({ queryKey: ['mealPlan', weekStartStr] })
  }

  async function removeEntry(planId: number) {
    await clearMealPlanSlot(planId)
    queryClient.invalidateQueries({ queryKey: ['mealPlan', weekStartStr] })
  }

  // ── Weekly summary ───────────────────────────────────────────────────────

  const dayNutrition = Array.from({ length: 7 }, (_, i) => sumDayNutrition(plans, i))
  const daysWithData = dayNutrition.filter((n) => n.calories > 0)
  const weekAvg =
    daysWithData.length > 0
      ? {
          calories: daysWithData.reduce((s, n) => s + n.calories, 0) / daysWithData.length,
          protein: daysWithData.reduce((s, n) => s + n.protein, 0) / daysWithData.length,
          carbs: daysWithData.reduce((s, n) => s + n.carbs, 0) / daysWithData.length,
          fat: daysWithData.reduce((s, n) => s + n.fat, 0) / daysWithData.length,
        }
      : null

  return (
    <div>
      <PageHeader
        title={
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <button className="icon-btn" onClick={() => navigateWeek(-1)} aria-label="Previous week">
              ‹
            </button>
            <span style={{ fontSize: 15, fontWeight: 700 }}>{weekLabel}</span>
            <button className="icon-btn" onClick={() => navigateWeek(1)} aria-label="Next week">
              ›
            </button>
          </span>
        }
        actions={
          <button
            className="icon-btn"
            title="Shopping List"
            onClick={() => navigate('/shopping-list', { state: { weekStart: weekStartStr } })}
          >
            🛒
          </button>
        }
      />

      <div className="page-content">
        {isLoading ? (
          <div className="empty-state">
            <span className="spinner" />
          </div>
        ) : (
          <>
            <div className="card" style={{ marginBottom: 12, padding: 0 }}>
              <button
                onClick={() => setSummaryExpanded((v) => !v)}
                style={{
                  display: 'flex',
                  width: '100%',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: 'inherit',
                  font: 'inherit',
                  padding: '12px 14px',
                }}
              >
                <span style={{ fontWeight: 700, fontSize: 15 }}>Weekly Summary</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  {weekAvg && <span style={{ fontSize: 12, opacity: 0.6 }}>{weekAvg.calories.toFixed(0)} cal/day avg</span>}
                  <span style={{ opacity: 0.6 }}>{summaryExpanded ? '▾' : '▸'}</span>
                </span>
              </button>

              {summaryExpanded && (
                <div style={{ padding: '0 14px 16px' }}>
                  <hr style={{ border: 'none', borderTop: '1px solid var(--color-outline-variant)', margin: '0 0 12px' }} />
                  {!weekAvg ? (
                    <p style={{ fontSize: 13, opacity: 0.5, padding: '8px 0' }}>Add meals to see your weekly summary</p>
                  ) : (
                    <>
                      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 80 }}>
                        {dayNutrition.map((n, i) => {
                          const ratio = Math.min(n.calories / calTarget, 1.5)
                          const barHeight = Math.max(ratio * 56, n.calories > 0 ? 2 : 0)
                          const color = n.calories <= calTarget ? '#43a047' : n.calories <= calTarget * 1.2 ? '#fb8c00' : '#e53935'
                          return (
                            <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-end', height: '100%' }}>
                              <div
                                style={{
                                  width: '100%',
                                  maxWidth: 22,
                                  height: barHeight,
                                  background: n.calories > 0 ? color : 'var(--color-surface-container-highest)',
                                  borderRadius: 3,
                                }}
                              />
                              <span style={{ fontSize: 11, opacity: 0.6, marginTop: 4 }}>{DAY_ABBR[i]}</span>
                              {n.calories > 0 && <span style={{ fontSize: 9 }}>{n.calories.toFixed(0)}</span>}
                            </div>
                          )
                        })}
                      </div>
                      <p style={{ textAlign: 'center', fontSize: 11, opacity: 0.5, margin: '4px 0 10px' }}>
                        Target: {calTarget.toFixed(0)} cal/day
                      </p>
                      <hr style={{ border: 'none', borderTop: '1px solid var(--color-outline-variant)', margin: '0 0 10px' }} />
                      <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: 6, fontSize: 12 }}>
                        <span style={{ fontWeight: 600 }}>Weekly avg:</span>
                        <span style={{ color: MACRO_COLORS.protein }}>{weekAvg.protein.toFixed(1)} g protein</span>
                        <span style={{ color: MACRO_COLORS.carbs }}>{weekAvg.carbs.toFixed(1)} g carbs</span>
                        <span style={{ color: MACRO_COLORS.fat }}>{weekAvg.fat.toFixed(1)} g fat</span>
                      </div>
                    </>
                  )}
                </div>
              )}
            </div>

            {Array.from({ length: 7 }, (_, dayIndex) => (
              <DaySection
                key={dayIndex}
                dayIndex={dayIndex}
                date={addDays(currentWeekStart, dayIndex)}
                nutrition={dayNutrition[dayIndex]}
                targets={{ calories: calTarget, protein: proTarget, carbs: carbTarget, fat: fatTarget }}
                getMealsForSlot={getMealsForSlot}
                onAddToSlot={(slot) => setSlotPicker({ dayIndex, slot })}
                onRemoveEntry={removeEntry}
                onOpenMeal={(mealId) => navigate(`/meals/${mealId}`)}
              />
            ))}
          </>
        )}
      </div>

      {slotPicker && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'flex-end', justifyContent: 'center', zIndex: 150 }}
          onClick={() => setSlotPicker(null)}
        >
          <div
            className="card"
            style={{ width: '100%', maxWidth: 480, maxHeight: '75vh', display: 'flex', flexDirection: 'column', borderRadius: '20px 20px 0 0', margin: 0 }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ marginTop: 0 }}>
              Add meal to {DAY_NAMES[slotPicker.dayIndex]} {slotPicker.slot[0].toUpperCase() + slotPicker.slot.slice(1)}
            </h3>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {allMeals.length === 0 ? (
                <p style={{ opacity: 0.6, textAlign: 'center', padding: 24 }}>No meals found. Add meals first.</p>
              ) : (
                allMeals.map((meal) => (
                  <button
                    key={meal.id}
                    onClick={() => assignMeal(slotPicker.dayIndex, slotPicker.slot, meal)}
                    style={{
                      display: 'flex',
                      width: '100%',
                      alignItems: 'center',
                      gap: 12,
                      padding: '10px 4px',
                      background: 'none',
                      border: 'none',
                      borderBottom: '1px solid var(--color-outline-variant)',
                      cursor: 'pointer',
                      color: 'inherit',
                      font: 'inherit',
                      textAlign: 'left',
                    }}
                  >
                    {meal.imageUrl ? (
                      <img src={meal.imageUrl} alt="" style={{ width: 48, height: 48, borderRadius: 6, objectFit: 'cover' }} />
                    ) : (
                      <span style={{ fontSize: 28 }}>🍽️</span>
                    )}
                    <span style={{ fontSize: 14 }}>{meal.name}</span>
                  </button>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

interface DaySectionProps {
  dayIndex: number
  date: Date
  nutrition: DayNutrition
  targets: DayNutrition
  getMealsForSlot: (dayIndex: number, slot: string) => MealPlan[]
  onAddToSlot: (slot: (typeof MEAL_SLOTS)[number]) => void
  onRemoveEntry: (planId: number) => void
  onOpenMeal: (mealId: number) => void
}

function DaySection({ dayIndex, date, nutrition, targets, getMealsForSlot, onAddToSlot, onRemoveEntry, onOpenMeal }: DaySectionProps) {
  const hasNutrition = nutrition.calories > 0

  return (
    <div style={{ marginBottom: 14 }}>
      <div
        style={{
          padding: '10px 12px',
          borderRadius: 10,
          background: 'color-mix(in srgb, var(--color-primary) 12%, transparent)',
          marginBottom: 6,
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <span style={{ fontWeight: 700, fontSize: 15 }}>
            {DAY_NAMES[dayIndex]}, {format(date, 'MMM d')}
          </span>
          {hasNutrition && <span style={{ fontSize: 12, fontWeight: 600, opacity: 0.7 }}>{nutrition.calories.toFixed(0)} cal</span>}
        </div>
        {hasNutrition && (
          <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 4 }}>
            <MacroBar label="Cal" value={nutrition.calories} target={targets.calories} unit="cal" color={MACRO_COLORS.calories} />
            <MacroBar label="Protein" value={nutrition.protein} target={targets.protein} unit="g" color={MACRO_COLORS.protein} />
            <MacroBar label="Carbs" value={nutrition.carbs} target={targets.carbs} unit="g" color={MACRO_COLORS.carbs} />
            <MacroBar label="Fat" value={nutrition.fat} target={targets.fat} unit="g" color={MACRO_COLORS.fat} />
          </div>
        )}
      </div>

      {MEAL_SLOTS.map((slot) => {
        const meals = getMealsForSlot(dayIndex, slot)
        const slotLabel = slot[0].toUpperCase() + slot.slice(1)
        return (
          <div key={slot} className="card" style={{ marginBottom: 6, padding: '8px 12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontWeight: 600, fontSize: 13, color: 'var(--color-primary)' }}>{slotLabel}</span>
              <button className="btn-text" style={{ fontSize: 13, padding: '2px 6px' }} onClick={() => onAddToSlot(slot)}>
                + Add
              </button>
            </div>
            {meals.length === 0 ? (
              <p style={{ fontSize: 13, fontStyle: 'italic', opacity: 0.5, margin: '2px 0 4px' }}>No meals added</p>
            ) : (
              meals.map((plan) => (
                <div key={plan.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0' }}>
                  <div
                    style={{ cursor: plan.mealId ? 'pointer' : 'default', display: 'flex', alignItems: 'center', gap: 8, flex: 1, minWidth: 0 }}
                    onClick={() => plan.mealId && onOpenMeal(plan.mealId)}
                  >
                    {plan.mealImageUrl ? (
                      <img src={plan.mealImageUrl} alt="" style={{ width: 36, height: 36, borderRadius: 4, objectFit: 'cover' }} />
                    ) : (
                      <span style={{ fontSize: 28 }}>🍽️</span>
                    )}
                    <div style={{ minWidth: 0 }}>
                      <p style={{ margin: 0, fontSize: 14, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{plan.mealName}</p>
                      {plan.mealCalories > 0 && (
                        <p style={{ margin: 0, fontSize: 11, opacity: 0.6 }}>{plan.mealCalories.toFixed(0)} cal / serving</p>
                      )}
                    </div>
                  </div>
                  <button className="icon-btn" style={{ width: 28, height: 28 }} onClick={() => plan.id && onRemoveEntry(plan.id)} aria-label="Remove">
                    ✕
                  </button>
                </div>
              ))
            )}
          </div>
        )
      })}
    </div>
  )
}

function MacroBar({ label, value, target, unit, color }: { label: string; value: number; target: number; unit: string; color: string }) {
  const progress = Math.min(value / target, 1)
  const valueText = Number.isInteger(value) ? value.toFixed(0) : value.toFixed(1)
  const targetText = target.toFixed(0)

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
      <span style={{ width: 44, fontSize: 11, opacity: 0.7 }}>{label}</span>
      <div style={{ flex: 1, height: 7, borderRadius: 4, background: `color-mix(in srgb, ${color} 15%, transparent)`, overflow: 'hidden' }}>
        <div style={{ width: `${progress * 100}%`, height: '100%', background: color, borderRadius: 4 }} />
      </div>
      <span style={{ width: 76, fontSize: 10, opacity: 0.6, textAlign: 'right' }}>
        {valueText} / {targetText} {unit}
      </span>
    </div>
  )
}
