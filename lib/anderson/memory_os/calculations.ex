defmodule Anderson.MemoryOS.Calculations do
  @moduledoc """
  Utility module for MemoryOS calculations.

  Contains implementations for similarity metrics and other utility calculations
  used across the MemoryOS resources.
  """

  @doc """
  Calculate Jaccard similarity between two sets of keywords.

  Jaccard similarity is defined as the size of the intersection divided by the size of the union.

  ## Parameters
  - segment: The segment with keywords attribute
  - context: Context map containing query_keywords

  ## Returns
  - Float: Jaccard similarity score between 0.0 and 1.0
  """
  def jaccard_similarity(segment, context) do
    segment_keywords = MapSet.new(segment.keywords)
    query_keywords = MapSet.new(context.query_keywords)

    intersection = MapSet.intersection(segment_keywords, query_keywords)
    union = MapSet.union(segment_keywords, query_keywords)

    intersection_size = MapSet.size(intersection)
    union_size = MapSet.size(union)

    if union_size == 0 do
      0.0
    else
      intersection_size / union_size
    end
  end

  @doc """
  Placeholder calculation that returns 0.0.

  Used as a temporary implementation for calculations that will be properly implemented later.
  """
  def placeholder_calculation(_resource, _context) do
    0.0
  end
end
