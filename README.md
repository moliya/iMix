# iMix
代码混淆的Demo

##### 简介
基于[KLGenerateSpamCode](https://github.com/klaus01/KLGenerateSpamCode)的代码实现混淆

利用fastlane脚本实现自动调用混淆代码并对图片及垃圾代码等进行处理

##### 使用
Note: 使用前请先安装fastlane

1. clone代码到本地，比如用户目录下
2. 修改`~/iMix/fastlane/`目录下的`Fastfile`文件，根据注释配置指定的混淆处理
3. 打开终端，cd到iMix文件目录下，执行`fastlane mix`即可
4. 后续根据提示决定是否手动导入垃圾代码的操作

app_faker参数说明：
```
proj_dir #必填，需要混淆的Xcode项目文件路径，即xxx.xcodeproj文件的绝对路径

exec_dir #选填，混淆脚本的文件路径，通常不用配置

proj_old_name #选填，原项目名，不设置时，脚本会自动配置项目名

proj_new_name #选填，重命名的项目名

class_old_prefix #选填，原类名前缀，脚本会替换含有该类名前缀的类文件，如果类名前缀不匹配则不会处理

class_new_prefix #选填，需要替换的新类名前缀

spam_code_dir #选填，垃圾代码输出的文件夹路径，不配置则会保存在iMix/spam目录下，需要手动将文件导入项目中，如果配置了路径，脚本会自动将垃圾代码文件导入项目的指定路径下

spam_code_str #选填，插入的垃圾代码字符串

ignore_dir #选填，忽略处理的文件夹名，多个路径可用 , 分隔

handle_xassets #选填，是否处理图片名称及hash
```
