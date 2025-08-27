
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { authService, authStore } from '../authService'

vi.mock('axios')
vi.mock('../config/env', () => ({
  ENV: {
    SF_CLIENT_ID: 'test_client_id',
    SF_REDIRECT_URI: 'http://localhost:3000/callback',
    SF_SCOPES: 'api refresh_token',
    SF_AUTH_URL: 'https://login.salesforce.com/services/oauth2/authorize'
  },
  tokenEndpoint: 'https://login.salesforce.com/services/oauth2/token'
}))
vi.mock('../utils/pkce')
vi.mock('../utils/logger')

const { default: axios } = await import('axios')
const mockAxios = vi.mocked(axios)

// Mock localStorage
const localStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
}
Object.defineProperty(window, 'localStorage', { value: localStorageMock })

// Mock crypto.randomUUID
Object.defineProperty(globalThis, 'crypto', {
  value: {
    randomUUID: vi.fn(() => 'mock-uuid-1234')
  }
})

// Mock window.location
const mockLocation = {
  assign: vi.fn(),
  href: 'http://localhost:3000'
}
Object.defineProperty(window, 'location', { value: mockLocation })

describe('authService', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    localStorageMock.getItem.mockReturnValue(null)
  })

  afterEach(() => {
    vi.clearAllMocks()
  })


  describe('handleOAuthCallback', () => {
    it('should return false when no code in URL', async () => {
      Object.defineProperty(window, 'location', {
        value: { href: 'http://localhost:3000/callback' }
      })

      const result = await authService.handleOAuthCallback()

      expect(result).toBe(false)
      expect(mockAxios.post).not.toHaveBeenCalled()
    })
  })

  describe('refresh', () => {
    it('should return null when no refresh token', async () => {
      localStorageMock.getItem.mockReturnValue(null)

      const result = await authService.refresh()

      expect(result).toBe(null)
      expect(mockAxios.post).not.toHaveBeenCalled()
    })
  })

  describe('logout', () => {
    it('should clear all stored tokens', () => {
      authService.logout()

      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_access_token')
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_refresh_token')
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_instance_url')
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_access_exp')
    })
  })

  describe('isAccessTokenValid', () => {
    it('should return true when token is valid', () => {
      const futureTime = Date.now() + 60000 // 1 minute from now
      localStorageMock.getItem.mockImplementation((key) => {
        if (key === 'sf_access_exp') return futureTime.toString()
        return null
      })

      const result = authService.isAccessTokenValid()

      expect(result).toBe(true)
    })

    it('should return false when token is expired', () => {
      const pastTime = Date.now() - 60000 // 1 minute ago
      localStorageMock.getItem.mockImplementation((key) => {
        if (key === 'sf_access_exp') return pastTime.toString()
        return null
      })

      const result = authService.isAccessTokenValid()

      expect(result).toBe(false)
    })

    it('should return false when no expiration time stored', () => {
      localStorageMock.getItem.mockReturnValue(null)

      const result = authService.isAccessTokenValid()

      expect(result).toBe(false)
    })

    it('should return false when token expires within 30 seconds', () => {
      const almostExpired = Date.now() + 20000 // 20 seconds from now (less than 30s buffer)
      localStorageMock.getItem.mockImplementation((key) => {
        if (key === 'sf_access_exp') return almostExpired.toString()
        return null
      })

      const result = authService.isAccessTokenValid()

      expect(result).toBe(false)
    })
  })
})

describe('authStore', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    localStorageMock.getItem.mockReturnValue(null)
  })

  describe('accessToken', () => {
    it('should get and set access token', () => {
      localStorageMock.getItem.mockReturnValue('test_token')
      
      expect(authStore.accessToken).toBe('test_token')
      expect(localStorageMock.getItem).toHaveBeenCalledWith('sf_access_token')

      authStore.accessToken = 'new_token'
      expect(localStorageMock.setItem).toHaveBeenCalledWith('sf_access_token', 'new_token')

      authStore.accessToken = null
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_access_token')
    })
  })

  describe('refreshToken', () => {
    it('should get and set refresh token', () => {
      localStorageMock.getItem.mockReturnValue('refresh_123')
      
      expect(authStore.refreshToken).toBe('refresh_123')
      
      authStore.refreshToken = 'new_refresh'
      expect(localStorageMock.setItem).toHaveBeenCalledWith('sf_refresh_token', 'new_refresh')
    })
  })

  describe('instanceUrl', () => {
    it('should get and set instance URL', () => {
      localStorageMock.getItem.mockReturnValue('https://test.salesforce.com')
      
      expect(authStore.instanceUrl).toBe('https://test.salesforce.com')
      
      authStore.instanceUrl = 'https://new.salesforce.com'
      expect(localStorageMock.setItem).toHaveBeenCalledWith('sf_instance_url', 'https://new.salesforce.com')
    })
  })

  describe('accessExp', () => {
    it('should get and set access expiration as number', () => {
      localStorageMock.getItem.mockReturnValue('1609459200000')
      
      expect(authStore.accessExp).toBe(1609459200000)
      
      authStore.accessExp = 1609459200001
      expect(localStorageMock.setItem).toHaveBeenCalledWith('sf_access_exp', '1609459200001')
    })

    it('should return null when no expiration stored', () => {
      localStorageMock.getItem.mockReturnValue(null)
      
      expect(authStore.accessExp).toBe(null)
    })
  })

  describe('clear', () => {
    it('should clear all stored values', () => {
      authStore.clear()

      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_access_token')
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_refresh_token')
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_instance_url')
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('sf_access_exp')
    })
  })
})