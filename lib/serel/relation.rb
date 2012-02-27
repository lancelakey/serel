module Serel
  class Relation
    attr_reader :type, :klass, :qty

    def initialize(type, qty)
      @type = type
      @klass = find_constant(type)
      @scope = {
        api_key: Serel::Base.api_key,
        site: Serel::Base.site
      }
      @qty = qty
    end

    # Public: Merges two relation objects together. This is used in our awesome
    #         new scoping engine!
    #
    # relation - A Serel::Relation object with the same base class as the
    #            current relation
    #
    # Returns self
    def merge(relation)
      if relation.instance_variable_get(:@type) != @type
        raise ArgumentError, 'You cannot merge two relation objects based on different classes'
      end
      @scope.merge!(relation.scoping)
    end

    # Scoping returns our internal scope defition. Things like url etc.
    def scoping
      @scope
    end

    def new_relation
      self
    end

    def method_missing(sym, *attrs, &block)
      # If the base relation class responds to the method, call
      # it and merge in the resulting relation scope
      if @klass.respond_to?(sym)
        relation = @klass.send(sym, *attrs, &block)
        merge(relation)
        self
      end
      super(sym, *attrs, &block)
    end

    #
    #
    #
    # Scope methods
    def pagesize(limit)
      @scope[:pagesize] = limit
      self
    end

    def sort(by)
      @scope[:by] = by.to_s
      self
    end
    
    def url(url)
      @scope[:url] = url
      self
    end

    def page(number)
      @scope[:page] = number
      self
    end

    def filter(filter)
      @scope[:filter] = filter.to_s
      self
    end

    #
    #
    #
    # Finder methods
    def all
      if klass.respond_to?(:all)
        all_helper(1)
      else
        raise NoMethodError
      end
    end

    def find(id)
      if klass.respond_to?(:find)
        url("#{@type}s/#{id}").request
      else
        raise NoMethodError
      end
    end

    def get
      if klass.respond_to?(:get)
        url("#{@type}s").request
      else
        raise NoMethodError
      end
    end

    # Request stuff
    def request
      Serel::Request.new(@type, scoping, @qty).execute
    end

    private

    def all_helper(page)
      response = page(page).pagesize(100).url("#{@type}s").request
      # TODO: find a query that triggers backoff.
      # if response.backoff
      #   Serel::Base.warn response.backoff
      # end
      if response.has_more
        response.concat all_helper(page+1)
      end
      response
    end

    def build_options
      opt = {}
      opt[:sort] = @sort if @sort
      opt[:pagesize] = @per if @per
      opt[:type] = @type
      opt
    end
  end
end