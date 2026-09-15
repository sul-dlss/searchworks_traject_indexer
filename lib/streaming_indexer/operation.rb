# frozen_string_literal: true

module StreamingIndexer
  # A fully mapped Solr operation. Keeping the SourceEvent attached allows
  # failures and metrics to retain their Kafka position without logging data.
  class Operation
    attr_reader :action, :id, :document, :event

    def self.add(id:, document:, event:)
      new(action: :add, id:, document:, event:)
    end

    def self.delete(id:, event:)
      new(action: :delete, id:, document: nil, event:)
    end

    def initialize(action:, id:, document:, event:)
      @action = action.to_sym
      @id = id
      @document = document
      @event = event
    end

    def add?
      action == :add
    end

    def delete?
      action == :delete
    end
  end
end
