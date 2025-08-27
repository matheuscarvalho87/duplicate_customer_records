import { useState, useMemo, useCallback } from 'react';
import { useDuplicates, useResolveDuplicate } from './queries/useDuplicateQueries';
import { useToast } from './utilities';
import type { DuplicateMatch } from '../types/DuplicateMatch';

type SortKey = 'score' | 'status';
type SortDir = 'asc' | 'desc';

interface UseDuplicateManagementOptions {
  initialPageSize?: number;
}

interface UseDuplicateManagementReturn {
  duplicates: DuplicateMatch[];
  isLoading: boolean;
  isError: boolean;
  error: Error | null;

  pagination: {
    currentPage: number;
    pageSize: number;
    totalPages: number;
    totalCount: number;          // <<< Novo
    offset: number;
    hasNextPage: boolean;
    hasPreviousPage: boolean;
    goToPage: (page: number) => void;
    setPageSize: (size: number) => void;
  };

  sort: {
    key: SortKey;
    direction: SortDir;
    sortBy: (key: SortKey) => void;
  };

  filters: {
    values: { minScore: number };
    setMinScore: (value: number) => void;
    clearAllFilters: () => void;
    hasActiveFilters: boolean;
  };

  actions: {
    resolveOne: (id: string, action: 'merge' | 'ignore') => Promise<void>;
    isResolving: boolean;
  };
}

export function useDuplicateManagement({
  initialPageSize = 10
}: UseDuplicateManagementOptions = {}): UseDuplicateManagementReturn {
  const toast = useToast();

  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(initialPageSize);
  const offset = (currentPage - 1) * pageSize;

  const [sortKey, setSortKey] = useState<SortKey>('score');
  const [sortDir, setSortDir] = useState<SortDir>('desc');

  const [minScore, setMinScore] = useState<number>(50);

  const queryParams = useMemo(() => ({
    limit: pageSize,
    offset,
    minScore,
    sort: sortKey,
    order: sortDir,
  }), [pageSize, offset, minScore, sortKey, sortDir]);

  const {
    data: duplicatesResp,
    isLoading,
    isError,
    error,
  } = useDuplicates(queryParams);

  const duplicates: DuplicateMatch[] = useMemo(() => {
    return (duplicatesResp?.duplicates as DuplicateMatch[]) ?? [];
  }, [duplicatesResp]);

  const totalCount: number = useMemo(() => {
    return (duplicatesResp?.pagination?.total as number) ?? 0;
  }, [duplicatesResp]);

  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
  const hasNextPage = currentPage < totalPages;
  const hasPreviousPage = currentPage > 1;

  const sortBy = useCallback((key: SortKey) => {
    setSortKey(prevKey => {
      if (prevKey === key) {
        setSortDir(prevDir => (prevDir === 'asc' ? 'desc' : 'asc'));
        return prevKey;
      }
      setSortDir('desc');
      return key;
    });
    setCurrentPage(1);
  }, []);

  const goToPage = useCallback((page: number) => {
    const valid = Math.max(1, Math.min(page, totalPages));
    setCurrentPage(valid);
  }, [totalPages]);

  const handleSetPageSize = useCallback((size: number) => {
    setPageSize(size);
    setCurrentPage(1);
  }, []);

  const setMinScoreFilter = useCallback((value: number) => {
    setMinScore(value);
    setCurrentPage(1);
  }, []);

  const clearAllFilters = useCallback(() => {
    setMinScore(50);
    setCurrentPage(1);
  }, []);

  const hasActiveFilters = minScore !== 50;

  const resolveMutation = useResolveDuplicate();
  const resolveOne = useCallback(
    async (id: string, action: 'merge' | 'ignore') => {
      try {
        await resolveMutation.mutateAsync({ id, action });
        toast.success(`Successfully ${action} duplicate`);
      } catch (err: any) {
        toast.error(`Failed to ${action} duplicate: ${err?.message || 'Unknown error'}`);
        throw err;
      }
    },
    [resolveMutation, toast]
  );

  return {
    duplicates,
    isLoading,
    isError,
    error: (error as Error) ?? null,

    pagination: {
      currentPage,
      pageSize,
      totalPages,
      totalCount,      // <<< Agora exposto corretamente
      offset,
      hasNextPage,
      hasPreviousPage,
      goToPage,
      setPageSize: handleSetPageSize,
    },

    sort: {
      key: sortKey,
      direction: sortDir,
      sortBy,
    },

    filters: {
      values: { minScore },
      setMinScore: setMinScoreFilter,
      clearAllFilters,
      hasActiveFilters,
    },

    actions: {
      resolveOne,
      isResolving: resolveMutation.isPending,
    },
  };
}
