import { PageHeader } from '../components/PageHeader'

export function MyGroceriesPage() {
  return (
    <div>
      <PageHeader title="My Groceries" />
      <div className="page-content empty-state">
        <p style={{ opacity: 0.6 }}>Coming soon</p>
      </div>
    </div>
  )
}
