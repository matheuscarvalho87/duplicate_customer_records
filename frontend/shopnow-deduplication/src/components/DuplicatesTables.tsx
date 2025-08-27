import { useState, useMemo, useCallback } from 'react';
import { ChevronUp, ChevronDown, Filter, X, ChevronLeft, ChevronRight } from 'lucide-react';
import type { DuplicateMatch } from '../types/DuplicateMatch';

interface DuplicatesTableProps {
  duplicates: DuplicateMatch[];
  onRowClick?: (duplicate: DuplicateMatch) => void;
  onMergeOne: (id: string) => Promise<void> | void;
  onIgnoreOne: (id: string) => Promise<void> | void;
  loading?: boolean;
  currentPage?: number;
  pageSize?: number;
  totalPages?: number;
  totalCount?: number;
  onPageChange?: (page: number) => void;
  onPageSizeChange?: (size: number) => void;
}

interface SortConfig {
  key:
    | keyof DuplicateMatch
    | 'customerA.firstName'
    | 'customerA.lastName'
    | 'customerB.firstName'
    | 'customerB.lastName';
  direction: 'asc' | 'desc';
}

interface FilterConfig {
  minScore: number;
  maxScore: number;
  status: string;
}

const DEFAULT_FILTER: FilterConfig = {
  minScore: 0,
  maxScore: 100,
  status: 'all'
};

const PAGE_SIZE_OPTIONS = [10, 25, 50, 100];

export default function DuplicatesTable({
  duplicates,
  onRowClick,
  onMergeOne,
  onIgnoreOne,
  loading = false,
  currentPage = 1,
  pageSize = 10,
  totalPages = 1,
  totalCount = 0, // <<< Novo
  onPageChange,
  onPageSizeChange
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

  const clearFilters = useCallback(() => {
    setFilterConfig(DEFAULT_FILTER);
  }, []);

  const SortButton = ({ column }: { column: SortConfig['key'] }) => (
    <button
      onClick={() => handleSort(column)}
      className="flex items-center gap-1 hover:text-blue-600 transition-colors"
      aria-label={`Sort by ${column}`}
    >
      {sortConfig.key === column &&
        (sortConfig.direction === 'asc' ? (
          <ChevronUp className="w-4 h-4" />
        ) : (
          <ChevronDown className="w-4 h-4" />
        ))}
    </button>
  );

  const PaginationControls = () => {
    const startItem = (currentPage - 1) * pageSize + 1;
    const endItem = Math.min(currentPage * pageSize, totalCount);

    const hasNextPage = currentPage < totalPages;
    const hasPreviousPage = currentPage > 1;

    return (
      <div className="flex items-center justify-between px-4 py-3 bg-white border-t border-gray-200">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <span className="text-sm text-gray-700">Show</span>
            <select
              value={pageSize}
              onChange={(e) => onPageSizeChange?.(Number(e.target.value))}
              className="border border-gray-300 rounded-md px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              {PAGE_SIZE_OPTIONS.map(size => (
                <option key={size} value={size}>{size}</option>
              ))}
            </select>
            <span className="text-sm text-gray-700">per page</span>
          </div>

          <div className="text-sm text-gray-700">
            Showing {startItem} to {endItem} of {totalCount} results
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => onPageChange?.(currentPage - 1)}
            disabled={!hasPreviousPage || loading}
            className="inline-flex items-center px-2 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-500 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            aria-label="Previous page"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>

          <div className="flex items-center gap-1">
            {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
              let pageNum;
              if (totalPages <= 5) {
                pageNum = i + 1;
              } else if (currentPage <= 3) {
                pageNum = i + 1;
              } else if (currentPage >= totalPages - 2) {
                pageNum = totalPages - 4 + i;
              } else {
                pageNum = currentPage - 2 + i;
              }

              return (
                <button
                  key={pageNum}
                  onClick={() => onPageChange?.(pageNum)}
                  disabled={loading}
                  className={`inline-flex items-center px-3 py-2 border text-sm font-medium rounded-md transition-colors ${
                    currentPage === pageNum
                      ? 'bg-blue-600 border-blue-600 text-white'
                      : 'bg-white border-gray-300 text-gray-700 hover:bg-gray-50'
                  }`}
                >
                  {pageNum}
                </button>
              );
            })}
          </div>

          <button
            onClick={() => onPageChange?.(currentPage + 1)}
            disabled={!hasNextPage || loading}
            className="inline-flex items-center px-2 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-500 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            aria-label="Next page"
          >
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    );
  };

  if (loading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg shadow-sm">
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
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

  
      <div className="grid grid-cols-1 md:grid-cols-5 gap-5 px-5 py-3 bg-gray-50 border-b border-gray-200 font-medium text-gray-700 text-sm">
        <div className="flex items-center gap-1">
          Customer A
          <SortButton column="customerA.firstName" />
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
        <div className="text-right pr-2">Actions</div>
      </div>

      {/* Rows */}
      <div className="divide-y divide-gray-200">
        {processedData.length === 0 ? (
          <div className="flex items-center justify-center h-32 text-gray-500">
            No duplicate matches found
          </div>
        ) : (
          processedData.map((item) => (
            <div
              key={item.id}
              className="grid grid-cols-1 md:grid-cols-5 gap-8 px-5 py-5 hover:bg-gray-50 transition-colors"
            >
              <div
                className="md:col-span-1 cursor-pointer"
                onClick={() => onRowClick?.(item)}
              >
                <div className="flex flex-col space-y-1 leading-snug">
                  <span className="font-medium text-gray-900">
                    {item.customerA.firstName} {item.customerA.lastName}
                  </span>
                  <span className="text-sm text-gray-500 break-all">{item.customerA.email}</span>
                </div>
              </div>

              <div
                className="md:col-span-1 cursor-pointer leading-relaxed"
                onClick={() => onRowClick?.(item)}
              >
                <div className="font-medium text-gray-900">
                  {item.customerB.firstName} {item.customerB.lastName}
                </div>
                <div className="text-sm text-gray-500">{item.customerB.email}</div>
              </div>

              <div className="md:col-span-1 flex items-center">
                <span
                  className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                    item.score >= 90
                      ? 'bg-red-100 text-red-800'
                      : item.score >= 70
                      ? 'bg-yellow-100 text-yellow-800'
                      : 'bg-green-100 text-green-800'
                  }`}
                >
                  {item.score}% Match
                </span>
              </div>

              <div className="md:col-span-1 flex items-center">
                <span
                  className={`inline-flex items-center px-2 py-1 text-xs rounded ${
                    item.status === 'Pending Review'
                      ? 'bg-gray-100 text-gray-800'
                      : item.status === 'Merged'
                      ? 'bg-green-100 text-green-800'
                      : 'bg-red-100 text-red-800'
                  }`}
                >
                  {item.status}
                </span>
              </div>

              <div className="md:col-span-1 flex items-center justify-end gap-2">
                <button
                  onClick={() => onMergeOne(item.id)}
                  disabled={loading}
                  className="inline-flex items-center px-3 py-2 text-sm font-medium rounded-md bg-green-600 text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Merge
                </button>
                <button
                  onClick={() => onIgnoreOne(item.id)}
                  disabled={loading}
                  className="inline-flex items-center px-3 py-2 text-sm font-medium rounded-md bg-gray-100 text-gray-800 border border-gray-300 hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Ignore
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Pagination */}
      {processedData.length > 0 && <PaginationControls />}
    </div>
  );
}
