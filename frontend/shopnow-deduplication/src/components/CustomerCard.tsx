import React, { useState } from 'react';
import { 
  User, 
  Mail, 
  Phone, 
  Calendar, 
  ChevronDown, 
  ChevronUp, 
  AlertCircle,
  CheckCircle
} from 'lucide-react';
import type { Customer } from '../types/Customer';
import { MatchScoreBadge } from './MatchScoreBadge';

interface CustomerCardProps {
  customer: Customer;
  otherCustomer?: Customer;
  matchScore?: number;
  showDifferences?: boolean;
  variant?: 'default' | 'compact' | 'detailed';
  className?: string;
}

interface FieldComparisonProps {
  label: string;
  value1: string | undefined;
  value2: string | undefined;
  icon?: React.ReactNode;
  showDifferences: boolean;
}

function FieldComparison({ 
  label, 
  value1, 
  value2, 
  icon, 
  showDifferences 
}: FieldComparisonProps) {
  const hasValue1 = Boolean(value1);
  const hasValue2 = Boolean(value2);
  const valuesEqual = value1?.toLowerCase().trim() === value2?.toLowerCase().trim();
  const isDifferent = showDifferences && hasValue1 && hasValue2 && !valuesEqual;
  const isMissing = showDifferences && ((hasValue1 && !hasValue2) || (!hasValue1 && hasValue2));

  return (
    <div className="space-y-1">
      <div className="flex items-center gap-2">
        {icon}
        <span className="text-xs font-medium text-gray-500 uppercase tracking-wide">
          {label}
        </span>
        {(isDifferent || isMissing) && (
          <AlertCircle className="w-3 h-3 text-orange-500" />
        )}
        {showDifferences && valuesEqual && hasValue1 && hasValue2 && (
          <CheckCircle className="w-3 h-3 text-green-500" />
        )}
      </div>
      <div className={`text-sm ${
        isDifferent ? 'bg-orange-50 border border-orange-200 rounded px-2 py-1' :
        isMissing ? 'bg-gray-50 border border-gray-200 rounded px-2 py-1' :
        showDifferences && valuesEqual && hasValue1 ? 'bg-green-50 border border-green-200 rounded px-2 py-1' :
        ''
      }`}>
        <div className={`${isDifferent ? 'text-orange-800' : isMissing ? 'text-gray-500' : 'text-gray-900'}`}>
          {value1 || <span className="italic text-gray-400">Not provided</span>}
        </div>
      </div>
    </div>
  );
}



export default function CustomerCard({
  customer,
  otherCustomer,
  matchScore,
  showDifferences = false,
  variant = 'default',
  className = ''
}: CustomerCardProps) {
  const [isExpanded, setIsExpanded] = useState(variant === 'detailed');

  const formatDate = (dateString: string | undefined) => {
    if (!dateString) return undefined;
    try {
      return new Date(dateString).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      });
    } catch {
      return dateString;
    }
  };

  const getInitials = (firstName: string, lastName: string) => {
    return `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
  };

  if (variant === 'compact') {
    return (
      <div className={`bg-white border border-gray-200 rounded-lg p-3 ${className}`}>
        <div className="flex items-center gap-3">
          <div className="flex-shrink-0 w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
            <span className="text-sm font-medium text-blue-800">
              {getInitials(customer.firstName, customer.lastName)}
            </span>
          </div>
          <div className="flex-1 min-w-0">
            <h4 className="text-sm font-medium text-gray-900 truncate">
              {customer.firstName} {customer.lastName}
            </h4>
            <p className="text-xs text-gray-500 truncate">{customer.email}</p>
          </div>
          {matchScore !== undefined && (
            <div className="flex-shrink-0">
              <span className={`inline-flex items-center px-2 py-1 rounded text-xs font-medium ${
                matchScore >= 90 ? 'bg-red-100 text-red-800' :
                matchScore >= 70 ? 'bg-yellow-100 text-yellow-800' :
                'bg-green-100 text-green-800'
              }`}>
                {matchScore}%
              </span>
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className={`bg-white border border-gray-200 rounded-lg shadow-sm ${className}`}>
      {/* Header */}
      <div className="p-4 border-b border-gray-200">
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <div className="flex-shrink-0 w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
              <span className="text-lg font-medium text-blue-800">
                {getInitials(customer.firstName, customer.lastName)}
              </span>
            </div>
            <div>
              <h3 className="text-lg font-semibold text-gray-900">
                {customer.firstName} {customer.lastName}
              </h3>
              <p className="text-sm text-gray-500">Customer ID: {customer.id}</p>
            </div>
          </div>
          
          {matchScore !== undefined && (
            <MatchScoreBadge score={matchScore} />
          )}
        </div>
      </div>

      {/* Basic Information */}
      <div className="p-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FieldComparison
            label="Email"
            value1={customer.email}
            value2={otherCustomer?.email}
            icon={<Mail className="w-3 h-3 text-gray-400" />}
            showDifferences={showDifferences}
          />
          
          <FieldComparison
            label="Phone"
            value1={customer.phone}
            value2={otherCustomer?.phone}
            icon={<Phone className="w-3 h-3 text-gray-400" />}
            showDifferences={showDifferences}
          />
        </div>

        {variant !== 'compact' && (
          <div className="mt-4">
            <button
              onClick={() => setIsExpanded(!isExpanded)}
              className="flex items-center gap-2 text-sm font-medium text-blue-600 hover:text-blue-800 transition-colors"
              aria-expanded={isExpanded}
              aria-controls={`customer-details-${customer.id}`}
            >
              {isExpanded ? (
                <>
                  <ChevronUp className="w-4 h-4" />
                  Hide Details
                </>
              ) : (
                <>
                  <ChevronDown className="w-4 h-4" />
                  Show Details
                </>
              )}
            </button>

            {isExpanded && (
              <div id={`customer-details-${customer.id}`} className="mt-4 space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <FieldComparison
                    label="First Name"
                    value1={customer.firstName}
                    value2={otherCustomer?.firstName}
                    icon={<User className="w-3 h-3 text-gray-400" />}
                    showDifferences={showDifferences}
                  />
                  
                  <FieldComparison
                    label="Last Name"
                    value1={customer.lastName}
                    value2={otherCustomer?.lastName}
                    icon={<User className="w-3 h-3 text-gray-400" />}
                    showDifferences={showDifferences}
                  />
                  
                  <FieldComparison
                    label="Signup Date"
                    value1={formatDate(customer.signupDate)}
                    value2={formatDate(otherCustomer?.signupDate)}
                    icon={<Calendar className="w-3 h-3 text-gray-400" />}
                    showDifferences={showDifferences}
                  />
                </div>

                {/* Additional metadata */}
                <div className="pt-4 border-t border-gray-100">
                  <h4 className="text-sm font-medium text-gray-700 mb-2">Additional Information</h4>
                  <div className="grid grid-cols-2 gap-4 text-xs text-gray-500">
                    <div>
                      <span className="font-medium">Record Created:</span>
                      <br />
                      {formatDate(customer.signupDate) || 'Unknown'}
                    </div>
                    <div>
                      <span className="font-medium">Customer ID:</span>
                      <br />
                      <code className="bg-gray-100 px-1 py-0.5 rounded text-xs">
                        {customer.id}
                      </code>
                    </div>
                  </div>
                </div>

                {/* Differences Summary */}
                {showDifferences && otherCustomer && (
                  <div className="pt-4 border-t border-gray-100">
                    <h4 className="text-sm font-medium text-gray-700 mb-2">Comparison Summary</h4>
                    <div className="grid grid-cols-3 gap-4 text-center">
                      <div className="text-xs">
                        <div className="text-green-600 font-medium">
                          {/* Count matching fields */}
                          {[
                            customer.email === otherCustomer.email && customer.email,
                            customer.phone === otherCustomer.phone && customer.phone,
                            customer.firstName === otherCustomer.firstName,
                            customer.lastName === otherCustomer.lastName,
                            customer.signupDate === otherCustomer.signupDate && customer.signupDate
                          ].filter(Boolean).length}
                        </div>
                        <div className="text-gray-500">Matching</div>
                      </div>
                      <div className="text-xs">
                        <div className="text-orange-600 font-medium">
                          {/* Count different fields */}
                          {[
                            customer.email !== otherCustomer.email && customer.email && otherCustomer.email,
                            customer.phone !== otherCustomer.phone && customer.phone && otherCustomer.phone,
                            customer.firstName !== otherCustomer.firstName,
                            customer.lastName !== otherCustomer.lastName,
                            customer.signupDate !== otherCustomer.signupDate && customer.signupDate && otherCustomer.signupDate
                          ].filter(Boolean).length}
                        </div>
                        <div className="text-gray-500">Different</div>
                      </div>
                      <div className="text-xs">
                        <div className="text-gray-600 font-medium">
                          {[
                            (customer.email && !otherCustomer.email) || (!customer.email && otherCustomer.email),
                            (customer.phone && !otherCustomer.phone) || (!customer.phone && otherCustomer.phone),
                            (customer.signupDate && !otherCustomer.signupDate) || (!customer.signupDate && otherCustomer.signupDate)
                          ].filter(Boolean).length}
                        </div>
                        <div className="text-gray-500">Missing</div>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}