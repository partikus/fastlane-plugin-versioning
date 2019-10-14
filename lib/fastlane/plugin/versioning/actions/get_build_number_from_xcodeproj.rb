module Fastlane
    module Actions
      class GetBuildNumberFromXcodeprojAction < Action
        require 'xcodeproj'
        require 'pathname'
  
        def self.run(params)
          unless params[:xcodeproj]
            if Helper.test?
              params[:xcodeproj] = "/tmp/fastlane/tests/fastlane/xcodeproj/versioning_fixture_project.xcodeproj"
            else
              params[:xcodeproj] = Dir["*.xcodeproj"][0] unless params[:xcodeproj]
            end
          end
  
          if params[:target]
            build_number = get_build_number_using_target(params)
          else
            build_number = get_build_number_using_scheme(params)
          end

          Actions.lane_context[SharedValues::BUILD_NUMBER] = build_number #TODO: compared to ths plist getter, this is a slightly different meaning. BUILD_NUMBER is like <major>.<minor>.<patch>.<build> as opposed to <build>
          build_number
        end
  
        def self.get_build_number_using_target(params)
          project = Xcodeproj::Project.open(params[:xcodeproj])
          if params[:target]
            target = project.targets.detect { |t| t.name == params[:target] }
          else
            # firstly we are trying to find modern application target
            target = project.targets.detect do |t|
              t.kind_of?(Xcodeproj::Project::Object::PBXNativeTarget) &&
                t.product_type == 'com.apple.product-type.application'
            end
            target = project.targets[0] if target.nil?
          end

          build_number = target.resolved_build_setting('CURRENT_PROJECT_VERSION', true)
          UI.user_error! 'Cannot resolve build number build setting.' if build_number.nil? || build_number.empty? #TODO: come back to this message
  
          if !(build_configuration_name = params[:build_configuration_name]).nil?
            build_number = build_number[build_configuration_name]
            UI.user_error! "Cannot resolve CURRENT_PROJECT_VERSION build setting for #{build_configuration_name}." if plist.nil?
          else
            build_number = build_number.values.compact.uniq
            UI.user_error! 'Cannot accurately resolve CURRENT_PROJECT_VERSION build setting, try specifying :build_configuration_name.' if build_number.count > 1
            build_number = build_number.first
          end

          build_number
        end
  
        def self.get_build_number_using_scheme(params)
          config = { project: params[:xcodeproj], scheme: params[:scheme], configuration: params[:build_configuration_name] }
          project = FastlaneCore::Project.new(config)
          project.select_scheme
  
          build_number = project.build_settings(key: 'CURRENT_PROJECT_VERSION')
          #TODO: USER_ERROR message same as in line 38?
          build_number
        end
  
        #####################################################
        # @!group Documentation
        #####################################################
  
        def self.description
          "Get the version number of your project"
        end
  
        def self.details
          'TODO:'
        end
  
        def self.available_options
          [
            FastlaneCore::ConfigItem.new(key: :xcodeproj,
                                         env_name: "FL_BUILD_NUMBER_PROJECT",
                                         description: "Optional, you must specify the path to your main Xcode project if it is not in the project root directory or if you have multiple *.xcodeproj's in the root directory",
                                         optional: true,
                                         verify_block: proc do |value|
                                           UI.user_error!("Please pass the path to the project, not the workspace") if value.end_with? ".xcworkspace"
                                           UI.user_error!("Could not find Xcode project at path '#{File.expand_path(value)}'") if !File.exist?(value) and !Helper.is_test?
                                         end),
            FastlaneCore::ConfigItem.new(key: :target,
                                         env_name: "FL_BUILD_NUMBER_TARGET",
                                         optional: true,
                                         conflicting_options: [:scheme],
                                         description: "Specify a specific target if you have multiple per project, optional"),
            FastlaneCore::ConfigItem.new(key: :scheme,
                                         env_name: "FL_BUILD_NUMBER_SCHEME",
                                         optional: true,
                                         conflicting_options: [:target],
                                         description: "Specify a specific scheme if you have multiple per project, optional"),
            FastlaneCore::ConfigItem.new(key: :build_configuration_name,
                                         optional: true,
                                         description: "Specify a specific build configuration if you have different build settings for each configuration")
  
          ]
        end
  
        def self.authors
          ["jdouglas-nz"]
        end
  
        def self.is_supported?(platform)
          [:ios, :mac].include? platform
        end
      end
    end
  end
  