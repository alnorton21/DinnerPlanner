import { PageHeader } from '../components/PageHeader'

export function ShoppingListPage() {
  return (
    <div>
      <PageHeader title="Shopping List" />
      <div className="page-content empty-state">
        <p style={{ opacity: 0.6 }}>Coming soon</p>
      </div>
    </div>
  )
}
