class Banner < ActiveRecord::Base
  translates :image_id
  translated_belongs_to :image
end

class Image < ActiveRecord::Base
end