import type { ReactNode } from 'react';
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryProvider } from '../../providers/QueryProvider';

function AllProviders({ children }: { children: ReactNode }) {
  return (
    <MemoryRouter>
      <QueryProvider>{children}</QueryProvider>
    </MemoryRouter>
  );
}

export function renderWithProviders(ui: React.ReactElement, options?: Parameters<typeof render>[1]) {
  return render(ui, { wrapper: AllProviders, ...options });
}
