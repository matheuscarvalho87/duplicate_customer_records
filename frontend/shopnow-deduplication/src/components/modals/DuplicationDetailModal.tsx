import type { DuplicateMatch } from '@/types/DuplicateMatch';
import CustomerCard from '../CustomerCard';
import { X } from 'lucide-react';

interface DuplicateDetailModalProps {
  duplicate: DuplicateMatch | null;
  onClose: () => void;
}

export default function DuplicateDetailModal({ duplicate, onClose }: DuplicateDetailModalProps) {
  if (!duplicate) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-900">Duplicate Match Details</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            aria-label="Close modal"
          >
            <X className="w-6 h-6" />
          </button>
        </div>
        
        <div className="p-6 space-y-6">
          {/* Match Score and Status */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <span className={`inline-flex items-center px-3 py-2 rounded-full text-lg font-semibold ${
                duplicate.score >= 90 ? 'bg-red-100 text-red-800' :
                duplicate.score >= 70 ? 'bg-yellow-100 text-yellow-800' :
                'bg-green-100 text-green-800'
              }`}>
                {duplicate.score}% Match
              </span>
              <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
                duplicate.status === 'Pending Review' ? 'bg-gray-100 text-gray-800' :
                duplicate.status === 'Merged' ? 'bg-green-100 text-green-800' :
                'bg-red-100 text-red-800'
              }`}>
                {duplicate.status}
              </span>
            </div>
          </div>

          {/* Customer Comparison */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div>
              <h3 className="text-lg font-medium text-gray-900 mb-4">Customer A</h3>
              <CustomerCard
                customer={duplicate.customerA}
                otherCustomer={duplicate.customerB}
                showDifferences={true}
                variant="detailed"
              />
            </div>
            
            <div>
              <h3 className="text-lg font-medium text-gray-900 mb-4">Customer B</h3>
              <CustomerCard
                customer={duplicate.customerB}
                otherCustomer={duplicate.customerA}
                showDifferences={true}
                variant="detailed"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}