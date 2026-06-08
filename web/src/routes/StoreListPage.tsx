import { PageHeader } from '../components/PageHeader'

export function StoreListPage() {
  return (
    <div>
      <PageHeader title="Stores" />
      <div className="page-content empty-state">
        <p style={{ opacity: 0.6 }}>Coming soon</p>
      </div>
    </div>
  )
}
