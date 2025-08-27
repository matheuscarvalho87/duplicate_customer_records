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
    mutationFn: ({ id, action }: { id: string; action: 'merge' | 'ignore' }) =>
      duplicateService.resolve(id, action),
    
    onMutate: async ({ id, action }) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.duplicates.all });

      const previousDuplicates = queryClient.getQueriesData({ 
        queryKey: queryKeys.duplicates.lists() 
      });

      queryClient.setQueriesData(
        { queryKey: queryKeys.duplicates.lists() },
        (oldData: any) => {
          if (!oldData?.duplicates) return oldData;
          
          return {
            ...oldData,
            duplicates: oldData.duplicates.filter((dup: DuplicateMatch) => dup.id !== id)
          };
        }
      );

      queryClient.setQueryData(
        queryKeys.duplicates.detail(id),
        (oldData: DuplicateMatch | undefined) => 
          oldData ? { 
            ...oldData, 
            status: action === 'merge' ? 'Merged' : 'Ignored' 
          } : undefined
      );

      return { previousDuplicates };
    },

    onError: (error, variables, context) => {
      if (context?.previousDuplicates) {
        context.previousDuplicates.forEach(([queryKey, data]) => {
          queryClient.setQueryData(queryKey, data);
        });
      }
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.duplicates.all });
      queryClient.invalidateQueries({ queryKey: queryKeys.duplicates.stats() });
    },
  });
}