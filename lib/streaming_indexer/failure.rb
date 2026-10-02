# frozen_string_literal: true

module StreamingIndexer
  Failure = Data.define(:event, :stage, :error, :id, :attempts) do
    def initialize(event:, stage:, error:, id: nil, attempts: 1)
      super
    end
  end
end
