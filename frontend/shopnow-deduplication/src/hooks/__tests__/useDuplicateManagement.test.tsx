import React from 'react';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';

const mockUseDuplicates = vi.fn();
const mockMutateAsync = vi.fn();
const mockUseResolveDuplicate = vi.fn(() => ({ mutateAsync: mockMutateAsync, isPending: false }));
const success = vi.fn();
const errorToast = vi.fn();

vi.mock('../queries/useDuplicateQueries', () => ({
  useDuplicates: (...args: unknown[]) => mockUseDuplicates(...args),
  useResolveDuplicate: (...args: unknown[]) => mockUseResolveDuplicate(...args),
}));

vi.mock('../utilities', () => ({
  useToast: () => ({ success, error: errorToast }),
}));

import { useDuplicateManagement } from '../useDuplicateManagement';

function Wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({
    defaultOptions: {
      queries: { retry: false, staleTime: Infinity },
      mutations: { retry: false },
    },
  });
  return (
    <MemoryRouter>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </MemoryRouter>
  );
}

describe('useDuplicateManagement', () => {
  beforeEach(() => {
    mockUseDuplicates.mockReset();
    mockMutateAsync.mockReset();
    success.mockReset();
    errorToast.mockReset();

    mockUseDuplicates.mockReturnValue({
      data: {
        duplicates: [
          { id: 'dup_1', score: 80, status: 'PENDING', customerA: {}, customerB: {}, createdAt: new Date().toISOString() },
        ],
      pagination: { total: 25, offset: 0, limit: 10 },
      },
      isLoading: false,
      isError: false,
      error: null,
    });
  });

  it('exposes defaults, items and pagination', () => {
    const { result } = renderHook(() => useDuplicateManagement(), { wrapper: Wrapper });
    expect(result.current.duplicates.length).toBe(1);
    expect(result.current.pagination.totalCount).toBe(25);
    expect(result.current.pagination.pageSize).toBe(10);
    expect(result.current.pagination.currentPage).toBe(1);
    expect(result.current.pagination.totalPages).toBe(3);
    expect(result.current.pagination.hasNextPage).toBe(true);
    expect(result.current.pagination.hasPreviousPage).toBe(false);
    expect(result.current.pagination.offset).toBe(0);
    expect(result.current.sort.key).toBe('score');
    expect(result.current.sort.direction).toBe('desc');
    expect(result.current.filters.values.minScore).toBe(50);
    expect(result.current.filters.hasActiveFilters).toBe(false);
  });

  it('navigates pages and clamps bounds', () => {
    const { result } = renderHook(() => useDuplicateManagement(), { wrapper: Wrapper });
    act(() => result.current.pagination.goToPage(3));
    expect(result.current.pagination.currentPage).toBe(3);
    expect(result.current.pagination.hasNextPage).toBe(false);
    expect(result.current.pagination.offset).toBe(20);
    act(() => result.current.pagination.goToPage(999));
    expect(result.current.pagination.currentPage).toBe(3);
    act(() => result.current.pagination.goToPage(0));
    expect(result.current.pagination.currentPage).toBe(1);
  });

  it('updates pageSize and resets to first page', () => {
    const { result } = renderHook(() => useDuplicateManagement(), { wrapper: Wrapper });
    act(() => result.current.pagination.setPageSize(5));
    expect(result.current.pagination.pageSize).toBe(5);
    expect(result.current.pagination.currentPage).toBe(1);
    expect(result.current.pagination.totalPages).toBe(5);
    expect(result.current.pagination.offset).toBe(0);
  });

  it('toggles sorting and resets page', () => {
    const { result } = renderHook(() => useDuplicateManagement(), { wrapper: Wrapper });
    act(() => result.current.pagination.goToPage(2));
    act(() => result.current.sort.sortBy('score'));
    expect(result.current.sort.key).toBe('score');
    expect(result.current.sort.direction).toBe('asc');
    expect(result.current.pagination.currentPage).toBe(1);
    act(() => result.current.sort.sortBy('status'));
    expect(result.current.sort.key).toBe('status');
    expect(result.current.sort.direction).toBe('desc');
    expect(result.current.pagination.currentPage).toBe(1);
  });

  it('applies and clears minScore filter', () => {
    const { result } = renderHook(() => useDuplicateManagement(), { wrapper: Wrapper });
    act(() => result.current.pagination.goToPage(2));
    act(() => result.current.filters.setMinScore(70));
    expect(result.current.filters.values.minScore).toBe(70);
    expect(result.current.filters.hasActiveFilters).toBe(true);
    expect(result.current.pagination.currentPage).toBe(1);
    act(() => result.current.filters.clearAllFilters());
    expect(result.current.filters.values.minScore).toBe(50);
    expect(result.current.filters.hasActiveFilters).toBe(false);
  });

  it('resolves one duplicate successfully', async () => {
    mockMutateAsync.mockResolvedValueOnce({});
    const { result } = renderHook(() => useDuplicateManagement(), { wrapper: Wrapper });
    await act(async () => {
      await result.current.actions.resolveOne('dup_1', 'merge');
    });
    expect(mockMutateAsync).toHaveBeenCalledWith({ id: 'dup_1', action: 'merge' });
    expect(success).toHaveBeenCalled();
    expect(result.current.actions.isResolving).toBe(false);
  });

  it('handles resolve error and rethrows', async () => {
    mockMutateAsync.mockRejectedValueOnce(new Error('boom'));
    const { result } = renderHook(() => useDuplicateManagement(), { wrapper: Wrapper });
    await expect(result.current.actions.resolveOne('dup_1', 'ignore')).rejects.toThrow('boom');
    expect(errorToast).toHaveBeenCalled();
  });
});
