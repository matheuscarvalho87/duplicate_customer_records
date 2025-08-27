import { http, HttpResponse } from 'msw'
import { mockDuplicates, createMergeResponse } from './mockData'

const BASE_URL = 'https://orgfarm-d26e890132-dev-ed.develop.my.salesforce.com'

export const handlers = [
  http.get(`${BASE_URL}/services/apexrest/duplicates/pending`, ({ request }) => {
    const url = new URL(request.url)
    const limit = parseInt(url.searchParams.get('limit') || '10')
    const offset = parseInt(url.searchParams.get('offset') || '0')
    const minScore = parseFloat(url.searchParams.get('minScore') || '0')
    
    const filteredDuplicates = mockDuplicates.filter(dup => dup.score >= minScore)
    const paginatedData = filteredDuplicates.slice(offset, offset + limit)
    const total = filteredDuplicates.length
    
    return HttpResponse.json({
      pagination: {
        hasMore: offset + limit < total,
        total,
        offset,
        limit
      },
      items: paginatedData
    })
  }),

  http.post(`${BASE_URL}/services/apexrest/duplicates/:id/resolve`, async ({ request, params }) => {
    const body = await request.json() as { action: string }
    const { id } = params as { id: string }
    
    if (!['merge', 'ignore'].includes(body.action)) {
      return HttpResponse.json(
        { message: 'Bad Request', details: 'Action must be merge or ignore' },
        { status: 400 }
      )
    }
    
    return HttpResponse.json(createMergeResponse(id, body.action))
  }),

  http.post('https://login.salesforce.com/services/oauth2/token', async ({ request }) => {
    const body = await request.text()
    const params = new URLSearchParams(body)
    
    if (params.get('grant_type') === 'authorization_code') {
      return HttpResponse.json({
        access_token: 'mock_access_token_12345',
        refresh_token: 'mock_refresh_token_12345',
        instance_url: BASE_URL,
        id: `${BASE_URL}/id/00D000000000000EAA/005000000000000AAA`,
        token_type: 'Bearer',
        issued_at: Date.now().toString(),
        signature: 'mock_signature'
      })
    }
    
    return HttpResponse.json(
      { error: 'invalid_grant', error_description: 'Invalid authorization code' },
      { status: 400 }
    )
  }),

  http.get(`${BASE_URL}/services/apexrest/duplicates/error`, () => {
    return HttpResponse.json(
      { message: 'Internal Server Error', details: 'Database connection failed' },
      { status: 500 }
    )
  }),

  http.get(`${BASE_URL}/services/apexrest/duplicates/timeout`, () => {
    return HttpResponse.error()
  })
]