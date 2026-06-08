import { useEffect, useRef, useState } from 'react'
import { BrowserMultiFormatReader } from '@zxing/browser'
import type { IScannerControls } from '@zxing/browser'

interface BarcodeScannerModalProps {
  onDetected: (code: string) => void
  onClose: () => void
}

export function BarcodeScannerModal({ onDetected, onClose }: BarcodeScannerModalProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const reader = new BrowserMultiFormatReader()
    let controls: IScannerControls | undefined
    let cancelled = false
    let detected = false

    reader
      .decodeFromConstraints(
        { video: { facingMode: 'environment' } },
        videoRef.current ?? undefined,
        (result, _err, ctrl) => {
          controls = ctrl
          if (detected || !result) return
          detected = true
          ctrl.stop()
          onDetected(result.getText())
        },
      )
      .then((ctrl) => {
        controls = ctrl
        if (cancelled) ctrl.stop()
      })
      .catch((err) => {
        if (!cancelled) setError(err?.message ?? 'Could not access the camera')
      })

    return () => {
      cancelled = true
      controls?.stop()
    }
  }, [onDetected])

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.85)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 200,
      }}
    >
      <button
        className="icon-btn"
        onClick={onClose}
        style={{ position: 'absolute', top: 16, right: 16, color: '#fff' }}
        aria-label="Close scanner"
      >
        ✕
      </button>

      {error ? (
        <p style={{ color: '#fff', padding: 24, textAlign: 'center' }}>{error}</p>
      ) : (
        <div style={{ position: 'relative', width: '100%', maxWidth: 480 }}>
          <video ref={videoRef} style={{ width: '100%', borderRadius: 12 }} muted playsInline />
          <div
            style={{
              position: 'absolute',
              inset: '30% 15%',
              border: '3px solid #4caf50',
              borderRadius: 12,
              pointerEvents: 'none',
            }}
          />
        </div>
      )}

      <p style={{ color: '#fff', marginTop: 20, fontSize: 15 }}>Point the camera at a product barcode</p>
    </div>
  )
}
