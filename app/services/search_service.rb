# frozen_string_literal: true

class SearchService < BaseService
  attr_accessor :query, :account

  def call(query, limit, resolve = false, account = nil)
    @query   = query
    @account = account

    default_results.tap do |results|
      if url_query?
        results.merge!(url_resource_results) unless url_resource.nil?
      elsif query.present?
        results[:accounts] = AccountSearchService.new.call(query, limit, account, resolve: resolve)
        results[:statuses] = StatusesIndex.filter(term: { searchable_by: account.id }).query(query_string: { default_field: 'text', query: query }).limit(limit).objects if full_text_searchable?
        results[:hashtags] = Tag.search_for(query.gsub(/\A#/, ''), limit) unless query.start_with?('@')
      end
    end
  end

  def default_results
    { accounts: [], hashtags: [], statuses: [] }
  end

  def url_query?
    query =~ /\Ahttps?:\/\//
  end

  def url_resource_results
    { url_resource_symbol => [url_resource] }
  end

  def url_resource
    @_url_resource ||= ResolveURLService.new.call(query)
  end

  def url_resource_symbol
    url_resource.class.name.downcase.pluralize.to_sym
  end

  def full_text_searchable?
    !account.nil? && !(query.start_with?('#') || query.include?('@'))
  end
end
