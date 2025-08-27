// src/hooks/query-keys.ts
/**
 * Centralized query keys for React Query
 * Following the pattern: [entity, ...params]
 */

export const queryKeys = {
  duplicates: {
    all: ['duplicates'] as const,
    lists: () => [...queryKeys.duplicates.all, 'list'] as const,
    list: (params?: Record<string, unknown>) => 
      [...queryKeys.duplicates.lists(), params] as const,
    pending: (params?: { limit?: number; offset?: number; minScore?: number }) =>
      [...queryKeys.duplicates.all, 'pending', params] as const,
    detail: (id: string) => [...queryKeys.duplicates.all, 'detail', id] as const,
    stats: () => [...queryKeys.duplicates.all, 'stats'] as const,
  },
} as const;

export const queryKeyUtils = {
  invalidateAllDuplicates: () => queryKeys.duplicates.all,
  invalidateDuplicateLists: () => queryKeys.duplicates.lists(),
};