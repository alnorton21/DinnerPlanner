import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AuthProvider, useAuth } from './hooks/useAuth'
import { ThemeProvider } from './hooks/useTheme'
import { AuthPage } from './routes/AuthPage'
import { ResetPasswordPage } from './routes/ResetPasswordPage'
import { UpdatePasswordPage } from './routes/UpdatePasswordPage'
import { HomePage } from './routes/HomePage'
import { ProfilePage } from './routes/ProfilePage'
import { MealListPage } from './routes/MealListPage'
import { MealDetailPage } from './routes/MealDetailPage'
import { AddMealPage } from './routes/AddMealPage'
import { EditMealPage } from './routes/EditMealPage'
import { MealPlannerPage } from './routes/MealPlannerPage'
import { MonthlyCalendarPage } from './routes/MonthlyCalendarPage'
import { ShoppingListPage } from './routes/ShoppingListPage'
import { MyGroceriesPage } from './routes/MyGroceriesPage'
import { StoreListPage } from './routes/StoreListPage'
import { StorePreferencesPage } from './routes/StorePreferencesPage'

const queryClient = new QueryClient()

function Gate() {
  const { session, loading, isPasswordRecovery } = useAuth()

  if (loading) {
    return (
      <div className="empty-state">
        <span className="spinner" />
      </div>
    )
  }

  if (isPasswordRecovery) {
    return (
      <Routes>
        <Route path="*" element={<UpdatePasswordPage />} />
      </Routes>
    )
  }

  if (!session) {
    return (
      <Routes>
        <Route path="/reset-password" element={<ResetPasswordPage />} />
        <Route path="/update-password" element={<UpdatePasswordPage />} />
        <Route path="*" element={<AuthPage />} />
      </Routes>
    )
  }

  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/profile" element={<ProfilePage />} />

      <Route path="/meals" element={<MealListPage />} />
      <Route path="/meals/new" element={<AddMealPage />} />
      <Route path="/meals/:id" element={<MealDetailPage />} />
      <Route path="/meals/:id/edit" element={<EditMealPage />} />

      <Route path="/planner" element={<MealPlannerPage />} />
      <Route path="/calendar" element={<MonthlyCalendarPage />} />
      <Route path="/shopping-list" element={<ShoppingListPage />} />

      <Route path="/groceries" element={<MyGroceriesPage />} />

      <Route path="/stores" element={<StoreListPage />} />
      <Route path="/stores/preferences" element={<StorePreferencesPage />} />

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <ThemeProvider>
          <HashRouter>
            <div className="app-shell">
              <Gate />
            </div>
          </HashRouter>
        </ThemeProvider>
      </AuthProvider>
    </QueryClientProvider>
  )
}
