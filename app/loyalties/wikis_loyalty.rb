class WikisLoyalty < ApplicationLoyalty
  def user_level
    record.wiki_maintainers.find_by(user_id: user.id)&.level || 0
  end
  
  def edit?
    user_level >= 3
  end

  def update?
    edit?
  end
end
