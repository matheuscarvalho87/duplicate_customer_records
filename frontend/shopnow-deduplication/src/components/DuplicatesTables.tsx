import React, { useState, useMemo, useCallback } from 'react';
import { FixedSizeList as List } from 'react-window';
import { ChevronUp, ChevronDown, Filter, X } from 'lucide-react';
import type { DuplicateMatch } from '../types/DuplicateMatch';

interface DuplicatesTableProps {
  duplicates: DuplicateMatch[];
  selectedIds: string[];
  onSelectionChange: (ids: string[]) => void;
  onRowClick?: (duplicate: DuplicateMatch) => void;
  loading?: boolean;
}

interface SortConfig {
  key: keyof DuplicateMatch | 'customerA.firstName' | 'customerA.lastName' | 'customerB.firstName' | 'customerB.lastName';
  direction: 'asc' | 'desc';
}

interface FilterConfig {
  minScore: number;
  maxScore: number;
  status: string;
}

const ITEM_HEIGHT = 80;
const HEADER_HEIGHT = 60;
const DEFAULT_FILTER: FilterConfig = {
  minScore: 0,
  maxScore: 100,
  status: 'all'
};

export default function DuplicatesTable({
  duplicates,
  selectedIds,
  onSelectionChange,
  onRowClick,
  loading = false
}: DuplicatesTableProps) {
  const [sortConfig, setSortConfig] = useState<SortConfig>({ key: 'score', direction: 'desc' });
  const [filterConfig, setFilterConfig] = useState<FilterConfig>(DEFAULT_FILTER);
  const [showFilters, setShowFilters] = useState(false);

  const processedData = useMemo(() => {
    let filtered = duplicates.filter(item => {
      const scoreInRange = item.score >= filterConfig.minScore && item.score <= filterConfig.maxScore;
      const statusMatch = filterConfig.status === 'all' || item.status === filterConfig.status;
      return scoreInRange && statusMatch;
    });

    filtered.sort((a, b) => {
      let aValue: any;
      let bValue: any;

      switch (sortConfig.key) {
        case 'customerA.firstName':
          aValue = a.customerA.firstName;
          bValue = b.customerA.firstName;
          break;
        case 'customerA.lastName':
          aValue = a.customerA.lastName;
          bValue = b.customerA.lastName;
          break;
        case 'customerB.firstName':
          aValue = a.customerB.firstName;
          bValue = b.customerB.firstName;
          break;
        case 'customerB.lastName':
          aValue = a.customerB.lastName;
          bValue = b.customerB.lastName;
          break;
        default:
          aValue = a[sortConfig.key as keyof DuplicateMatch];
          bValue = b[sortConfig.key as keyof DuplicateMatch];
      }

      if (typeof aValue === 'string' && typeof bValue === 'string') {
        aValue = aValue.toLowerCase();
        bValue = bValue.toLowerCase();
      }

      if (aValue < bValue) return sortConfig.direction === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortConfig.direction === 'asc' ? 1 : -1;
      return 0;
    });

    return filtered;
  }, [duplicates, sortConfig, filterConfig]);

  const handleSort = useCallback((key: SortConfig['key']) => {
    setSortConfig(prev => ({
      key,
      direction: prev.key === key && prev.direction === 'asc' ? 'desc' : 'asc'
    }));
  }, []);

  const handleSelectAll = useCallback((checked: boolean) => {
    if (checked) {
      onSelectionChange(processedData.map(item => item.id));
    } else {
      onSelectionChange([]);
    }
  }, [processedData, onSelectionChange]);

  const handleSelectRow = useCallback((id: string, checked: boolean) => {
    if (checked) {
      onSelectionChange([...selectedIds, id]);
    } else {
      onSelectionChange(selectedIds.filter(selectedId => selectedId !== id));
    }
  }, [selectedIds, onSelectionChange]);

  const clearFilters = useCallback(() => {
    setFilterConfig(DEFAULT_FILTER);
  }, []);

  const SortButton = ({ column }: { column: SortConfig['key'] }) => (
    <button
      onClick={() => handleSort(column)}
      className="flex items-center gap-1 hover:text-blue-600 transition-colors"
      aria-label={`Sort by ${column}`}
    >
      {sortConfig.key === column && (
        sortConfig.direction === 'asc' ? 
          <ChevronUp className="w-4 h-4" /> : 
          <ChevronDown className="w-4 h-4" />
      )}
    </button>
  );

  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => {
    const item = processedData[index];
    const isSelected = selectedIds.includes(item.id);

    return (
      <div
        style={style}
        className={`border-b border-gray-200 flex items-center px-4 hover:bg-gray-50 transition-colors ${
          isSelected ? 'bg-blue-50 border-blue-200' : ''
        }`}
      >
        <div className="w-12 flex items-center justify-center">
          <input
            type="checkbox"
            checked={isSelected}
            onChange={(e) => handleSelectRow(item.id, e.target.checked)}
            className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            aria-label={`Select duplicate match ${item.id}`}
          />
        </div>
        
        <div 
          className="flex-1 grid grid-cols-1 md:grid-cols-5 gap-4 py-3 cursor-pointer"
          onClick={() => onRowClick?.(item)}
        >
          <div className="md:col-span-2">
            <div className="font-medium text-gray-900">
              {item.customerA.firstName} {item.customerA.lastName}
            </div>
            <div className="text-sm text-gray-500">{item.customerA.email}</div>
          </div>
          
          <div className="md:col-span-2">
            <div className="font-medium text-gray-900">
              {item.customerB.firstName} {item.customerB.lastName}
            </div>
            <div className="text-sm text-gray-500">{item.customerB.email}</div>
          </div>
          
          <div className="flex flex-col items-end">
            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
              item.score >= 90 ? 'bg-red-100 text-red-800' :
              item.score >= 70 ? 'bg-yellow-100 text-yellow-800' :
              'bg-green-100 text-green-800'
            }`}>
              {item.score}% Match
            </span>
            <span className={`mt-1 inline-flex items-center px-2 py-1 text-xs rounded ${
              item.status === 'Pending Review' ? 'bg-gray-100 text-gray-800' :
              item.status === 'Merged' ? 'bg-green-100 text-green-800' :
              'bg-red-100 text-red-800'
            }`}>
              {item.status}
            </span>
          </div>
        </div>
      </div>
    );
  };

  const allSelected = processedData.length > 0 && selectedIds.length === processedData.length;
  const someSelected = selectedIds.length > 0 && selectedIds.length < processedData.length;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-sm">
      <div className="border-b border-gray-200 p-4">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-medium text-gray-900">
            Duplicate Matches ({processedData.length})
          </h3>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            <Filter className="w-4 h-4" />
            Filters
          </button>
        </div>
        
        {showFilters && (
          <div className="bg-gray-50 rounded-lg p-4 space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label htmlFor="minScore" className="block text-sm font-medium text-gray-700 mb-1">
                  Min Score
                </label>
                <input
                  id="minScore"
                  type="number"
                  min="0"
                  max="100"
                  value={filterConfig.minScore}
                  onChange={(e) => setFilterConfig(prev => ({ ...prev, minScore: Number(e.target.value) }))}
                  className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
              </div>
              
              <div>
                <label htmlFor="maxScore" className="block text-sm font-medium text-gray-700 mb-1">
                  Max Score
                </label>
                <input
                  id="maxScore"
                  type="number"
                  min="0"
                  max="100"
                  value={filterConfig.maxScore}
                  onChange={(e) => setFilterConfig(prev => ({ ...prev, maxScore: Number(e.target.value) }))}
                  className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
              </div>
              
              <div>
                <label htmlFor="status" className="block text-sm font-medium text-gray-700 mb-1">
                  Status
                </label>
                <select
                  id="status"
                  value={filterConfig.status}
                  onChange={(e) => setFilterConfig(prev => ({ ...prev, status: e.target.value }))}
                  className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                >
                  <option value="all">All Statuses</option>
                  <option value="Pending Review">Pending Review</option>
                  <option value="Merged">Merged</option>
                  <option value="Ignored">Ignored</option>
                </select>
              </div>
            </div>
            
            <div className="flex justify-end">
              <button
                onClick={clearFilters}
                className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              >
                <X className="w-4 h-4" />
                Clear Filters
              </button>
            </div>
          </div>
        )}
      </div>

      <div 
        className="grid grid-cols-1 md:grid-cols-5 gap-4 px-4 py-3 bg-gray-50 border-b border-gray-200 font-medium text-gray-700 text-sm"
        style={{ height: HEADER_HEIGHT }}
      >
        <div className="flex items-center">
          <div className="w-12 flex items-center justify-center mr-4">
            <input
              type="checkbox"
              checked={allSelected}
              ref={(input) => {
                if (input) input.indeterminate = someSelected;
              }}
              onChange={(e) => handleSelectAll(e.target.checked)}
              className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              aria-label="Select all duplicates"
            />
          </div>
          <div className="flex items-center gap-1">
            Customer A
            <SortButton column="customerA.firstName" />
          </div>
        </div>
        
        <div className="flex items-center gap-1">
          Customer B
          <SortButton column="customerB.firstName" />
        </div>
        
        <div className="flex items-center gap-1">
          Match Score
          <SortButton column="score" />
        </div>
        
        <div className="flex items-center gap-1">
          Status
          <SortButton column="status" />
        </div>
        
        <div></div>
      </div>

      {processedData.length === 0 ? (
        <div className="flex items-center justify-center h-32 text-gray-500">
          No duplicate matches found
        </div>
      ) : (
        <List
          height={Math.min(400, processedData.length * ITEM_HEIGHT)}
          itemCount={processedData.length}
          itemSize={ITEM_HEIGHT}
          overscanCount={5}
        >
          {Row}
        </List>
      )}

      {selectedIds.length > 0 && (
        <div className="border-t border-gray-200 px-4 py-3 bg-blue-50">
          <p className="text-sm text-blue-700">
            {selectedIds.length} duplicate{selectedIds.length === 1 ? '' : 's'} selected
          </p>
        </div>
      )}
    </div>
  );
}