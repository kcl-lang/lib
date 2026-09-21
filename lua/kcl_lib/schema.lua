return "\
×N2’\1\0186\26\23.com.kcl.api.PingResult\
\4Ping\18\21.com.kcl.api.PingArgs\18H\26\29.com.kcl.api.ListMethodResult\
\
ListMethod\18\27.com.kcl.api.ListMethodArgs\
\14BuiltinService2°\13\0186\26\23.com.kcl.api.PingResult\
\4Ping\18\21.com.kcl.api.PingArgs\18H\26\29.com.kcl.api.GetVersionResult\
\
GetVersion\18\27.com.kcl.api.GetVersionArgs\18N\26\31.com.kcl.api.ParseProgramResult\
\12ParseProgram\18\29.com.kcl.api.ParseProgramArgs\18E\26\28.com.kcl.api.ParseFileResult\
\9ParseFile\18\26.com.kcl.api.ParseFileArgs\18K\26\30.com.kcl.api.LoadPackageResult\
\11LoadPackage\18\28.com.kcl.api.LoadPackageArgs\18L\26\30.com.kcl.api.ListOptionsResult\
\11ListOptions\18\29.com.kcl.api.ParseProgramArgs\18Q\26 .com.kcl.api.ListVariablesResult\
\13ListVariables\18\30.com.kcl.api.ListVariablesArgs\18K\26\30.com.kcl.api.ExecProgramResult\
\11ExecProgram\18\28.com.kcl.api.ExecProgramArgs\18N\26\31.com.kcl.api.BuildProgramResult\
\12BuildProgram\18\29.com.kcl.api.BuildProgramArgs\18M\26\30.com.kcl.api.ExecProgramResult\
\12ExecArtifact\18\29.com.kcl.api.ExecArtifactArgs\18N\26\31.com.kcl.api.OverrideFileResult\
\12OverrideFile\18\29.com.kcl.api.OverrideFileArgs\18f\26'.com.kcl.api.GetSchemaTypeMappingResult\
\20GetSchemaTypeMapping\18%.com.kcl.api.GetSchemaTypeMappingArgs\18H\26\29.com.kcl.api.FormatCodeResult\
\
FormatCode\18\27.com.kcl.api.FormatCodeArgs\18H\26\29.com.kcl.api.FormatPathResult\
\
FormatPath\18\27.com.kcl.api.FormatPathArgs\18B\26\27.com.kcl.api.LintPathResult\
\8LintPath\18\25.com.kcl.api.LintPathArgs\18N\26\31.com.kcl.api.ValidateCodeResult\
\12ValidateCode\18\29.com.kcl.api.ValidateCodeArgs\18N\26\31.com.kcl.api.ListDepFilesResult\
\12ListDepFiles\18\29.com.kcl.api.ListDepFilesArgs\18]\26$.com.kcl.api.LoadSettingsFilesResult\
\17LoadSettingsFiles\18\".com.kcl.api.LoadSettingsFilesArgs\18<\26\25.com.kcl.api.RenameResult\
\6Rename\18\23.com.kcl.api.RenameArgs\18H\26\29.com.kcl.api.RenameCodeResult\
\
RenameCode\18\27.com.kcl.api.RenameCodeArgs\0186\26\23.com.kcl.api.TestResult\
\4Test\18\21.com.kcl.api.TestArgs\18`\26%.com.kcl.api.UpdateDependenciesResult\
\18UpdateDependencies\18#.com.kcl.api.UpdateDependenciesArgs\
\
KclServiceb\6proto3\
\
spec.proto\18\11com.kcl.apiB\20Z\5.;apiª\2\
KclLib.API\"1\18\16\24\1(\9 \1\
\8pkg_name\18\16\24\2(\9 \1\
\8pkg_path\
\11ExternalPkg\"'\18\12\24\1(\9 \1\
\4name\18\13\24\2(\9 \1\
\5value\
\8Argument\"L\18\13\24\1(\9 \1\
\5level\18\12\24\2(\9 \1\
\4code\18&\24\3(\11 \3\
\8messages2\20.com.kcl.api.Message\
\5Error\":\18\11\24\1(\9 \1\
\3msg\18\"\24\2(\11 \1\
\3pos2\21.com.kcl.api.Position\
\7Message\"\25\18\13\24\1(\9 \1\
\5value\
\8PingArgs\"\27\18\13\24\1(\9 \1\
\5value\
\
PingResult\"\16\
\14GetVersionArgs\"\\\18\15\24\1(\9 \1\
\7version\18\16\24\2(\9 \1\
\8checksum\18\15\24\3(\9 \1\
\7git_sha\18\20\24\4(\9 \1\
\12version_info\
\16GetVersionResult\"\16\
\14ListMethodArgs\",\18\24\24\1(\9 \3\
\16method_name_list\
\16ListMethodResult\"^\18\12\24\1(\9 \1\
\4path\18\14\24\2(\9 \1\
\6source\18/\24\3(\11 \3\
\13external_pkgs2\24.com.kcl.api.ExternalPkg\
\13ParseFileArgs\"U\18\16\24\1(\9 \1\
\8ast_json\18\12\24\2(\9 \3\
\4deps\18\"\24\3(\11 \3\
\6errors2\18.com.kcl.api.Error\
\15ParseFileResult\"c\18\13\24\1(\9 \3\
\5paths\18\15\24\2(\9 \3\
\7sources\18/\24\3(\11 \3\
\13external_pkgs2\24.com.kcl.api.ExternalPkg\
\16ParseProgramArgs\"Y\18\16\24\1(\9 \1\
\8ast_json\18\13\24\2(\9 \3\
\5paths\18\"\24\3(\11 \3\
\6errors2\18.com.kcl.api.Error\
\18ParseProgramResult\"‡\1\0181\24\1(\11 \1\
\
parse_args2\29.com.kcl.api.ParseProgramArgs\18\19\24\2(\8 \1\
\11resolve_ast\18\20\24\3(\8 \1\
\12load_builtin\18\22\24\4(\8 \1\
\14with_ast_index\
\15LoadPackageArgs\"ð\7\26A\
\11ScopesEntry\18\11\24\1(\9 \1\
\3key\18!\24\2(\11 \1\
\5value2\18.com.kcl.api.Scope:\0028\1\26C\
\12SymbolsEntry\18\11\24\1(\9 \1\
\3key\18\"\24\2(\11 \1\
\5value2\19.com.kcl.api.Symbol:\0028\1\26N\
\18NodeSymbolMapEntry\18\11\24\1(\9 \1\
\3key\18'\24\2(\11 \1\
\5value2\24.com.kcl.api.SymbolIndex:\0028\1\0264\
\18SymbolNodeMapEntry\18\11\24\1(\9 \1\
\3key\18\13\24\2(\9 \1\
\5value:\0028\1\26V\
\26FullyQualifiedNameMapEntry\18\11\24\1(\9 \1\
\3key\18'\24\2(\11 \1\
\5value2\24.com.kcl.api.SymbolIndex:\0028\1\26K\
\16PkgScopeMapEntry\18\11\24\1(\9 \1\
\3key\18&\24\2(\11 \1\
\5value2\23.com.kcl.api.ScopeIndex:\0028\1\
\17LoadPackageResult\18\15\24\1(\9 \1\
\7program\18\13\24\2(\9 \3\
\5paths\18(\24\3(\11 \3\
\12parse_errors2\18.com.kcl.api.Error\18'\24\4(\11 \3\
\11type_errors2\18.com.kcl.api.Error\18:\24\5(\11 \3\
\6scopes2*.com.kcl.api.LoadPackageResult.ScopesEntry\18<\24\6(\11 \3\
\7symbols2+.com.kcl.api.LoadPackageResult.SymbolsEntry\18J\24\7(\11 \3\
\15node_symbol_map21.com.kcl.api.LoadPackageResult.NodeSymbolMapEntry\18J\24\8(\11 \3\
\15symbol_node_map21.com.kcl.api.LoadPackageResult.SymbolNodeMapEntry\18[\24\9(\11 \3\
\24fully_qualified_name_map29.com.kcl.api.LoadPackageResult.FullyQualifiedNameMapEntry\18F\24\
(\11 \3\
\13pkg_scope_map2/.com.kcl.api.LoadPackageResult.PkgScopeMapEntry\"=\18(\24\2(\11 \3\
\7options2\23.com.kcl.api.OptionHelp\
\17ListOptionsResult\"_\18\12\24\1(\9 \1\
\4name\18\12\24\2(\9 \1\
\4type\18\16\24\3(\8 \1\
\8required\18\21\24\4(\9 \1\
\13default_value\18\12\24\5(\9 \1\
\4help\
\
OptionHelp\"Ä\1\18 \24\1(\11 \1\
\2ty2\20.com.kcl.api.KclType\18\12\24\2(\9 \1\
\4name\18'\24\3(\11 \1\
\5owner2\24.com.kcl.api.SymbolIndex\18%\24\4(\11 \1\
\3def2\24.com.kcl.api.SymbolIndex\18'\24\5(\11 \3\
\5attrs2\24.com.kcl.api.SymbolIndex\18\17\24\6(\8 \1\
\9is_global\
\6Symbol\"º\1\18\12\24\1(\9 \1\
\4kind\18'\24\2(\11 \1\
\6parent2\23.com.kcl.api.ScopeIndex\18'\24\3(\11 \1\
\5owner2\24.com.kcl.api.SymbolIndex\18)\24\4(\11 \3\
\8children2\23.com.kcl.api.ScopeIndex\18&\24\5(\11 \3\
\4defs2\24.com.kcl.api.SymbolIndex\
\5Scope\"1\18\9\24\1(\4 \1\
\1i\18\9\24\2(\4 \1\
\1g\18\12\24\3(\9 \1\
\4kind\
\11SymbolIndex\"0\18\9\24\1(\4 \1\
\1i\18\9\24\2(\4 \1\
\1g\18\12\24\3(\9 \1\
\4kind\
\
ScopeIndex\"Ï\3\18\16\24\1(\9 \1\
\8work_dir\18\23\24\2(\9 \3\
\15k_filename_list\18\19\24\3(\9 \3\
\11k_code_list\18#\24\4(\11 \3\
\4args2\21.com.kcl.api.Argument\18\17\24\5(\9 \3\
\9overrides\18\27\24\6(\8 \1\
\19disable_yaml_result\18\26\24\7(\8 \1\
\18print_override_ast\18\26\24\8(\8 \1\
\18strict_range_check\18\20\24\9(\8 \1\
\12disable_none\18\15\24\
(\5 \1\
\7verbose\18\13\24\11(\5 \1\
\5debug\18\17\24\12(\8 \1\
\9sort_keys\18/\24\13(\11 \3\
\13external_pkgs2\24.com.kcl.api.ExternalPkg\18 \24\14(\8 \1\
\24include_schema_type_path\18\20\24\15(\8 \1\
\12compile_only\18\19\24\16(\8 \1\
\11show_hidden\18\21\24\17(\9 \3\
\13path_selector\18\17\24\18(\8 \1\
\9fast_eval\
\15ExecProgramArgs\"g\18\19\24\1(\9 \1\
\11json_result\18\19\24\2(\9 \1\
\11yaml_result\18\19\24\3(\9 \1\
\11log_message\18\19\24\4(\9 \1\
\11err_message\
\17ExecProgramResult\"S\18/\24\1(\11 \1\
\9exec_args2\28.com.kcl.api.ExecProgramArgs\18\14\24\2(\9 \1\
\6output\
\16BuildProgramArgs\"\"\18\12\24\1(\9 \1\
\4path\
\18BuildProgramResult\"Q\18\12\24\1(\9 \1\
\4path\18/\24\2(\11 \1\
\9exec_args2\28.com.kcl.api.ExecProgramArgs\
\16ExecArtifactArgs\" \18\14\24\1(\9 \1\
\6source\
\14FormatCodeArgs\"%\18\17\24\1(\12 \1\
\9formatted\
\16FormatCodeResult\"\30\18\12\24\1(\9 \1\
\4path\
\14FormatPathArgs\")\18\21\24\1(\9 \3\
\13changed_paths\
\16FormatPathResult\"\29\18\13\24\1(\9 \3\
\5paths\
\12LintPathArgs\"!\18\15\24\1(\9 \3\
\7results\
\14LintPathResult\"E\18\12\24\1(\9 \1\
\4file\18\13\24\2(\9 \3\
\5specs\18\20\24\3(\9 \3\
\12import_paths\
\16OverrideFileArgs\"N\18\14\24\1(\8 \1\
\6result\18(\24\2(\11 \3\
\12parse_errors2\18.com.kcl.api.Error\
\18OverrideFileResult\"-\18\21\24\1(\8 \1\
\13merge_program\
\20ListVariablesOptions\"8\18(\24\1(\11 \3\
\9variables2\21.com.kcl.api.Variable\
\12VariableList\"e\18\13\24\1(\9 \3\
\5files\18\13\24\2(\9 \3\
\5specs\0182\24\3(\11 \1\
\7options2!.com.kcl.api.ListVariablesOptions\
\17ListVariablesArgs\"ë\1\26K\
\14VariablesEntry\18\11\24\1(\9 \1\
\3key\18(\24\2(\11 \1\
\5value2\25.com.kcl.api.VariableList:\0028\1\
\19ListVariablesResult\18B\24\1(\11 \3\
\9variables2/.com.kcl.api.ListVariablesResult.VariablesEntry\18\25\24\2(\9 \3\
\17unsupported_codes\18(\24\3(\11 \3\
\12parse_errors2\18.com.kcl.api.Error\"”\1\18\13\24\1(\9 \1\
\5value\18\17\24\2(\9 \1\
\9type_name\18\14\24\3(\9 \1\
\6op_sym\18)\24\4(\11 \3\
\
list_items2\21.com.kcl.api.Variable\18+\24\5(\11 \3\
\12dict_entries2\21.com.kcl.api.MapEntry\
\8Variable\"=\18\11\24\1(\9 \1\
\3key\18$\24\2(\11 \1\
\5value2\21.com.kcl.api.Variable\
\8MapEntry\"`\18/\24\1(\11 \1\
\9exec_args2\28.com.kcl.api.ExecProgramArgs\18\19\24\2(\9 \1\
\11schema_name\
\24GetSchemaTypeMappingArgs\"É\1\26N\
\22SchemaTypeMappingEntry\18\11\24\1(\9 \1\
\3key\18#\24\2(\11 \1\
\5value2\20.com.kcl.api.KclType:\0028\1\
\26GetSchemaTypeMappingResult\18[\24\1(\11 \3\
\19schema_type_mapping2>.com.kcl.api.GetSchemaTypeMappingResult.SchemaTypeMappingEntry\"ß\1\26R\
\22SchemaTypeMappingEntry\18\11\24\1(\9 \1\
\3key\18'\24\2(\11 \1\
\5value2\24.com.kcl.api.SchemaTypes:\0028\1\
#GetSchemaTypeMappingUnderPathResult\18d\24\1(\11 \3\
\19schema_type_mapping2G.com.kcl.api.GetSchemaTypeMappingUnderPathResult.SchemaTypeMappingEntry\"8\18)\24\1(\11 \3\
\11schema_type2\20.com.kcl.api.KclType\
\11SchemaTypes\"·\1\18\16\24\1(\9 \1\
\8datafile\18\12\24\2(\9 \1\
\4data\18\12\24\3(\9 \1\
\4file\18\12\24\4(\9 \1\
\4code\18\14\24\5(\9 \1\
\6schema\18\22\24\6(\9 \1\
\14attribute_name\18\14\24\7(\9 \1\
\6format\18/\24\8(\11 \3\
\13external_pkgs2\24.com.kcl.api.ExternalPkg\
\16ValidateCodeArgs\":\18\15\24\1(\8 \1\
\7success\18\19\24\2(\9 \1\
\11err_message\
\18ValidateCodeResult\":\18\12\24\1(\3 \1\
\4line\18\14\24\2(\3 \1\
\6column\18\16\24\3(\9 \1\
\8filename\
\8Position\"h\18\16\24\1(\9 \1\
\8work_dir\18\20\24\2(\8 \1\
\12use_abs_path\18\19\24\3(\8 \1\
\11include_all\18\23\24\4(\8 \1\
\15use_fast_parser\
\16ListDepFilesArgs\"E\18\15\24\1(\9 \1\
\7pkgroot\18\15\24\2(\9 \1\
\7pkgpath\18\13\24\3(\9 \3\
\5files\
\18ListDepFilesResult\"8\18\16\24\1(\9 \1\
\8work_dir\18\13\24\2(\9 \3\
\5files\
\21LoadSettingsFilesArgs\"z\18/\24\1(\11 \1\
\15kcl_cli_configs2\22.com.kcl.api.CliConfig\18.\24\2(\11 \3\
\11kcl_options2\25.com.kcl.api.KeyValuePair\
\23LoadSettingsFilesResult\"ƒ\2\18\13\24\1(\9 \3\
\5files\18\14\24\2(\9 \1\
\6output\18\17\24\3(\9 \3\
\9overrides\18\21\24\4(\9 \3\
\13path_selector\18\26\24\5(\8 \1\
\18strict_range_check\18\20\24\6(\8 \1\
\12disable_none\18\15\24\7(\3 \1\
\7verbose\18\13\24\8(\8 \1\
\5debug\18\17\24\9(\8 \1\
\9sort_keys\18\19\24\
(\8 \1\
\11show_hidden\18 \24\11(\8 \1\
\24include_schema_type_path\18\17\24\12(\8 \1\
\9fast_eval\
\9CliConfig\"*\18\11\24\1(\9 \1\
\3key\18\13\24\2(\9 \1\
\5value\
\12KeyValuePair\"]\18\20\24\1(\9 \1\
\12package_root\18\19\24\2(\9 \1\
\11symbol_path\18\18\24\3(\9 \3\
\
file_paths\18\16\24\4(\9 \1\
\8new_name\
\
RenameArgs\"%\18\21\24\1(\9 \3\
\13changed_files\
\12RenameResult\"Å\1\0262\
\16SourceCodesEntry\18\11\24\1(\9 \1\
\3key\18\13\24\2(\9 \1\
\5value:\0028\1\
\14RenameCodeArgs\18\20\24\1(\9 \1\
\12package_root\18\19\24\2(\9 \1\
\11symbol_path\18B\24\3(\11 \3\
\12source_codes2,.com.kcl.api.RenameCodeArgs.SourceCodesEntry\18\16\24\4(\9 \1\
\8new_name\"\1\0263\
\17ChangedCodesEntry\18\11\24\1(\9 \1\
\3key\18\13\24\2(\9 \1\
\5value:\0028\1\
\16RenameCodeResult\18F\24\1(\11 \3\
\13changed_codes2/.com.kcl.api.RenameCodeResult.ChangedCodesEntry\"t\18/\24\1(\11 \1\
\9exec_args2\28.com.kcl.api.ExecProgramArgs\18\16\24\2(\9 \3\
\8pkg_list\18\18\24\3(\9 \1\
\
run_regexp\18\17\24\4(\8 \1\
\9fail_fast\
\8TestArgs\"5\18'\24\2(\11 \3\
\4info2\25.com.kcl.api.TestCaseInfo\
\
TestResult\"R\18\12\24\1(\9 \1\
\4name\18\13\24\2(\9 \1\
\5error\18\16\24\3(\4 \1\
\8duration\18\19\24\4(\9 \1\
\11log_message\
\12TestCaseInfo\"?\18\21\24\1(\9 \1\
\13manifest_path\18\14\24\2(\8 \1\
\6vendor\
\22UpdateDependenciesArgs\"K\18/\24\3(\11 \3\
\13external_pkgs2\24.com.kcl.api.ExternalPkg\
\24UpdateDependenciesResult\"û\5\26G\
\15PropertiesEntry\18\11\24\1(\9 \1\
\3key\18#\24\2(\11 \1\
\5value2\20.com.kcl.api.KclType:\0028\1\26E\
\13ExamplesEntry\18\11\24\1(\9 \1\
\3key\18#\24\2(\11 \1\
\5value2\20.com.kcl.api.Example:\0028\1\
\7KclType\18\12\24\1(\9 \1\
\4type\18)\24\2(\11 \3\
\11union_types2\20.com.kcl.api.KclType\18\15\24\3(\9 \1\
\7default\18\19\24\4(\9 \1\
\11schema_name\18\18\24\5(\9 \1\
\
schema_doc\0188\24\6(\11 \3\
\
properties2$.com.kcl.api.KclType.PropertiesEntry\18\16\24\7(\9 \3\
\8required\18!\24\8(\11 \1\
\3key2\20.com.kcl.api.KclType\18\"\24\9(\11 \1\
\4item2\20.com.kcl.api.KclType\18\12\24\
(\5 \1\
\4line\18*\24\11(\11 \3\
\
decorators2\22.com.kcl.api.Decorator\18\16\24\12(\9 \1\
\8filename\18\16\24\13(\9 \1\
\8pkg_path\18\19\24\14(\9 \1\
\11description\0184\24\15(\11 \3\
\8examples2\".com.kcl.api.KclType.ExamplesEntry\18)\24\16(\11 \1\
\11base_schema2\20.com.kcl.api.KclType\18-\24\17H\0 \1\
\8function(\0112\25.com.kcl.api.FunctionType\0186\24\18H\1 \1\
\15index_signature(\0112\27.com.kcl.api.IndexSignatureB\11\
\9_functionB\18\
\16_index_signature\"_\18&\24\1(\11 \3\
\6params2\22.com.kcl.api.Parameter\18'\24\2(\11 \1\
\9return_ty2\20.com.kcl.api.KclType\
\12FunctionType\";\18\12\24\1(\9 \1\
\4name\18 \24\2(\11 \1\
\2ty2\20.com.kcl.api.KclType\
\9Parameter\"Š\1\
\14IndexSignature\18\18\24\1(\9 \1\
\8key_nameH\0\18!\24\2(\11 \1\
\3key2\20.com.kcl.api.KclType\18!\24\3(\11 \1\
\3val2\20.com.kcl.api.KclType\18\17\24\4(\8 \1\
\9any_otherB\11\
\9_key_name\"•\1\26/\
\13KeywordsEntry\18\11\24\1(\9 \1\
\3key\18\13\24\2(\9 \1\
\5value:\0028\1\
\9Decorator\18\12\24\1(\9 \1\
\4name\18\17\24\2(\9 \3\
\9arguments\0186\24\3(\11 \3\
\8keywords2$.com.kcl.api.Decorator.KeywordsEntry\">\18\15\24\1(\9 \1\
\7summary\18\19\24\2(\9 \1\
\11description\18\13\24\3(\9 \1\
\5value\
\7Example"