# Search Functionality Implementation

This document describes the comprehensive search functionality that has been implemented across the application, including both backend and frontend components.

## Features

### 🔍 **Comprehensive Search**
- Search across multiple entities: Events, Users, and Tags
- Real-time search suggestions with debouncing
- Advanced filtering capabilities
- Relevance-based result ranking

### 🎯 **Advanced Filtering**
- Filter by entity type (Events, Users, Tags)
- Event status filtering (Draft, Published, Ongoing, Completed, Cancelled)
- Event type filtering (Conference, Workshop, Meetup, Webinar, Hackathon, Other)
- Date range filtering
- Location-based filtering with radius
- Tag-based filtering

### 📱 **Modern UI/UX**
- Search bar with filter button
- Modal-based search results display
- Real-time suggestions dropdown
- Responsive design with Tamagui components
- Loading states and error handling

## Backend Implementation

### Search Service (`server/src/features/search/`)

#### Models
- **SearchResult**: Database model for storing search results
- **SearchService**: Core search logic with relevance scoring
- **SearchController**: HTTP request handling
- **Validation**: Request validation using Joi

#### Key Features
- **Efficient Database Queries**: Uses Sequelize with optimized WHERE clauses
- **Relevance Scoring**: Intelligent ranking based on:
  - Exact matches (highest priority)
  - Partial matches
  - Recency
  - Popularity metrics
- **Pagination**: Supports infinite scroll with cursor-based pagination
- **Caching**: Ready for Redis integration

#### API Endpoints

```typescript
// Main search endpoint
GET /api/search?query=search_term&filters[types][]=event&page=1&limit=20

// Search suggestions
GET /api/search/suggestions?query=search_term&limit=5

// Search options (available filters)
GET /api/search/options
```

#### Search Filters

```typescript
interface ISearchFilters {
  types?: ('event' | 'user' | 'tag')[];
  eventStatus?: EEventStatus[];
  eventType?: EEventType[];
  dateRange?: {
    start: Date;
    end: Date;
  };
  location?: {
    latitude: number;
    longitude: number;
    radius: number; // in kilometers
  };
  tags?: string[];
  limit?: number;
  offset?: number;
}
```

## Frontend Implementation

### Components

#### 1. SearchBar (`client/components/SearchBar/`)
- **Features**:
  - Real-time search suggestions
  - Debounced input (300ms delay)
  - Filter button with visual indicator
  - Clear search functionality
  - Keyboard navigation (Enter, Escape)

#### 2. SearchModal (`client/components/SearchModal/`)
- **Features**:
  - Full-screen modal with sheet animation
  - Integrated search bar
  - Filter panel with collapsible UI
  - Result cards with rich metadata
  - Infinite scroll with "Load More"
  - Result categorization with icons and badges

#### 3. useDebounce Hook (`client/hooks/useDebounce.ts`)
- **Purpose**: Optimize API calls by delaying search requests
- **Usage**: 300ms delay for search suggestions

### API Integration (`client/common/api/search.action.ts`)

```typescript
// Main search function
export const search = async (
  query: string,
  filters?: ISearchFilters,
  page: number = 1,
  limit: number = 20
): Promise<ISearchResponse>

// Get search suggestions
export const getSearchSuggestions = async (
  query: string,
  limit: number = 5
): Promise<ISuggestionsResponse>

// Get available search options
export const getSearchOptions = async (): Promise<ISearchOptionsResponse>
```

## Usage

### Basic Search
1. Click the "Search Events, Users & Tags" button on the Home screen
2. Type your search query (minimum 2 characters)
3. View real-time suggestions as you type
4. Press Enter or click a suggestion to search

### Advanced Filtering
1. Open the search modal
2. Click the "Filters" button
3. Select desired filter options:
   - Entity types (Events, Users, Tags)
   - Event status
   - Event type
   - Date range
   - Location radius
4. Results update automatically

### Result Navigation
- **Events**: Click to navigate to event details
- **Users**: Click to navigate to user profile
- **Tags**: Click to navigate to events with that tag

## Technical Details

### Relevance Scoring Algorithm

#### Events
- Exact name match: +10 points
- Name starts with query: +8 points
- Name contains query: +6 points
- Description contains query: +3 points
- Tag match: +4 points
- Recent events (< 7 days): +2 points
- Popular events (> 10 participants): +1 point

#### Users
- Exact username match: +10 points
- Username starts with query: +8 points
- Username contains query: +6 points
- Full name contains query: +4 points
- Bio contains query: +2 points
- Verified users: +1 point
- Popular users (> 100 followers): +1 point

#### Tags
- Exact name match: +10 points
- Name starts with query: +8 points
- Name contains query: +6 points
- Description contains query: +3 points
- High usage (> 10 times): +1 point

### Performance Optimizations

1. **Debounced Search**: 300ms delay prevents excessive API calls
2. **Database Indexing**: Optimized queries with proper WHERE clauses
3. **Pagination**: Cursor-based pagination for large result sets
4. **Caching Ready**: Architecture supports Redis integration
5. **Lazy Loading**: Results load progressively

### Error Handling

- **Input Validation**: Minimum 2 characters required
- **API Error Handling**: Graceful fallbacks for failed requests
- **Loading States**: Visual feedback during searches
- **Empty States**: Helpful messages when no results found

## Future Enhancements

### Planned Features
1. **Search History**: Remember recent searches
2. **Saved Searches**: Allow users to save filter combinations
3. **Advanced Filters**: More granular filtering options
4. **Search Analytics**: Track popular searches
5. **Fuzzy Search**: Handle typos and similar terms
6. **Elasticsearch Integration**: For more advanced search capabilities

### Performance Improvements
1. **Redis Caching**: Cache popular search results
2. **Database Indexing**: Add full-text search indexes
3. **CDN Integration**: For static search assets
4. **Service Workers**: Offline search capabilities

## Dependencies

### Backend
- `joi`: Request validation
- `sequelize`: Database ORM
- `express`: HTTP server

### Frontend
- `date-fns`: Date formatting
- `tamagui`: UI components
- `expo-router`: Navigation

## Testing

To test the search functionality:

1. **Start the backend server**:
   ```bash
   cd server
   npm run dev
   ```

2. **Start the frontend**:
   ```bash
   cd client
   npm start
   ```

3. **Test search scenarios**:
   - Search for event names
   - Search for usernames
   - Search for tags
   - Apply various filters
   - Test pagination
   - Test suggestions

## API Documentation

### Search Endpoint
```
GET /api/search
```

**Query Parameters**:
- `query` (required): Search term (min 2 characters)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Results per page (default: 20, max: 100)
- `filters[types][]` (optional): Array of entity types
- `filters[eventStatus][]` (optional): Array of event statuses
- `filters[eventType][]` (optional): Array of event types
- `filters[dateRange][start]` (optional): Start date (ISO string)
- `filters[dateRange][end]` (optional): End date (ISO string)
- `filters[location][latitude]` (optional): Latitude
- `filters[location][longitude]` (optional): Longitude
- `filters[location][radius]` (optional): Radius in kilometers
- `filters[tags][]` (optional): Array of tag names

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "type": "event|user|tag",
      "title": "Result Title",
      "description": "Result Description",
      "imageUrl": "https://...",
      "metadata": {},
      "relevanceScore": 8.5,
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "total": 100,
    "page": 1,
    "limit": 20,
    "hasNext": true
  }
}
```

This implementation provides a robust, scalable search system that can be easily extended and optimized for future requirements.