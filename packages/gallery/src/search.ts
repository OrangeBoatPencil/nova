import { SupabaseClient } from '@supabase/supabase-js';

export interface SearchOptions {
  query: string;
  limit?: number;
  offset?: number;
  filters?: Record<string, unknown>;
}

/**
 * Search for files using Postgres full-text search
 * @param supabase Supabase client
 * @param table Table name to search in
 * @param searchColumns Columns to search for matches
 * @param options Search options
 */
export const searchFiles = async (
  supabase: SupabaseClient,
  table: string,
  searchColumns: string[],
  options: SearchOptions
) => {
  const { query, limit = 20, offset = 0, filters = {} } = options;

  // Create search query using vector column or search columns
  let queryBuilder = supabase
    .from(table)
    .select('*');

  // Add full-text search
  if (query && query.trim() !== '') {
    // If there's a search column, use it
    if (searchColumns.length > 0) {
      // Create a ILIKE query for each column
      const searchQuery = searchColumns.map(column => {
        return `${column}.ilike.%${query}%`;
      }).join(',');
      
      queryBuilder = queryBuilder.or(searchQuery);
    }
  }

  // Apply filters
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== null) {
      queryBuilder = queryBuilder.eq(key, value);
    }
  });

  // Apply pagination
  queryBuilder = queryBuilder
    .range(offset, offset + limit - 1)
    .order('created_at', { ascending: false });

  const { data, error, count } = await queryBuilder;

  if (error) {
    throw error;
  }

  return {
    data,
    count,
    limit,
    offset,
    hasMore: (count || 0) > offset + limit
  };
}; 