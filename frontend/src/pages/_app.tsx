import type { AppProps } from 'next/app'
import { ThemeProvider } from '@/components/ThemeProvider'
import { AppProvider, useAppContext } from '@/context/AppContext'
import AppLayout from '@/components/layout/AppLayout'
import ConvertModal from '@/components/ConvertModal'
import '@/styles/globals.css'

function GlobalModals() {
  const { convertModalOpen, closeConvertModal } = useAppContext()
  return <ConvertModal isOpen={convertModalOpen} onClose={closeConvertModal} />
}

export default function App({ Component, pageProps }: AppProps) {
  return (
    <ThemeProvider>
      <AppProvider>
        <AppLayout>
          <Component {...pageProps} />
        </AppLayout>
        <GlobalModals />
      </AppProvider>
    </ThemeProvider>
  )
}
