module Globalize
  module Model
  
    class MigrationError < StandardError; end
    class UntranslatedMigrationField < MigrationError; end
    class MigrationMissingTranslatedField < MigrationError; end
    class BadMigrationFieldType < MigrationError; end
  
    module ActiveRecord
      module Translated
        def self.included(base)
          base.extend ActMethods
        end

        module ActMethods
          def translates(*attr_names)
            options = attr_names.extract_options!
            options[:translated_attributes] = attr_names

            # Only set up once per class
            unless included_modules.include? InstanceMethods
              class_inheritable_accessor :globalize_options, :globalize_proxy
              
              include InstanceMethods
              extend  ClassMethods
              
              self.globalize_proxy = Globalize::Model::ActiveRecord.create_proxy_class(self)
              has_many(
                :globalize_translations,
                :class_name   => globalize_proxy.name,
                :extend       => Extensions,
                :dependent    => :delete_all,
                :foreign_key  => class_name.foreign_key
              )

              after_save :update_globalize_record              
            end

            self.globalize_options = options
            Globalize::Model::ActiveRecord.define_accessors(self, attr_names)
            
            # Import any callbacks that have been defined by extensions to Globalize2
            # and run them.
            extend Callbacks
            Callbacks.instance_methods.each {|cb| send cb }
          end

          def locale=(locale)
            @@locale = locale
          end
          
          def locale
            (defined?(@@locale) && @@locale) || I18n.locale
          end          
        end

        # Dummy Callbacks module. Extensions to Globalize2 can insert methods into here
        # and they'll be called at the end of the translates class method.
        module Callbacks
        end
        
        # Extension to the has_many :globalize_translations association
        module Extensions
          def by_locales(locales)
            find :all, :conditions => { :locale => locales.map(&:to_s) }
          end
        end
        
        module ClassMethods          
          def method_missing(method, *args)
            if method.to_s =~ /^find_by_(\w+)$/ && globalize_options[:translated_attributes].include?($1.to_sym)
              find(:first, :joins => :globalize_translations,
                   :conditions => [ "#{i18n_attr($1)} = ? AND #{i18n_attr('locale')} IN (?)",
                                   args.first,I18n.fallbacks[I18n.locale].map{|tag| tag.to_s}])
            else
              super
            end
          end
                    
          def create_translation_table!
            translated_fields = self.globalize_options[:translated_attributes]
            translation_table_name = self.name.underscore + '_translations'
            
            self.connection.create_table(translation_table_name) do |t|
              t.references self.table_name.singularize
              t.string :locale
              translated_fields.each do |name|
                t.column name, self.columns_hash[name.to_s].type
              end
              t.timestamps              
            end
            
            self.connection.add_index translation_table_name, [:locale,"#{self.table_name.singularize}_id"]
            
            for item in self.all
              (I18n.available_locales - [:root]).each do |l|
                I18n.locale = l.to_s
                translated_fields.each do |k|
                  eval("item.#{k.to_s} = item[:#{k.to_s}]")
                end
                item.save
              end
            end
            
            translated_fields.each do |name|
              self.connection.remove_column self.table_name, name
            end
            
          end

          def drop_translation_table!
            translation_table_name = self.name.underscore + '_translations'
            self.connection.drop_table translation_table_name
          end
          
          private
          
          def i18n_attr(attribute_name)
            self.base_class.name.underscore + "_translations.#{attribute_name}"
          end          
        end
        
        module InstanceMethods
          def reload(options = nil)
            globalize.clear
            
            # clear all globalized attributes
            # TODO what's the best way to handle this?
            self.class.globalize_options[:translated_attributes].each do |attr|
              @attributes.delete attr.to_s
            end
            
            super options
          end
          
          def globalize
            @globalize ||= Adapter.new self
          end
          
          def update_globalize_record
            globalize.update_translations!
          end
          
          def translated_locales
            globalize_translations.scoped(:select => 'DISTINCT locale').map {|gt| gt.locale.to_sym }
          end
          
          def set_translations options
            options.keys.each do |key|

              translation = globalize_translations.find_by_locale(key.to_s) ||
                globalize_translations.build(:locale => key.to_s)
              translation.update_attributes!(options[key])
            end
          end
          
        end
      end
    end
  end
end