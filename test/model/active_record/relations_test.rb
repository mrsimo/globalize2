require File.join( File.dirname(__FILE__), '..', '..', 'test_helper' )
require 'active_record'
require 'globalize/model/active_record'
require 'ruby-debug'

# Hook up model translation
ActiveRecord::Base.send(:include, Globalize::Model::ActiveRecord::Translated)
ActiveRecord::Base.send(:include, Globalize::Model::ActiveRecord::Relations)

# Load Post model
require File.join( File.dirname(__FILE__), '..', '..', 'data', 'banner' )

class RelationsTest < ActiveSupport::TestCase
  def setup
    I18n.locale = :'en-US'
    I18n.fallbacks.clear 
    reset_db! File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'data', 'schema.rb'))
    ActiveRecord::Base.locale = nil
  end
  
  def teardown
    I18n.fallbacks.clear 
  end
  
  # Translating integer fields is possible
  test "can create an object with a translatable integer field" do
    banner = Banner.create :name => "normal", :image_id => 1
    assert_equal banner.globalize_translations.map(&:image_id), [1]
  end
  
  test "the attribute has different values for different locales" do
    banner = Banner.create :name => "normal", :image_id => 1
    I18n.locale = :"ca-ES"
    banner.image_id = 2
    banner.save
    assert banner.globalize_translations.map(&:image_id).include?(1)
    assert banner.globalize_translations.map(&:image_id).include?(2)
    assert_equal banner.image_id , 2
    I18n.locale = :'en-US'
    assert_equal banner.image_id , 1
  end
  
  # Can haz translated_belongs_to
  test "translated_belongs_to helps use the localized integer to relate different objects according to the locale" do
    banner = Banner.create :name => "test subject"
    image_es = Image.create :name => "spanish"
    image_en = Image.create :name => "english"
    banner.image_id = image_en.id
    banner.save
    assert_equal image_en, banner.image
    I18n.locale = :'es-ES'    
    banner.image_id = image_es.id
    banner.save
    assert_equal image_es, banner.image
    I18n.locale = :'ca-ES'
    assert_nil banner.image
  end
  
  test "uses fallbacks as usual" do
    I18n.fallbacks.map 'de-DE' => [ 'en-US' ]
    banner = Banner.create :name => "test subject"
    image_en = Image.create :name => "english"
    banner.image_id = image_en.id
    I18n.locale = :'de-DE'
    assert_equal image_en, banner.image
  end
  
  test "can assign objects through the relation" do
    banner = Banner.create :name => "test subject"
    banner.image = Image.create :name => "i'm the one"
    banner.save
    assert_equal "i'm the one", banner.image.name
  end
  
end