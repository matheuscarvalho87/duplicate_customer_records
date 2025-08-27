# ShopNow Duplicate Management System

A comprehensive duplicate detection and management solution built with Salesforce (backend) and React TypeScript (frontend). This system automatically identifies potential duplicate customer records using advanced matching algorithms and provides an intuitive interface for reviewing and resolving duplicates.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [Configuration](#configuration)
- [Running the Application](#running-the-application)
- [Testing](#testing)
- [API Documentation](#api-documentation)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)

## Project Overview

The ShopNow Duplicate Management System addresses the critical business need for maintaining clean customer data by:

- **Automated Detection**: Batch processing to identify potential duplicates using multiple matching algorithms
- **Intelligent Scoring**: Advanced fuzzy matching with configurable scoring thresholds
- **User-Friendly Interface**: React-based dashboard for reviewing and managing duplicate records
- **Security First**: Comprehensive CRUD/FLS checks and custom permission validation
- **Enterprise Ready**: Built with scalability, monitoring, and deployment best practices

## Architecture

### Backend (Salesforce)
- **Custom Objects**: Customer__c and Duplicate_Match__c with proper relationships and validation
- **Apex Services**: Core business logic with separation of concerns
- **Batch Processing**: Scalable duplicate detection with automatic scheduling
- **REST API**: Secure endpoints for frontend integration
- **Security Layer**: CRUD/FLS validation and custom permission framework

### Frontend (React/TypeScript)
- **Modern Stack**: Vite, TypeScript, Tailwind CSS
- **State Management**: React Query for server state management
- **Component Architecture**: Reusable, accessible components
- **Authentication**: OAuth 2.0 integration with Salesforce

## Features

### Core Functionality
- **Multiple Match Types**:
  - Exact email matching (Score: 100)
  - Fuzzy name + phone matching (Score: 70)
  - Same last name + phone matching (Score: 50)

- **Advanced Matching Algorithms**:
  - Levenshtein distance calculation
  - Diacritic normalization for international names
  - Phone number standardization
  - Configurable similarity thresholds

- **Batch Processing**:
  - Hourly automated duplicate detection
  - Configurable batch sizes (default: 200 records)
  - Comprehensive error handling and retry logic
  - Email notifications with execution summaries

- **User Interface**:
  - Virtual scrolling for large datasets
  - Responsive design with accessibility features

### Security & Performance
- Object-level and field-level security validation
- Custom permission-based access control
- Query optimization with proper indexing
- Request/response logging and monitoring
- Bulkification best practices throughout

## Prerequisites

### Salesforce Environment
- Salesforce Developer Edition or higher
- System Administrator privileges
- API access enabled

### Development Environment
- Node.js 22.x or higher
- pnpm (recommended) or npm
- Git
- Modern web browser

## Installation & Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd duplicate_customer_records
```

### 2. Salesforce Setup

#### Deploy Salesforce Components

Using Salesforce CLI:

```bash
cd salesforce/shopnow-deduplication/
sfdx force:source:deploy -p force-app/main/default/
```

Or using VS Code with Salesforce Extension Pack:
1. Open the `salesforce/shopnow-deduplication/` directory in VS Code
2. Right-click on `force-app/main/default/`
3. Select "SFDX: Deploy Source to Org"

#### Create Custom Permission Set

1. Navigate to Setup > Permission Sets
2. Create a new Permission Set named "Duplicate_Manager"
3. Assign the following permissions:
   - Object: Customer__c (Read, Create, Edit, Delete)
   - Object: Duplicate_Match__c (Read, Create, Edit, Delete)
   - Custom Permission: ShopNow_Deduplication_Access

#### Schedule Batch Job

Execute in Anonymous Apex:

```apex
// Schedule hourly duplicate detection
DuplicateMatchingScheduler.scheduleHourly();
```

### 3. Frontend Setup

#### Install Dependencies

```bash
cd frontend/shopnow-deduplication/
pnpm install
```

#### Environment Configuration

```bash
cp .env.example .env.local
```

## Configuration

### Salesforce OAuth Setup

1. **Create Connected App**:
   - Navigate to Setup > App Manager
   - Click "New Connected App"
   - Fill in basic information:
     - Connected App Name: `ShopNow Duplicate Management`
     - API Name: `ShopNow_Duplicate_Management`
     - Contact Email: Your email

2. **OAuth Settings**:
   - Enable OAuth Settings: ✓
   - Callback URL: `http://localhost:5173/callback`
   - Selected OAuth Scopes:
     - Access and manage your data (api)
     - Perform requests on your behalf at any time (refresh_token)
     - Access your basic information (id, profile, email)

3. **Security Settings**:
   - IP Relaxation: Relax IP restrictions
   - Refresh Token Policy: Refresh token is valid until revoked

4. **Consumer Key**:
   - After saving, note the Consumer Key from the connected app details

### Environment Variables

Edit `.env.local` in the frontend directory:

```env
VITE_SF_BASE_URL="https://<your-alias-here>.develop.my.salesforce.com"

VITE_DEV_AUTH_PROXY_PATH="/sf-auth"

VITE_SF_AUTH_URL="https://<your-alias-here>.develop.my.salesforce.com/services/oauth2/authorize"
VITE_SF_TOKEN_URL="https://<your-alias-here>.develop.my.salesforce.com/services/oauth2/token"

VITE_SF_CLIENT_ID=your_consumer_key_here
VITE_SF_REDIRECT_URI="http://localhost:5173/oauth/callback"
VITE_SF_SCOPES="openid refresh_token api web"

VITE_LOG_LEVEL="debug"
```

### Salesforce Custom Settings (Optional)

For production environments, consider creating Custom Settings or Custom Metadata Types for:

- Batch processing schedule intervals
- Match score thresholds
- Email notification recipients
- API rate limiting configuration

## Running the Application

### Development Mode

```bash
cd frontend/
pnpm dev
```

The application will be available at `http://localhost:5173`

### Production Build

```bash
cd frontend/shopnow-deduplication/
pnpm build

pnpm preview
```

### Initial Data Setup

To populate test data for development:

```apex
// Execute in Anonymous Apex
DataFactory.createTestData();
```

## Testing

### Salesforce Tests

Run Apex tests using Salesforce CLI:

```bash
# Run all tests
sfdx force:apex:test:run --codecoverage --resultformat human

# Run specific test class
sfdx force:apex:test:run --classnames "DuplicateMatchingServiceTest" --codecoverage
```

### Frontend Tests

```bash
cd frontend/

# Run unit tests
pnpm test

# Run tests with coverage
pnpm test:coverage

# Run integration tests
pnpm test:integration
```

### Test Coverage Requirements

- **Salesforce**: Minimum 90% code coverage
- **Frontend**: Minimum 80% code coverage

## API Documentation

### Authentication

The system uses OAuth 2.0 with PKCE for secure authentication with Salesforce.

### Available Endpoints

#### GET `/services/apexrest/duplicates/pending`

Retrieve pending duplicate matches with pagination and filtering support.

**Query Parameters:**
- `limit` (integer): Records per page (default: 50, max: 200)
- `offset` (integer): Pagination offset (default: 0)
- `minScore` (decimal): Minimum match score filter (default: 0)
- `sinceDays` (integer): Filter records created within N days (default: 365)
- `sort` (string): Sort field ('score' or 'createddate', default: 'createddate')
- `order` (string): Sort order ('asc' or 'desc', default: 'desc')

**Response:**
```json
{
  "items": [
    {
      "id": "a00XX000000001",
      "score": 85,
      "status": "Pending Review",
      "createdAt": "2024-01-15T10:30:00.000Z",
      "customerA": {
        "id": "a01XX000000001",
        "firstName": "John",
        "lastName": "Doe",
        "email": "john.doe@example.com",
        "phone": "(555) 123-4567"
      },
      "customerB": {
        "id": "a01XX000000002",
        "firstName": "Jon",
        "lastName": "Doe",
        "email": "j.doe@example.com",
        "phone": "(555) 123-4567"
      }
    }
  ],
  "page": {
    "limit": 50,
    "offset": 0,
    "total": 127
  }
}
```

#### POST `/services/apexrest/duplicates/{id}/resolve`

Resolve a duplicate match by merging or ignoring.

**Request Body:**
```json
{
  "action": "merge" // or "ignore"
}
```

**Response:**
```json
{
  "status": "ok",
  "action": "merge",
  "matchId": "a00XX000000001"
}
```

### Error Handling

All API endpoints return structured error responses:

```json
{
  "message": "Bad Request",
  "details": "Invalid action parameter. Use 'merge' or 'ignore'."
}
```

**HTTP Status Codes:**
- `200`: Success
- `400`: Bad Request (validation errors)
- `403`: Forbidden (insufficient permissions)
- `404`: Not Found
- `500`: Internal Server Error

## Deployment

### Frontend Deployment

#### Build Optimization

```bash
cd frontend/shopnow-deduplication/
pnpm build
```

#### Environment-Specific Builds

For different environments, create corresponding `.env` files:

- `.env.development`
- `.env.staging`
- `.env.production`


## Contributing

### Development Workflow

1. **Branch Naming**: `feature/description`, `bugfix/description`, `hotfix/description`
2. **Commit Messages**: Follow conventional commits format
3. **Pull Requests**: Include tests and documentation updates
4. **Code Review**: Required before merging to main branch

### Code Standards

#### Salesforce (Apex)
- Follow Salesforce Apex best practices
- Maintain 90%+ test coverage
- Use proper bulkification patterns
- Include comprehensive error handling
- Document complex business logic

#### Frontend (TypeScript/React)
- Use TypeScript strict mode
- Follow ESLint and Prettier configurations
- Implement proper error boundaries
- Use semantic HTML and ARIA labels

## Troubleshooting

### Common Issues

#### Authentication Issues

**Problem**: OAuth authentication fails
**Solution**: 
1. Verify the Connected App callback URL matches exactly
2. Check that the Consumer Key is correctly set in `.env.local`
3. Ensure IP restrictions are relaxed for the Connected App
4. Clear browser cache and cookies

#### API Permission Errors

**Problem**: 403 Forbidden responses from Salesforce API
**Solution**:
1. Verify the user has the "Duplicate_Manager" permission set assigned
2. Check Custom Permission "ShopNow_Deduplication_Access" is included
3. Validate object and field-level security permissions
4. Review sharing rules for Custom Objects

#### Performance Issues

**Problem**: Slow duplicate detection batch processing
**Solution**:
1. Review batch size configuration (default: 200)
2. Check for missing indexes on frequently queried fields
3. Monitor SOQL query limits and optimize WHERE clauses
4. Consider partitioning large datasets by date ranges

#### Frontend Build Issues

**Problem**: Build fails with TypeScript errors
**Solution**:
1. Ensure all dependencies are correctly installed: `pnpm install`
2. Check TypeScript version compatibility
3. Review type definitions for third-party packages
4. Clear node_modules and reinstall if needed

### Logging and Monitoring

#### Salesforce Monitoring

- Check Debug Logs for detailed execution traces
- Monitor Apex Jobs for batch processing status
- Review Custom Object records for data integrity
- Use Salesforce Inspector for real-time debugging

#### Frontend Monitoring

- Browser DevTools for network requests and console logs
- React DevTools for component hierarchy debugging
- Performance tab for loading time analysis

### Performance Optimization

#### Database Optimization

1. **Indexing Strategy**:
   - Email__c field (for exact matches)
   - Phone__c field (for phone matching)
   - CreatedDate (for batch processing queries)

2. **Query Optimization**:
   - Use selective WHERE clauses
   - Implement proper LIMIT clauses
   - Avoid SOQL in loops patterns

#### Frontend Optimization

1. **Bundle Optimization**:
   - Implement code splitting with React.lazy()
   - Use tree shaking for unused code elimination
   - Optimize images and assets

2. **Runtime Performance**:
   - Implement virtual scrolling for large lists
   - Use React.memo for expensive components
   - Debounce user input for search functionality

---

**Project Status**: Active Development
**Last Updated**: August 2025
**Version**: 1.0.0
**License**: MIT