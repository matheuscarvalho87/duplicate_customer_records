// src/services/__tests__/duplicateService.test.ts
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { duplicateService } from '../duplicateService'
import { duplicateFactory } from '../../test/factories/duplicateFactory'

// Mock the entire api/client module
vi.mock('../../api/client', () => ({
  http: {
    get: vi.fn(),
    post: vi.fn(),
  }
}))

// Import after mocking to get the mocked version
const { http } = await import('../../api/client')
const mockGet = vi.mocked(http.get)
const mockPost = vi.mocked(http.post)

describe('duplicateService', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('getPending', () => {
    it('should fetch pending duplicates with default parameters', async () => {
      const mockResponse = {
        data: {
          pagination: {
            total: 2,
            offset: 0,
            limit: 50,
            hasMore: false
          },
          items: duplicateFactory.buildMany(2)
        }
      }

      mockGet.mockResolvedValueOnce(mockResponse)

      const result = await duplicateService.getPending()

      expect(mockGet).toHaveBeenCalledWith(
        '/services/apexrest/duplicates/pending?limit=50&offset=0&minScore=0&sort=score&order=desc'
      )
      expect(result).toEqual({
        duplicates: mockResponse.data.items,
        pagination: {
          page: 1,
          pageSize: 50,
          total: 2,
          hasMore: false
        }
      })
    })

    it('should fetch pending duplicates with custom parameters', async () => {
      const mockResponse = {
        data: {
          pagination: {
            total: 5,
            offset: 20,
            limit: 10,
            hasMore: true
          },
          items: duplicateFactory.buildMany(10)
        }
      }

      mockGet.mockResolvedValueOnce(mockResponse)

      const params = {
        limit: 10,
        offset: 20,
        minScore: 70,
        sort: 'createdAt' as const,
        order: 'asc' as const
      }

      const result = await duplicateService.getPending(params)

      expect(mockGet).toHaveBeenCalledWith(
        '/services/apexrest/duplicates/pending?limit=10&offset=20&minScore=70&sort=createdAt&order=asc'
      )
      expect(result.pagination).toEqual({
        page: 3, // (20 / 10) + 1
        pageSize: 10,
        total: 5,
        hasMore: true
      })
    })

    it('should handle empty response gracefully', async () => {
      const mockResponse = {
        data: {
          pagination: {
            total: 0,
            offset: 0,
            limit: 50,
            hasMore: false
          },
          items: []
        }
      }

      mockGet.mockResolvedValueOnce(mockResponse)

      const result = await duplicateService.getPending()

      expect(result.duplicates).toEqual([])
      expect(result.pagination.total).toBe(0)
    })

    it('should handle missing items array', async () => {
      const mockResponse = {
        data: {
          pagination: {
            total: 0,
            offset: 0,
            limit: 50,
            hasMore: false
          }
          // items is undefined
        }
      }

      mockGet.mockResolvedValueOnce(mockResponse)

      const result = await duplicateService.getPending()

      expect(result.duplicates).toEqual([])
    })

    it('should throw error when API call fails', async () => {
      const apiError = new Error('Network error')
      mockGet.mockRejectedValueOnce(apiError)

      await expect(duplicateService.getPending()).rejects.toThrow('Network error')
      
      expect(mockGet).toHaveBeenCalledOnce()
    })

    it('should log error when API call fails', async () => {
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
      const apiError = new Error('API Error')
      mockGet.mockRejectedValueOnce(apiError)

      await expect(duplicateService.getPending()).rejects.toThrow()

      expect(consoleSpy).toHaveBeenCalledWith(
        'Error fetching pending duplicates:',
        apiError
      )

      consoleSpy.mockRestore()
    })

    it('should calculate correct page number for various offsets', async () => {
      const testCases = [
        { offset: 0, limit: 10, expectedPage: 1 },
        { offset: 10, limit: 10, expectedPage: 2 },
        { offset: 25, limit: 10, expectedPage: 3 }, // 25/10 = 2.5, floor + 1 = 3
        { offset: 100, limit: 25, expectedPage: 5 }
      ]

      for (const testCase of testCases) {
        mockGet.mockResolvedValueOnce({
          data: {
            pagination: {
              total: 200,
              offset: testCase.offset,
              limit: testCase.limit,
              hasMore: true
            },
            items: []
          }
        })

        const result = await duplicateService.getPending({
          offset: testCase.offset,
          limit: testCase.limit
        })

        expect(result.pagination.page).toBe(testCase.expectedPage)
      }
    })
  })

  describe('getPendingSimple', () => {
    it('should fetch all duplicates with limit 1000', async () => {
      const mockDuplicates = duplicateFactory.buildMany(5)
      const mockResponse = {
        data: {
          pagination: {
            total: 5,
            offset: 0,
            limit: 1000,
            hasMore: false
          },
          items: mockDuplicates
        }
      }

      mockGet.mockResolvedValueOnce(mockResponse)

      const result = await duplicateService.getPendingSimple()

      expect(mockGet).toHaveBeenCalledWith(
        '/services/apexrest/duplicates/pending?limit=1000&offset=0&minScore=0&sort=score&order=desc'
      )
      expect(result).toEqual(mockDuplicates)
    })

    it('should propagate errors from getPending', async () => {
      const apiError = new Error('Service unavailable')
      mockGet.mockRejectedValueOnce(apiError)

      await expect(duplicateService.getPendingSimple()).rejects.toThrow('Service unavailable')
    })
  })

  describe('resolve', () => {
    it('should resolve duplicate with merge action', async () => {
      mockPost.mockResolvedValueOnce({})

      const duplicateId = 'a01gL00000TestId'
      
      await duplicateService.resolve(duplicateId, 'merge')

      expect(mockPost).toHaveBeenCalledWith(
        `/services/apexrest/duplicates/${duplicateId}/resolve`,
        { action: 'merge' }
      )
    })

    it('should resolve duplicate with ignore action', async () => {
      mockPost.mockResolvedValueOnce({})

      const duplicateId = 'a01gL00000TestId'
      
      await duplicateService.resolve(duplicateId, 'ignore')

      expect(mockPost).toHaveBeenCalledWith(
        `/services/apexrest/duplicates/${duplicateId}/resolve`,
        { action: 'ignore' }
      )
    })

    it('should encode duplicate ID in URL', async () => {
      mockPost.mockResolvedValueOnce({})

      const duplicateIdWithSpecialChars = 'a01gL/00000+Test Id'
      
      await duplicateService.resolve(duplicateIdWithSpecialChars, 'merge')

      expect(mockPost).toHaveBeenCalledWith(
        `/services/apexrest/duplicates/${encodeURIComponent(duplicateIdWithSpecialChars)}/resolve`,
        { action: 'merge' }
      )
    })

    it('should throw error when API call fails', async () => {
      const apiError = new Error('Forbidden')
      mockPost.mockRejectedValueOnce(apiError)

      await expect(duplicateService.resolve('testId', 'merge')).rejects.toThrow('Forbidden')
      
      expect(mockPost).toHaveBeenCalledOnce()
    })

    it('should log error with context when resolution fails', async () => {
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
      const apiError = new Error('Validation failed')
      const duplicateId = 'a01gL00000TestId'
      const action = 'ignore'
      
      mockPost.mockRejectedValueOnce(apiError)

      await expect(duplicateService.resolve(duplicateId, action)).rejects.toThrow()

      expect(consoleSpy).toHaveBeenCalledWith(
        `Error resolving duplicate ${duplicateId} with action ${action}:`,
        apiError
      )

      consoleSpy.mockRestore()
    })

    it('should handle various duplicate ID formats', async () => {
      mockPost.mockResolvedValue({})

      const testIds = [
        'a01gL00000Simple',
        'a01gL00000123456789012345',
        'a01-special-chars_test',
        '001234567890123456' // Standard Salesforce ID format
      ]

      for (const id of testIds) {
        await duplicateService.resolve(id, 'merge')
        
        expect(mockPost).toHaveBeenCalledWith(
          `/services/apexrest/duplicates/${encodeURIComponent(id)}/resolve`,
          { action: 'merge' }
        )
      }

      expect(mockPost).toHaveBeenCalledTimes(testIds.length)
    })
  })
})