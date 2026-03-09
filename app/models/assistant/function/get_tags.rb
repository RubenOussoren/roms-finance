class Assistant::Function::GetTags < Assistant::Function
  class << self
    def name
      "get_tags"
    end

    def description
      "Get all of the user's tags with usage counts."
    end
  end

  def call(params = {})
    tags = family.tags.left_joins(:taggings).group(:id).select("tags.*, COUNT(taggings.id) AS usage_count")

    {
      tags: tags.map { |tag|
        { name: tag.name, usage_count: tag.usage_count }
      }
    }
  end
end
