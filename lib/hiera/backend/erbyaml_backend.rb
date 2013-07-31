class Hiera
  module Backend
    class Erbyaml_backend
      def initialize(cache=nil)
        require 'yaml'
        Hiera.debug("Hiera ERB YAML backend starting")

        @cache = cache || Filecache.new
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up #{key} in ERB YAML backend")

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")
          yamlfile = Backend.datafile(:yaml, scope, source, "yaml") || next

          next unless File.exist?(yamlfile)

          data = @cache.read(yamlfile, Hash, {}) do |data|
            YAML.load(data)
          end

          next if data.empty?
          next unless data.include?(key)

          # Extra logging that we found the key. This can be outputted
          # multiple times if the resolution type is array or hash but that
          # should be expected as the logging will then tell the user ALL the
          # places where the key is found.
          Hiera.debug("Found #{key} in #{source}")

          # for array resolution we just append to the array whatever
          # we find, we then goes onto the next file and keep adding to
          # the array
          #
          # for priority searches we break after the first found data item
          new_answer = Backend.parse_answer(data[key], scope)
          case resolution_type
          when :array
            raise Exception, "Hiera type mismatch: expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
            answer ||= []
            answer << new_answer
          when :hash
            raise Exception, "Hiera type mismatch: expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
            answer ||= {}
            answer = Backend.merge_answer(new_answer,answer)
          else
            answer = new_answer
            break
          end
        end

        # Call the erb_parsing function which does the actual parsing
        # This function will loop over all values in case of array or hash
        return erb_parsing(scope, answer)
      end

      def stale?(yamlfile)
        # NOTE: The mtime change in a file MUST be > 1 second before being
        #       recognized as stale. File mtime changes within 1 second will
        #       not be recognized.
        stat    = File.stat(yamlfile)
        current = { 'inode' => stat.ino, 'mtime' => stat.mtime, 'size' => stat.size }
        return false if @cache[yamlfile] == current

        @cache[yamlfile] = current
        return true
      end

      def erb_parsing(scope, question)
        if scope.class == Puppet::DataBinding::Variables
          class << scope
            def get_scope
              @variable_bindings
            end
          end
          scope = scope.get_scope
        elsif scope.class.to_s == 'Hiera::Scope'
          class << scope
            def get_scope
              @real
            end
          end
          scope = scope.get_scope
        end

        if not question.nil?
          case question
          when Array
            answer = question.collect { |x| x = erb_parsing(scope, x)  }
          when Hash
            answer = question.inject({}) { |h, (k, v)| h[k] = erb_parsing(scope, v); h }
          when String 
            if ! question.include?('<%')
              answer = question
            else
              begin
                wrapper = Puppet::Parser::TemplateWrapper.new(scope)
                answer = wrapper.result("#{question}")
              rescue => detail
                raise Puppet::ParseError,
                  "Failed to parse inline template (#{question}): #{detail}"
              end
            end
          else
            answer = question.to_s
          end
          return answer
        end
        return nil
      end

    end
  end
end
