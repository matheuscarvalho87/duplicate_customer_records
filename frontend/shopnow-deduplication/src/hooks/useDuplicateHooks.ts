import { useState, useCallback, useEffect } from 'react';
import { duplicateService } from '../services/duplicateService';
import type { DuplicateMatch } from '../types/DuplicateMatch';

interface UseDuplicatesReturn {
  duplicates: DuplicateMatch[];
  loading: boolean;
  error: string | null;
  selectedIds: string[];
  totalCount: number;

  fetchDuplicates: () => Promise<void>;
  refreshData: () => Promise<void>;

  setSelectedIds: (ids: string[]) => void;
  selectAll: () => void;
  clearSelection: () => void;
 
  mergeDuplicates: (ids: string[]) => Promise<void>;
  ignoreDuplicates: (ids: string[]) => Promise<void>;

  resolveDuplicate: (id: string, action: 'merge' | 'ignore') => Promise<void>;

  clearError: () => void;
  getDuplicateById: (id: string) => DuplicateMatch | undefined;
}

interface UseDuplicatesOptions {
  autoFetch?: boolean;
}

export function useDuplicates(options: UseDuplicatesOptions = {}): UseDuplicatesReturn {
  const { autoFetch = true } = options;
  
  const [duplicates, setDuplicates] = useState<DuplicateMatch[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);


  const fetchDuplicates = useCallback(async () => {
    setLoading(true);
    setError(null);
    
    try {
      const data = await duplicateService.getPendingSimple();
      setDuplicates(data);
      
      setSelectedIds(prev => prev.filter(id => data.some(duplicate => duplicate.id === id)));
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch duplicates';
      setError(errorMessage);
      console.error('Error fetching duplicates:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  const refreshData = useCallback(async () => {
    await fetchDuplicates();
  }, [fetchDuplicates]);

  const selectAll = useCallback(() => {
    setSelectedIds(duplicates.map(d => d.id));
  }, [duplicates]);

  const clearSelection = useCallback(() => {
    setSelectedIds([]);
  }, []);

  const mergeDuplicates = useCallback(async (ids: string[]) => {
    if (ids.length === 0) return;

    setError(null);
    
    try {
      const promises = ids.map(id => duplicateService.resolve(id, 'merge'));
      await Promise.allSettled(promises);
      
      setDuplicates(prev => prev.filter(duplicate => !ids.includes(duplicate.id)));
      setSelectedIds(prev => prev.filter(id => !ids.includes(id)));
      
      await fetchDuplicates();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to merge duplicates';
      setError(errorMessage);
      console.error('Error merging duplicates:', err);
      throw err; 
    }
  }, []);

  const ignoreDuplicates = useCallback(async (ids: string[]) => {
    if (ids.length === 0) return;

    setError(null);
    
    try {
      const promises = ids.map(id => duplicateService.resolve(id, 'ignore'));
      await Promise.allSettled(promises);
      
      setDuplicates(prev => prev.filter(duplicate => !ids.includes(duplicate.id)));
      setSelectedIds(prev => prev.filter(id => !ids.includes(id)));
      
      await fetchDuplicates();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to ignore duplicates';
      setError(errorMessage);
      console.error('Error ignoring duplicates:', err);
      throw err;
    }
  }, []);

  const resolveDuplicate = useCallback(async (id: string, action: 'merge' | 'ignore') => {
    setError(null);
    
    try {
      await duplicateService.resolve(id, action);
      
      setDuplicates(prev => prev.filter(duplicate => duplicate.id !== id));
      setSelectedIds(prev => prev.filter(selectedId => selectedId !== id));
      
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : `Failed to ${action} duplicate`;
      setError(errorMessage);
      console.error(`Error ${action} duplicate:`, err);
      throw err; 
    }
  }, []);

  const clearError = useCallback(() => {
    setError(null);
  }, []);

  const getDuplicateById = useCallback((id: string) => {
    return duplicates.find(duplicate => duplicate.id === id);
  }, [duplicates]);

  useEffect(() => {
    if (autoFetch) {
      fetchDuplicates();
    }
  }, [autoFetch, fetchDuplicates]);



  return {
    duplicates,
    loading,
    error,
    selectedIds,
    totalCount: duplicates.length,
   
    fetchDuplicates,
    refreshData,

    setSelectedIds,
    selectAll,
    clearSelection,

    mergeDuplicates,
    ignoreDuplicates,

    resolveDuplicate,

    clearError,
    getDuplicateById
  };
}