import { type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'

interface PageHeaderProps {
  title: ReactNode
  showBack?: boolean
  actions?: ReactNode
}

export function PageHeader({ title, showBack = true, actions }: PageHeaderProps) {
  const navigate = useNavigate()
  return (
    <div className="app-bar">
      {showBack && (
        <button className="icon-btn" onClick={() => navigate(-1)} aria-label="Back">
          ←
        </button>
      )}
      <h1>{title}</h1>
      {actions}
    </div>
  )
}
