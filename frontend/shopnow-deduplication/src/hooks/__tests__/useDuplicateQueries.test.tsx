import React from 'react';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const m = vi.hoisted(() => ({
  getPending: vi.fn(),
  getPendingSimple: vi.fn(),
  resolve: vi.fn(),
}));

vi.mock('../../services/duplicateService', () => ({
  duplicateService: {
    getPending: m.getPending,
    getPendingSimple: m.getPendingSimple,
    resolve: m.resolve,
  },
}));

import { useDuplicates, usePendingDuplicates, useResolveDuplicate } from '../queries/useDuplicateQueries';
import { queryKeys } from '../query-keys';

function withQC(children?: React.ReactNode, client?: QueryClient) {
  const qc =
    client ??
    new QueryClient({
      defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
    });
  return {
    qc,
    wrapper: ({ children: c }: { children: React.ReactNode }) => (
      <QueryClientProvider client={qc}>{c}</QueryClientProvider>
    ),
  };
}

describe('useDuplicateQueries', () => {
  beforeEach(() => {
    m.getPending.mockReset();
    m.getPendingSimple.mockReset();
    m.resolve.mockReset();
  });

  it('useDuplicates calls service with params and returns data', async () => {
    const data = { duplicates: [{ id: 'x' }], pagination: { total: 1, offset: 0, limit: 10 } };
    m.getPending.mockResolvedValueOnce(data);
    const params = { limit: 10, offset: 0, minScore: 50, sort: 'score' as const, order: 'desc' as const };
    const { wrapper } = withQC();
    const { result } = renderHook(() => useDuplicates(params), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(m.getPending).toHaveBeenCalledWith(params);
    expect(result.current.data).toEqual(data);
  });

  it('usePendingDuplicates calls getPendingSimple', async () => {
    const data = { duplicates: [{ id: 'y' }], pagination: { total: 1, offset: 0, limit: 1000 } };
    m.getPendingSimple.mockResolvedValueOnce(data);
    const { wrapper } = withQC();
    const { result } = renderHook(() => usePendingDuplicates(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(m.getPendingSimple).toHaveBeenCalledTimes(1);
    expect(result.current.data).toEqual(data);
  });

  it('useResolveDuplicate optimistic success', async () => {
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
    const params = { limit: 10, offset: 0, minScore: 50, sort: 'score' as const, order: 'desc' as const };
    const listKey = queryKeys.duplicates.pending(params);
    const detailKey = queryKeys.duplicates.detail('dup_1');

    qc.setQueryData(listKey, {
      duplicates: [{ id: 'dup_1', status: 'PENDING' }, { id: 'dup_2', status: 'PENDING' }],
      pagination: { total: 2, offset: 0, limit: 10 },
    });
    qc.setQueryData(detailKey, { id: 'dup_1', status: 'PENDING' });

    m.resolve.mockResolvedValueOnce({ ok: true });

    const { wrapper } = withQC(undefined, qc);
    const { result } = renderHook(() => useResolveDuplicate(), { wrapper });

    await act(async () => {
      await result.current.mutateAsync({ id: 'dup_1', action: 'merge' });
    });

    const listAfter = qc.getQueryData(listKey) as any;
    const detailAfter = qc.getQueryData(detailKey) as any;

    expect(listAfter.duplicates.map((d: any) => d.id)).toEqual(['dup_2']);
    expect(detailAfter.status).toBe('Merged');
    expect(m.resolve).toHaveBeenCalledWith('dup_1', 'merge');
  });

  it('useResolveDuplicate rollback on error', async () => {
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
    const params = { limit: 10, offset: 0, minScore: 50, sort: 'score' as const, order: 'desc' as const };
    const listKey = queryKeys.duplicates.pending(params);
    const detailKey = queryKeys.duplicates.detail('dup_1');

    qc.setQueryData(listKey, {
      duplicates: [{ id: 'dup_1', status: 'PENDING' }, { id: 'dup_2', status: 'PENDING' }],
      pagination: { total: 2, offset: 0, limit: 10 },
    });
    qc.setQueryData(detailKey, { id: 'dup_1', status: 'PENDING' });

    m.resolve.mockRejectedValueOnce(new Error('boom'));

    const { wrapper } = withQC(undefined, qc);
    const { result } = renderHook(() => useResolveDuplicate(), { wrapper });

    await expect(result.current.mutateAsync({ id: 'dup_1', action: 'ignore' })).rejects.toThrow('boom');

    const listAfter = qc.getQueryData(listKey) as any;
    const detailAfter = qc.getQueryData(detailKey) as any;

    expect(listAfter.duplicates.map((d: any) => d.id)).toEqual(['dup_1', 'dup_2']);
    expect(detailAfter.status).toBe('PENDING');
    expect(m.resolve).toHaveBeenCalledWith('dup_1', 'ignore');
  });
});
