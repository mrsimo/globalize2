module Globalize
  module Model
    module ActiveRecord
      module Relations
        def self.included(base)
          base.extend ActMethods
        end
        
        module ActMethods
          def translated_belongs_to(element)
            globalize_proxy.module_eval do
              belongs_to element
            end
            define_method "#{element}" do
              id = send("#{element.to_s}_id")
              id.nil? ? nil : Image.find(id)
            end
            define_method "#{element}=" do |item|
              send("#{element.to_s}_id=",item.id)
              save
            end
          end
        end
        
      end
    end
  end
end