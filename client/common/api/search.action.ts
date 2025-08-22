import { apiClient } from "./apiClient";
import { ISearchFilters, ISearchResult } from "@/definitions/types";

export interface ISearchResponse {
  success: boolean;
  data: ISearchResult[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    hasNext: boolean;
  };
}

export interface ISearchOptionsResponse {
  success: boolean;
  data: {
    types: Array<{ value: string; label: string }>;
    eventStatus: Array<{ value: string; label: string }>;
    eventType: Array<{ value: string; label: string }>;
  };
}

export interface ISuggestionsResponse {
  success: boolean;
  data: string[];
}

/**
 * Perform a search across events, users, and tags
 */
export const search = async (
  query: string,
  filters?: ISearchFilters,
  page: number = 1,
  limit: number = 20
): Promise<ISearchResponse> => {
  const params = new URLSearchParams({
    query,
    page: page.toString(),
    limit: limit.toString(),
  });

  if (filters) {
    if (filters.types?.length) {
      filters.types.forEach(type => params.append('filters[types][]', type));
    }
    if (filters.eventStatus?.length) {
      filters.eventStatus.forEach(status => params.append('filters[eventStatus][]', status));
    }
    if (filters.eventType?.length) {
      filters.eventType.forEach(type => params.append('filters[eventType][]', type));
    }
    if (filters.dateRange) {
      params.append('filters[dateRange][start]', filters.dateRange.start.toISOString());
      params.append('filters[dateRange][end]', filters.dateRange.end.toISOString());
    }
    if (filters.location) {
      params.append('filters[location][latitude]', filters.location.latitude.toString());
      params.append('filters[location][longitude]', filters.location.longitude.toString());
      params.append('filters[location][radius]', filters.location.radius.toString());
    }
    if (filters.tags?.length) {
      filters.tags.forEach(tag => params.append('filters[tags][]', tag));
    }
  }

  const response = await apiClient.get(`/search?${params.toString()}`);
  return response.data;
};

/**
 * Get search suggestions
 */
export const getSearchSuggestions = async (
  query: string,
  limit: number = 5
): Promise<ISuggestionsResponse> => {
  const params = new URLSearchParams({
    query,
    limit: limit.toString(),
  });

  const response = await apiClient.get(`/search/suggestions?${params.toString()}`);
  return response.data;
};

/**
 * Get search options and filters
 */
export const getSearchOptions = async (): Promise<ISearchOptionsResponse> => {
  const response = await apiClient.get('/search/options');
  return response.data;
};