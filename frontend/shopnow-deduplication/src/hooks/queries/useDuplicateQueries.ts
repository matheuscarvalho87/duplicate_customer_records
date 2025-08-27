import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { duplicateService } from '../../services/duplicateService';
import { queryKeys } from '../query-keys';
import type { DuplicateMatch } from '../../types/DuplicateMatch';

interface DuplicateListParams {
  limit?: number;
  offset?: number;
  minScore?: number;
  sort?: 'score' | 'createdAt' | 'status';
  order?: 'asc' | 'desc';
}

type ResolveAction = 'merge' | 'ignore';

type MutationCtx = {
  previousListQueries: Array<[unknown, unknown]>;
  previousDetail: DuplicateMatch | undefined;
  detailKey: unknown;
};

export function useDuplicates(params?: DuplicateListParams) {
  return useQuery({
    queryKey: queryKeys.duplicates.pending(params),
    queryFn: () => duplicateService.getPending(params),
    refetchInterval: 30000,
    placeholderData: (previousData) => previousData,
    staleTime: 1000 * 10,
  });
}

export function usePendingDuplicates() {
  return useQuery({
    queryKey: queryKeys.duplicates.pending({ limit: 1000 }),
    queryFn: () => duplicateService.getPendingSimple(),
    refetchInterval: 15000,
    staleTime: 1000 * 5,
  });
}

export function useResolveDuplicate() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, action }: { id: string; action: ResolveAction }) =>
      duplicateService.resolve(id, action),

    onMutate: async ({ id, action }): Promise<MutationCtx> => {
      await queryClient.cancelQueries({ queryKey: queryKeys.duplicates.all });

      const listQueries = queryClient.getQueriesData({
        predicate: q =>
          Array.isArray(q.queryKey) &&
          (q.queryKey as any[])[0] === 'duplicates' &&
          ((q.queryKey as any[]).includes('pending') ||
           (q.queryKey as any[]).includes('list') ||
           (q.queryKey as any[]).includes('lists')),
      });

      const previousListQueries = listQueries.map(([key, data]) => [key, data] as [unknown, unknown]);

      listQueries.forEach(([key, oldData]) => {
        const d = oldData as any;
        if (d && Array.isArray(d.duplicates)) {
          queryClient.setQueryData(key, {
            ...d,
            duplicates: d.duplicates.filter((x: DuplicateMatch) => x.id !== id),
          });
        }
      });

      const detailKey = queryKeys.duplicates.detail(id);
      const previousDetail = queryClient.getQueryData<DuplicateMatch>(detailKey);

      queryClient.setQueryData(detailKey, (old: DuplicateMatch | undefined) =>
        old ? { ...old, status: action === 'merge' ? 'Merged' : 'Ignored' } : old
      );

      return { previousListQueries, previousDetail, detailKey };
    },

    onError: (_err, _vars, ctx) => {
      if (!ctx) return;
      ctx.previousListQueries.forEach(([key, data]) => {
        queryClient.setQueryData(key, data);
      });
      if (ctx.previousDetail !== undefined) {
        queryClient.setQueryData(ctx.detailKey, ctx.previousDetail);
      }
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.duplicates.all });
      queryClient.invalidateQueries({ queryKey: queryKeys.duplicates.stats() });
    },
  });
}