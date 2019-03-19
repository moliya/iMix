require 'xcodeproj'

module Fastlane
  module Actions
    module SharedValues
      APP_FAKER_CUSTOM_VALUE = :APP_FAKER_CUSTOM_VALUE
    end
    
    class AppFakerAction < Action
      def self.run(params)
        # 脚本路径
        exec_dir = params[:exec_dir]
        # 项目路径
        proj_dir = params[:proj_dir]
        # 原项目名
        old_name = params[:proj_old_name]
        # 新项目名
        new_name = params[:proj_new_name]
        # 当前项目名
        cur_name = nil
        # 原类名前缀
        old_prefix = params[:class_old_prefix]
        # 新类名前缀
        new_prefix = params[:class_new_prefix]
        # spam输出文件路径
        spam_dir = params[:spam_code_dir]
        # spam代码字符串
        spam_str = params[:spam_code_str]
        # 忽略的文件夹名集合
        ignores = params[:ignore_dir]
        # 是否处理图片资源
        is_handle = params[:handle_xassets]

        # 检查脚本文件的路径
        if !exec_dir || !exec_dir.empty?
          # 默认存放脚本文件的路径
          tmp_dir = File.dirname(__FILE__).gsub(/\/fastlane\/actions\Z/, "\/exec\/")
          if File::directory?(tmp_dir)
            Dir::entries(tmp_dir).each do |file|
              if File::file?(tmp_dir + file)
                exec_dir = tmp_dir + file
              end
            end
          end
        end
        
        # 项目根路径
        root_dir = /(.+)\/[a-zA-Z0-9_-]+\.xcodeproj/.match(proj_dir)[1]

        # 待执行的命令
        cmd = "#{exec_dir} #{root_dir}"

        #原项目名
        regex = /([a-zA-Z0-9_-]+)\.xcodeproj/
          if !old_name || old_name.empty?
            regex.match(proj_dir)
            old_name = $1
            cur_name = old_name
          end

        if !exec_dir || exec_dir.empty?
          UI.user_error!("No exec dir for AppFakerAction given, pass using `exec_dir: 'xxx'`")
          return
        end

        #删除垃圾代码文件夹下可能存在的无用的垃圾代码文件
        if !spam_dir.empty?
          UI.message("清理垃圾代码中...")
          #使用xcodeproj库打开工程文件
          project = Xcodeproj::Project.open(proj_dir)
          if project
            target = project.targets.first
            #查找group，即存放垃圾代码的文件夹
            group = project.main_group.find_subpath(File.join(cur_name, spam_dir),false)
            #source_tree 代表 The directory to which the path is relative
            #pbxproj文件中都是<group>
            group.set_source_tree('<group>')
            
            codes = []
            group.files.each do |file|
              if file.path.to_s.end_with?(".h")
                codes.push("\#import \"#{file.path}\"\n")
              end
            end
            #删除对垃圾文件的引用代码
            removeImportCodesRecursively(codes, project.main_group)
            #删除旧的垃圾文件
            removeBuildPhaseFilesRecursively(target, group)
            group.clear()
            #把Frameworks下的Pods_xxx.framework删除
            removePodsFramework(target, project.frameworks_group)
            #保存
            project.save
          end
        end

        # 修改项目名
        if new_name && !new_name.empty?
          if old_name && !old_name.empty?
            UI.message("替换项目名中...")
            arg = " -modifyProjectName \'#{old_name}>#{new_name}\'"
            tmp = "#{cmd} #{new_name}#{arg}"
            tmp = cmd + '/' + old_name + ' ' + arg
            Actions.sh(tmp)

            # 项目名替换后，需要更新项目路径
            proj_dir.gsub!(regex, "#{new_name}.xcodeproj")
            cur_name = new_name
          end
        end


        # 修改类名前缀
        if old_prefix && !old_prefix.empty? && new_prefix && !new_prefix.empty?
          UI.message("替换类名前缀中...")
          arg = " -modifyClassNamePrefix #{proj_dir} \'#{old_prefix}>#{new_prefix}\'"
          if ignores && !ignores.empty?
            arg += " -ignoreDirNames \'#{ignores}\'"
          end
          Actions.sh(cmd + arg)
        end

        # 如果根目录下有Podfile文件，则更新pod
        if File::exist?(File.join(root_dir, 'Podfile'))
          UI.message("pod install...")
          Actions.sh("pod install --project-directory=#{root_dir}")
        end

        # 处理图片资源
        if is_handle
          UI.message("处理图片资源中...")
          # 找到xcassets文件夹
          assets_dir = ''
          dir1 = File.join(root_dir, 'Assets.xcassets')
          dir2 = File.join(root_dir, cur_name, 'Assets.xcassets')
          if File::exist?(dir1)
            assets_dir = dir1
          elsif File::exist?(dir2)
            assets_dir = dir2
          end

          if assets_dir.empty?
            # 没有找到xcassets文件夹，则以项目根路径作为处理
            assets_dir = ''
          end

          # 重命名图片文件
          arg = " -handleXcassets"
          Actions.sh(exec_dir + " " + assets_dir + arg)

          # 压缩图片
          Actions.sh('find ' + assets_dir + ' -iname "*.png" -exec echo {} \; -exec convert {} {} \;')
        end

        # 生成混淆文件
        if spam_str && !spam_str.empty?
          if !spam_dir
            # 默认混淆文件的路径
            spam_dir = File.dirname(__FILE__).gsub(/\/fastlane\/actions\Z/, "\/spam\/")
            # 文件夹是否存在
            if !File::exist?(spam_dir)
              # 创建文件夹
              Dir::mkdir(spam_dir)
            end
            # 删除文件夹下可能存在的文件
            Dir::entries(spam_dir).each do |file|
              if File::file?(spam_dir + file)
                File::delete(spam_dir + file)
              end
            end
          end

          UI.message("生成混淆文件中...")
          arg = ' -spamCodeOut ' + File.join(root_dir, cur_name, spam_dir) + " \'#{spam_str}\'"
          if ignores && !ignores.empty?
            arg += " -ignoreDirNames \'#{ignores}\'"
          end
          tmp = cmd + '/' + cur_name + ' ' + arg
          Actions.sh(tmp)

          #添加引用内容
          project = Xcodeproj::Project.open(proj_dir)
          if project
            target = project.targets.first
            #查找group，即存放垃圾代码的文件夹
            group = project.main_group.find_subpath(File.join(cur_name, spam_dir),true)
            #添加引用
            addFilesToGroup(project, target, group)
            #保存
            project.save
          end
        end

        #任务完成
        UI.success("任务完成🎯🎯🎯")
        if spam_str && !spam_str.empty?
          if !spam_dir
            UI.important("📌垃圾代码文件保存在spam目录下，请手动导入项目中！")
          end
          UI.important("📌头文件引用代码保存在importHeaders.h中，请自行决定引用方式")
        end
      end

      #删除文件中的引用代码
      def self.removeImportCodesRecursively(codes, group)
        group.files.each do |file|
          if !File::exist?(file.real_path)
            next
          end
          if !file.path.to_s.end_with?(".h", ".m", ".mm", ".cpp")
            next
          end
          File.open(file.real_path, 'r:utf-8') do |lines|
            buffer = lines.read
            codes.each do |code|
              buffer = buffer.gsub(code, '')
            end
            File.open(file.real_path, 'w') do |f|
              f.write(buffer)
            end
          end
        end

        group.groups.each do |subGroup|
          removeImportCodesRecursively(codes, subGroup)
        end
      end

      #删除文件及build引用
      def self.removeBuildPhaseFilesRecursively(target, group)
        group.files.each do |file|
          #删除项目引用
          if file.real_path.to_s.end_with?(".m", ".mm", ".cpp")
            target.source_build_phase.remove_file_reference(file)
          elsif file.real_path.to_s.end_with?(".plist")
            target.resources_build_phase.remove_file_reference(file)
          end
          #删除文件
          File::delete(file.real_path)
        end
  
        group.groups.each do |sub_group|
          removeBuildPhaseFilesRecursively(target, sub_group)
        end
      end

      #删除Pod生成的Pods_xxx.framework
      def self.removePodsFramework(target, group)
        group.files.each do |file|
          #只删除符合条件的文件
          file_name = file.path.to_s
          if file_name.start_with?("Pods_") && file_name.end_with?(".framework")
            #删除framework引用
            target.frameworks_build_phase.remove_file_reference(file)
            #如果不调用remove_from_project，pbxproj文件中会残留两个Pods_xxx.framework相关的引用代码
            file.remove_from_project
          end
        end
      end

      #添加文件引用
      def self.addFilesToGroup(project, aTarget, aGroup)
        Dir.foreach(aGroup.real_path) do |entry|
          filePath = File.join(aGroup.real_path, entry)

          # 过滤目录和.DS_Store文件
          if !File.directory?(filePath) && entry != ".DS_Store" then
            # 向group中增加文件引用
            fileReference = aGroup.new_reference(filePath)
            # 如果不是头文件则继续增加到Build Phase中，PB文件需要加编译标志
            if filePath.to_s.end_with?("pbobjc.m", "pbobjc.mm") then
              aTarget.add_file_references([fileReference], '-fno-objc-arc')
            elsif filePath.to_s.end_with?(".m", ".mm", ".cpp") then
              aTarget.source_build_phase.add_file_reference(fileReference, true)
            elsif filePath.to_s.end_with?(".plist") then
              aTarget.resources_build_phase.add_file_reference(fileReference, true)
            end
          # 目录情况下, 递归添加
          elsif File.directory?(filePath) && entry != '.' && entry != '..' then
            hierarchy_path = aGroup.hierarchy_path[1, aGroup.hierarchy_path.length] 
            subGroup = project.main_group.find_subpath(hierarchy_path + '/' + entry, true)
            subGroup.set_source_tree(aGroup.source_tree)
            subGroup.set_path(aGroup.real_path + entry)
            addFilesToGroup(project, aTarget, subGroup)
          end
        end
      end

      def self.description
        "快捷执行代码混淆命令的action"
      end

      def self.authors
        ["Carefree"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "You can use this action to do cool things..."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :proj_dir,
                                       description: "Xcode项目文件路径，即xxx.xcodeproj文件的绝对路径",
                                       verify_block: proc do |value|
                                          UI.user_error!("No Xcode project dir for AppFakerAction given, pass using `proj_dir: 'xxx.xcodeproj'`") unless (value and not value.empty?)
                                          # UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :exec_dir,
                                       description: "混淆脚本的文件路径",
                                       optional:true,# 选填
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :proj_old_name,
                                       description: "原项目名",
                                       optional:true,# 选填
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :proj_new_name,
                                       description: "重命名的项目名",
                                       optional:true,# 选填
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :class_old_prefix,
                                       description: "原类名前缀",
                                       optional:true,# 选填
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :class_new_prefix,
                                       description: "新类名前缀",
                                       optional:true,# 选填
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :spam_code_dir,
                                       description: "垃圾代码输出的文件夹路径",
                                       optional:true,# 选填
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :spam_code_str,
                                       description: "插入的垃圾代码字符串",
                                       optional:true,# 选填
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :ignore_dir,
                                       description: "忽略处理的文件夹名，多个路径可用 `,` 分隔",
                                       optional:true,# 选填
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :handle_xassets,
                                       description: "是否处理图片名称及hash",
                                       optional:true,# 选填
                                       is_string: false),
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        
        platform == :ios
      end
    end
  end
end
