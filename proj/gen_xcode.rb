#!/usr/bin/env ruby
$uuid_base = 0
def uuid; $uuid_base += 1; sprintf("C%011d%012d", $uuid_base, $uuid_base); end
$ids = {}
def id_for(name); $ids[name] ||= uuid; end

SOURCE_FILES = [
  "DesignSystem.swift", "ClaudeChatApp.swift",
  "Models/Message.swift", "Models/Conversation.swift", "Models/AppSettings.swift",
  "Services/ClaudeService.swift", "Services/ConversationStore.swift",
  "ViewModels/ChatViewModel.swift", "ViewModels/SidebarViewModel.swift",
  "Views/ContentView.swift",
  "Views/CenteredTextEditor.swift", "Views/SidebarView.swift", "Views/FileDropModifier.swift",
  "Views/MarkdownRenderer.swift", "Views/SettingsView.swift",
]

source_entries = SOURCE_FILES.map do |path|
  { path: path, name: File.basename(path), fileRef: id_for("FR_#{path}"), buildFile: id_for("BF_#{path}") }
end

# Icon
icon_file_id = id_for("FR_AppIcon")
icon_build_id = id_for("BF_AppIcon")

# Group IDs
main_group_id = id_for("G_main"); source_root_id = id_for("G_SourceRoot")
product_ref_id = id_for("PR_App"); product_group_id = id_for("G_Products")
models_group_id = id_for("G_Models"); services_group_id = id_for("G_Services")
viewmodels_group_id = id_for("G_ViewModels"); views_group_id = id_for("G_Views")
bp_src = id_for("BP_Sources"); bp_res = id_for("BP_Resources"); bp_fw = id_for("BP_Frameworks")
nt = id_for("NT_App"); proj = id_for("PROJ")
cl_proj = id_for("CL_PROJ"); cl_tgt = id_for("CL_TARGET")
dc_proj = id_for("DC_PROJ"); rc_proj = id_for("RC_PROJ")
dc_tgt = id_for("DC_TARGET"); rc_tgt = id_for("RC_TARGET")
info_plist_id = id_for("FR_Info.plist")
src_root = "Sources/ClaudeChat"

puts "// !$*UTF8*$!"
puts "{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {"
puts "/* Begin PBXBuildFile section */"
source_entries.each { |e| puts "\t\t#{e[:buildFile]} /* #{e[:name]} in Sources */ = {isa = PBXBuildFile; fileRef = #{e[:fileRef]}; };" }
puts "\t\t#{icon_build_id} /* AppIcon.icns in Resources */ = {isa = PBXBuildFile; fileRef = #{icon_file_id}; };"
puts "/* End PBXBuildFile section */"

puts "/* Begin PBXFileReference section */"
puts "\t\t#{info_plist_id} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; };"
puts "\t\t#{icon_file_id} /* AppIcon.icns */ = {isa = PBXFileReference; lastKnownFileType = image.icns; path = AppIcon.icns; sourceTree = SOURCE_ROOT; };"
puts "\t\t#{product_ref_id} /* App.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"见一面.app\"; sourceTree = BUILT_PRODUCTS_DIR; };"
source_entries.each { |e| ext = e[:name].end_with?(".swift") ? "sourcecode.swift" : "text"; puts "\t\t#{e[:fileRef]} /* #{e[:name]} */ = {isa = PBXFileReference; lastKnownFileType = #{ext}; path = #{e[:name]}; sourceTree = \"<group>\"; };" }
puts "/* End PBXFileReference section */"

puts "/* Begin PBXGroup section */"
puts "\t\t#{main_group_id} = { isa = PBXGroup; children = (#{source_root_id} /* #{src_root} */,#{icon_file_id} /* AppIcon.icns */,#{product_group_id} /* Products */,); sourceTree = \"<group>\"; };"
puts "\t\t#{source_root_id} = { isa = PBXGroup; children = ("
top_level = source_entries.select { |e| !e[:path].include?("/") }
top_level.each { |e| puts "\t\t\t\t#{e[:fileRef]} /* #{e[:name]} */," }
puts "\t\t\t\t#{models_group_id} /* Models */,#{services_group_id} /* Services */,#{viewmodels_group_id} /* ViewModels */,#{views_group_id} /* Views */,#{info_plist_id} /* Info.plist */,); path = #{src_root}; sourceTree = \"<group>\"; };"
[ [models_group_id,"Models","Models"], [services_group_id,"Services","Services"], [viewmodels_group_id,"ViewModels","ViewModels"] ].each do |gid,name,dir|
  entries = source_entries.select { |e| e[:path].start_with?("#{dir}/") && e[:path].split("/").count == 2 }
  puts "\t\t#{gid} = { isa = PBXGroup; children = (#{entries.map { |e| "#{e[:fileRef]} /* #{e[:name]} */" }.join(",")},); name = #{name}; path = #{dir}; sourceTree = \"<group>\"; };"
end
views_entries = source_entries.select { |e| e[:path].start_with?("Views/") }
puts "\t\t#{views_group_id} = { isa = PBXGroup; children = (#{views_entries.map { |e| "#{e[:fileRef]} /* #{e[:name]} */" }.join(",")},); name = Views; path = Views; sourceTree = \"<group>\"; };"
puts "\t\t#{product_group_id} = { isa = PBXGroup; children = (#{product_ref_id} /* App.app */,); name = Products; sourceTree = \"<group>\"; };"
puts "/* End PBXGroup section */"

puts "/* Begin PBXNativeTarget section */"
puts "\t\t#{nt} /* App */ = { isa = PBXNativeTarget; buildConfigurationList = #{cl_tgt}; buildPhases = (#{bp_src},#{bp_res},#{bp_fw},); buildRules = (); dependencies = (); name = \"见一面\"; productName = \"见一面\"; productReference = #{product_ref_id}; productType = \"com.apple.product-type.application\"; };"
puts "/* End PBXNativeTarget section */"

puts "/* Begin PBXProject section */"
puts "\t\t#{proj} /* Project object */ = { isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1500; LastUpgradeCheck = 1500; TargetAttributes = { #{nt} = { CreatedOnToolsVersion = 15.0; }; }; }; buildConfigurationList = #{cl_proj}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = #{main_group_id}; productRefGroup = #{product_group_id}; projectDirPath = \"\"; projectRoot = \"\"; targets = (#{nt},); };"
puts "/* End PBXProject section */"

puts "/* Begin PBXSourcesBuildPhase section */"
puts "\t\t#{bp_src} /* Sources */ = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ("
source_entries.each { |e| puts "\t\t\t\t#{e[:buildFile]} /* #{e[:name]} in Sources */," }
puts "\t\t\t); runOnlyForDeploymentPostprocessing = 0; };"
puts "/* End PBXSourcesBuildPhase section */"

puts "/* Begin PBXResourcesBuildPhase section */"
puts "\t\t#{bp_res} /* Resources */ = { isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (\n\t\t\t\t#{icon_build_id} /* AppIcon.icns in Resources */,\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; };"
puts "/* End PBXResourcesBuildPhase section */"

puts "/* Begin PBXFrameworksBuildPhase section */"
puts "\t\t#{bp_fw} /* Frameworks */ = { isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };"
puts "/* End PBXFrameworksBuildPhase section */"

puts "/* Begin XCBuildConfiguration section */"
[[dc_proj,"Debug","dwarf","0","DEBUG=1","-Onone","DEBUG \$(inherited)"],
 [rc_proj,"Release","dwarf-with-dsym","","","",""]].each do |id,name,fmt,opt,defs,swift_opt,swift_active|
  puts "\t\t#{id} /* #{name} */ = { isa = XCBuildConfiguration; buildSettings = {"
  puts "\t\t\tALWAYS_SEARCH_USER_PATHS = NO; CLANG_ANALYZER_NONNULL = YES; CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\"; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES;"
  puts "\t\t\tCOPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = #{fmt}; ENABLE_STRICT_OBJC_MSGSEND = YES; ENABLE_USER_SCRIPT_SANDBOXING = YES;"
  puts "\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17; GCC_NO_COMMON_BLOCKS = YES; GCC_WARN_64_TO_32_BIT_CONVERSION = YES; GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;"
  puts "\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE; GCC_WARN_UNUSED_FUNCTION = YES; GCC_WARN_UNUSED_VARIABLE = YES;"
  puts "\t\t\tINFOPLIST_FILE = \"Sources/ClaudeChat/Info.plist\"; MACOSX_DEPLOYMENT_TARGET = 14.0; MTL_FAST_MATH = YES; SDKROOT = macosx; SWIFT_VERSION = 5.0;"
  puts "\t\t\tGCC_OPTIMIZATION_LEVEL = #{opt};" unless opt.empty?
  puts "\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (\"#{defs}\",\"\$(inherited)\",);" unless defs.empty?
  puts "\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"#{swift_opt}\";" unless swift_opt.empty?
  puts "\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"#{swift_active}\";" unless swift_active.empty?
  puts "\t\t\tONLY_ACTIVE_ARCH = YES;" if name == "Debug"
  puts "\t\t\tSWIFT_COMPILATION_MODE = wholemodule;" if name == "Release"
  puts "\t\t\tENABLE_NS_ASSERTIONS = NO;" if name == "Release"
  puts "\t\t}; name = #{name}; };"
end
[[dc_tgt,"Debug"],[rc_tgt,"Release"]].each do |id,name|
  puts "\t\t#{id} /* #{name} */ = { isa = XCBuildConfiguration; buildSettings = {"
  puts "\t\t\tCODE_SIGN_STYLE = Automatic; COMBINE_HIDPI_IMAGES = YES; CURRENT_PROJECT_VERSION = 1; ENABLE_HARDENED_RUNTIME = YES;"
  puts "\t\t\tGENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = \"Sources/ClaudeChat/Info.plist\";"
  puts "\t\t\tLD_RUNPATH_SEARCH_PATHS = (\"\$(inherited)\",\"@executable_path/../Frameworks\",);"
  puts "\t\t\tMARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = com.jianyimian.app; PRODUCT_NAME = \"见一面\";"
  puts "\t\t\tSWIFT_EMIT_LOC_STRINGS = YES; SWIFT_VERSION = 5.0;"
  puts "\t\t}; name = #{name}; };"
end
puts "/* End XCBuildConfiguration section */"

puts "/* Begin XCConfigurationList section */"
puts "\t\t#{cl_proj} = { isa = XCConfigurationList; buildConfigurations = (#{dc_proj},#{rc_proj},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"
puts "\t\t#{cl_tgt} = { isa = XCConfigurationList; buildConfigurations = (#{dc_tgt},#{rc_tgt},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"
puts "/* End XCConfigurationList section */"
puts "}; rootObject = #{proj}; }"
