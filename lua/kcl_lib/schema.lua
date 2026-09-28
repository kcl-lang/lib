return "\
šQ\
\
spec.proto\18\11com.kcl.apib\6proto32’\1\0186\
\4Ping\26\23.com.kcl.api.PingResult\18\21.com.kcl.api.PingArgs\18H\
\
ListMethod\26\29.com.kcl.api.ListMethodResult\18\27.com.kcl.api.ListMethodArgs\
\14BuiltinService2»\12\0186\
\4Ping\26\23.com.kcl.api.PingResult\18\21.com.kcl.api.PingArgs\18H\
\
GetVersion\26\29.com.kcl.api.GetVersionResult\18\27.com.kcl.api.GetVersionArgs\18N\
\12ParseProgram\26\31.com.kcl.api.ParseProgramResult\18\29.com.kcl.api.ParseProgramArgs\18E\
\9ParseFile\26\28.com.kcl.api.ParseFileResult\18\26.com.kcl.api.ParseFileArgs\18K\
\11LoadPackage\26\30.com.kcl.api.LoadPackageResult\18\28.com.kcl.api.LoadPackageArgs\18L\
\11ListOptions\26\30.com.kcl.api.ListOptionsResult\18\29.com.kcl.api.ParseProgramArgs\18Q\
\13ListVariables\26 .com.kcl.api.ListVariablesResult\18\30.com.kcl.api.ListVariablesArgs\18K\
\11ExecProgram\26\30.com.kcl.api.ExecProgramResult\18\28.com.kcl.api.ExecProgramArgs\18N\
\12OverrideFile\26\31.com.kcl.api.OverrideFileResult\18\29.com.kcl.api.OverrideFileArgs\18f\
\20GetSchemaTypeMapping\26'.com.kcl.api.GetSchemaTypeMappingResult\18%.com.kcl.api.GetSchemaTypeMappingArgs\18x\
\29GetSchemaTypeMappingUnderPath\0260.com.kcl.api.GetSchemaTypeMappingUnderPathResult\18%.com.kcl.api.GetSchemaTypeMappingArgs\18H\
\
FormatCode\26\29.com.kcl.api.FormatCodeResult\18\27.com.kcl.api.FormatCodeArgs\18H\
\
FormatPath\26\29.com.kcl.api.FormatPathResult\18\27.com.kcl.api.FormatPathArgs\18B\
\8LintPath\26\27.com.kcl.api.LintPathResult\18\25.com.kcl.api.LintPathArgs\18N\
\12ValidateCode\26\31.com.kcl.api.ValidateCodeResult\18\29.com.kcl.api.ValidateCodeArgs\18]\
\17LoadSettingsFiles\26$.com.kcl.api.LoadSettingsFilesResult\18\".com.kcl.api.LoadSettingsFilesArgs\18<\
\6Rename\26\25.com.kcl.api.RenameResult\18\23.com.kcl.api.RenameArgs\18H\
\
RenameCode\26\29.com.kcl.api.RenameCodeResult\18\27.com.kcl.api.RenameCodeArgs\0186\
\4Test\26\23.com.kcl.api.TestResult\18\21.com.kcl.api.TestArgs\18`\
\18UpdateDependencies\26%.com.kcl.api.UpdateDependenciesResult\18#.com.kcl.api.UpdateDependenciesArgs\
\
KclService\"1\18\16(\9\24\1 \1\
\8pkg_name\18\16(\9\24\2 \1\
\8pkg_path\
\11ExternalPkg\"'\18\12(\9\24\1 \1\
\4name\18\13(\9\24\2 \1\
\5value\
\8Argument\"L\18\13(\9\24\1 \1\
\5level\18\12(\9\24\2 \1\
\4code\18&2\20.com.kcl.api.Message(\11\24\3 \3\
\8messages\
\5Error\":\18\11(\9\24\1 \1\
\3msg\18\"2\21.com.kcl.api.Position(\11\24\2 \1\
\3pos\
\7Message\"\25\18\13(\9\24\1 \1\
\5value\
\8PingArgs\"\27\18\13(\9\24\1 \1\
\5value\
\
PingResult\"\16\
\14GetVersionArgs\"\\\18\15(\9\24\1 \1\
\7version\18\16(\9\24\2 \1\
\8checksum\18\15(\9\24\3 \1\
\7git_sha\18\20(\9\24\4 \1\
\12version_info\
\16GetVersionResult\"\16\
\14ListMethodArgs\",\18\24(\9\24\1 \3\
\16method_name_list\
\16ListMethodResult\"^\18\12(\9\24\1 \1\
\4path\18\14(\9\24\2 \1\
\6source\18/2\24.com.kcl.api.ExternalPkg(\11\24\3 \3\
\13external_pkgs\
\13ParseFileArgs\"U\18\16(\9\24\1 \1\
\8ast_json\18\12(\9\24\2 \3\
\4deps\18\"2\18.com.kcl.api.Error(\11\24\3 \3\
\6errors\
\15ParseFileResult\"c\18\13(\9\24\1 \3\
\5paths\18\15(\9\24\2 \3\
\7sources\18/2\24.com.kcl.api.ExternalPkg(\11\24\3 \3\
\13external_pkgs\
\16ParseProgramArgs\"Y\18\16(\9\24\1 \1\
\8ast_json\18\13(\9\24\2 \3\
\5paths\18\"2\18.com.kcl.api.Error(\11\24\3 \3\
\6errors\
\18ParseProgramResult\"‡\1\01812\29.com.kcl.api.ParseProgramArgs(\11\24\1 \1\
\
parse_args\18\19(\8\24\2 \1\
\11resolve_ast\18\20(\8\24\3 \1\
\12load_builtin\18\22(\8\24\4 \1\
\14with_ast_index\
\15LoadPackageArgs\"ð\7\26A:\0028\1\18\11(\9\24\1 \1\
\3key\18!2\18.com.kcl.api.Scope(\11\24\2 \1\
\5value\
\11ScopesEntry\26C:\0028\1\18\11(\9\24\1 \1\
\3key\18\"2\19.com.kcl.api.Symbol(\11\24\2 \1\
\5value\
\12SymbolsEntry\26N:\0028\1\18\11(\9\24\1 \1\
\3key\18'2\24.com.kcl.api.SymbolIndex(\11\24\2 \1\
\5value\
\18NodeSymbolMapEntry\0264:\0028\1\18\11(\9\24\1 \1\
\3key\18\13(\9\24\2 \1\
\5value\
\18SymbolNodeMapEntry\26V:\0028\1\18\11(\9\24\1 \1\
\3key\18'2\24.com.kcl.api.SymbolIndex(\11\24\2 \1\
\5value\
\26FullyQualifiedNameMapEntry\26K:\0028\1\18\11(\9\24\1 \1\
\3key\18&2\23.com.kcl.api.ScopeIndex(\11\24\2 \1\
\5value\
\16PkgScopeMapEntry\18\15(\9\24\1 \1\
\7program\18\13(\9\24\2 \3\
\5paths\18(2\18.com.kcl.api.Error(\11\24\3 \3\
\12parse_errors\18'2\18.com.kcl.api.Error(\11\24\4 \3\
\11type_errors\18:2*.com.kcl.api.LoadPackageResult.ScopesEntry(\11\24\5 \3\
\6scopes\18<2+.com.kcl.api.LoadPackageResult.SymbolsEntry(\11\24\6 \3\
\7symbols\18J21.com.kcl.api.LoadPackageResult.NodeSymbolMapEntry(\11\24\7 \3\
\15node_symbol_map\18J21.com.kcl.api.LoadPackageResult.SymbolNodeMapEntry(\11\24\8 \3\
\15symbol_node_map\18[29.com.kcl.api.LoadPackageResult.FullyQualifiedNameMapEntry(\11\24\9 \3\
\24fully_qualified_name_map\18F2/.com.kcl.api.LoadPackageResult.PkgScopeMapEntry(\11\24\
 \3\
\13pkg_scope_map\
\17LoadPackageResult\"=\18(2\23.com.kcl.api.OptionHelp(\11\24\2 \3\
\7options\
\17ListOptionsResult\"_\18\12(\9\24\1 \1\
\4name\18\12(\9\24\2 \1\
\4type\18\16(\8\24\3 \1\
\8required\18\21(\9\24\4 \1\
\13default_value\18\12(\9\24\5 \1\
\4help\
\
OptionHelp\"Ä\1\18 2\20.com.kcl.api.KclType(\11\24\1 \1\
\2ty\18\12(\9\24\2 \1\
\4name\18'2\24.com.kcl.api.SymbolIndex(\11\24\3 \1\
\5owner\18%2\24.com.kcl.api.SymbolIndex(\11\24\4 \1\
\3def\18'2\24.com.kcl.api.SymbolIndex(\11\24\5 \3\
\5attrs\18\17(\8\24\6 \1\
\9is_global\
\6Symbol\"º\1\18\12(\9\24\1 \1\
\4kind\18'2\23.com.kcl.api.ScopeIndex(\11\24\2 \1\
\6parent\18'2\24.com.kcl.api.SymbolIndex(\11\24\3 \1\
\5owner\18)2\23.com.kcl.api.ScopeIndex(\11\24\4 \3\
\8children\18&2\24.com.kcl.api.SymbolIndex(\11\24\5 \3\
\4defs\
\5Scope\"1\18\9(\4\24\1 \1\
\1i\18\9(\4\24\2 \1\
\1g\18\12(\9\24\3 \1\
\4kind\
\11SymbolIndex\"0\18\9(\4\24\1 \1\
\1i\18\9(\4\24\2 \1\
\1g\18\12(\9\24\3 \1\
\4kind\
\
ScopeIndex\"Ç\4B\19\
\17_sourcemap_output\18\16(\9\24\1 \1\
\8work_dir\18\23(\9\24\2 \3\
\15k_filename_list\18\19(\9\24\3 \3\
\11k_code_list\18#2\21.com.kcl.api.Argument(\11\24\4 \3\
\4args\18\17(\9\24\5 \3\
\9overrides\18\27(\8\24\6 \1\
\19disable_yaml_result\18\26(\8\24\7 \1\
\18print_override_ast\18\26(\8\24\8 \1\
\18strict_range_check\18\20(\8\24\9 \1\
\12disable_none\18\15(\5\24\
 \1\
\7verbose\18\13(\5\24\11 \1\
\5debug\18\17(\8\24\12 \1\
\9sort_keys\18/2\24.com.kcl.api.ExternalPkg(\11\24\13 \3\
\13external_pkgs\18 (\8\24\14 \1\
\24include_schema_type_path\18\20(\8\24\15 \1\
\12compile_only\18\19(\8\24\16 \1\
\11show_hidden\18\21(\9\24\17 \3\
\13path_selector\18\17(\8\24\18 \1\
\9fast_eval\18\20(\9\24\19 \1\
\12error_format\18\14(\9\24\20 \1\
\6format\18\31(\8\24\21 \1\
\23emit_attribute_metadata\18\26(\9\24\22 \1H\0\
\16sourcemap_output\
\15ExecProgramArgs\"Š\1B\12\
\
_sourcemap\18\19(\9\24\1 \1\
\11json_result\18\19(\9\24\2 \1\
\11yaml_result\18\19(\9\24\3 \1\
\11log_message\18\19(\9\24\4 \1\
\11err_message\18\19(\9\24\5 \1H\0\
\9sourcemap\
\17ExecProgramResult\" \18\14(\9\24\1 \1\
\6source\
\14FormatCodeArgs\"%\18\17(\12\24\1 \1\
\9formatted\
\16FormatCodeResult\"/\18\12(\9\24\1 \1\
\4path\18\15(\8\24\2 \1\
\7dry_run\
\14FormatPathArgs\")\18\21(\9\24\1 \3\
\13changed_paths\
\16FormatPathResult\"\29\18\13(\9\24\1 \3\
\5paths\
\12LintPathArgs\"!\18\15(\9\24\1 \3\
\7results\
\14LintPathResult\"E\18\12(\9\24\1 \1\
\4file\18\13(\9\24\2 \3\
\5specs\18\20(\9\24\3 \3\
\12import_paths\
\16OverrideFileArgs\"N\18\14(\8\24\1 \1\
\6result\18(2\18.com.kcl.api.Error(\11\24\2 \3\
\12parse_errors\
\18OverrideFileResult\"-\18\21(\8\24\1 \1\
\13merge_program\
\20ListVariablesOptions\"8\18(2\21.com.kcl.api.Variable(\11\24\1 \3\
\9variables\
\12VariableList\"e\18\13(\9\24\1 \3\
\5files\18\13(\9\24\2 \3\
\5specs\01822!.com.kcl.api.ListVariablesOptions(\11\24\3 \1\
\7options\
\17ListVariablesArgs\"ë\1\26K:\0028\1\18\11(\9\24\1 \1\
\3key\18(2\25.com.kcl.api.VariableList(\11\24\2 \1\
\5value\
\14VariablesEntry\18B2/.com.kcl.api.ListVariablesResult.VariablesEntry(\11\24\1 \3\
\9variables\18\25(\9\24\2 \3\
\17unsupported_codes\18(2\18.com.kcl.api.Error(\11\24\3 \3\
\12parse_errors\
\19ListVariablesResult\"”\1\18\13(\9\24\1 \1\
\5value\18\17(\9\24\2 \1\
\9type_name\18\14(\9\24\3 \1\
\6op_sym\18)2\21.com.kcl.api.Variable(\11\24\4 \3\
\
list_items\18+2\21.com.kcl.api.MapEntry(\11\24\5 \3\
\12dict_entries\
\8Variable\"=\18\11(\9\24\1 \1\
\3key\18$2\21.com.kcl.api.Variable(\11\24\2 \1\
\5value\
\8MapEntry\"`\18/2\28.com.kcl.api.ExecProgramArgs(\11\24\1 \1\
\9exec_args\18\19(\9\24\2 \1\
\11schema_name\
\24GetSchemaTypeMappingArgs\"É\1\26N:\0028\1\18\11(\9\24\1 \1\
\3key\18#2\20.com.kcl.api.KclType(\11\24\2 \1\
\5value\
\22SchemaTypeMappingEntry\18[2>.com.kcl.api.GetSchemaTypeMappingResult.SchemaTypeMappingEntry(\11\24\1 \3\
\19schema_type_mapping\
\26GetSchemaTypeMappingResult\"ß\1\26R:\0028\1\18\11(\9\24\1 \1\
\3key\18'2\24.com.kcl.api.SchemaTypes(\11\24\2 \1\
\5value\
\22SchemaTypeMappingEntry\18d2G.com.kcl.api.GetSchemaTypeMappingUnderPathResult.SchemaTypeMappingEntry(\11\24\1 \3\
\19schema_type_mapping\
#GetSchemaTypeMappingUnderPathResult\"8\18)2\20.com.kcl.api.KclType(\11\24\1 \3\
\11schema_type\
\11SchemaTypes\"·\1\18\16(\9\24\1 \1\
\8datafile\18\12(\9\24\2 \1\
\4data\18\12(\9\24\3 \1\
\4file\18\12(\9\24\4 \1\
\4code\18\14(\9\24\5 \1\
\6schema\18\22(\9\24\6 \1\
\14attribute_name\18\14(\9\24\7 \1\
\6format\18/2\24.com.kcl.api.ExternalPkg(\11\24\8 \3\
\13external_pkgs\
\16ValidateCodeArgs\":\18\15(\8\24\1 \1\
\7success\18\19(\9\24\2 \1\
\11err_message\
\18ValidateCodeResult\":\18\12(\3\24\1 \1\
\4line\18\14(\3\24\2 \1\
\6column\18\16(\9\24\3 \1\
\8filename\
\8Position\"8\18\16(\9\24\1 \1\
\8work_dir\18\13(\9\24\2 \3\
\5files\
\21LoadSettingsFilesArgs\"z\18/2\22.com.kcl.api.CliConfig(\11\24\1 \1\
\15kcl_cli_configs\18.2\25.com.kcl.api.KeyValuePair(\11\24\2 \3\
\11kcl_options\
\23LoadSettingsFilesResult\"ƒ\2\18\13(\9\24\1 \3\
\5files\18\14(\9\24\2 \1\
\6output\18\17(\9\24\3 \3\
\9overrides\18\21(\9\24\4 \3\
\13path_selector\18\26(\8\24\5 \1\
\18strict_range_check\18\20(\8\24\6 \1\
\12disable_none\18\15(\3\24\7 \1\
\7verbose\18\13(\8\24\8 \1\
\5debug\18\17(\8\24\9 \1\
\9sort_keys\18\19(\8\24\
 \1\
\11show_hidden\18 (\8\24\11 \1\
\24include_schema_type_path\18\17(\8\24\12 \1\
\9fast_eval\
\9CliConfig\"*\18\11(\9\24\1 \1\
\3key\18\13(\9\24\2 \1\
\5value\
\12KeyValuePair\"]\18\20(\9\24\1 \1\
\12package_root\18\19(\9\24\2 \1\
\11symbol_path\18\18(\9\24\3 \3\
\
file_paths\18\16(\9\24\4 \1\
\8new_name\
\
RenameArgs\"%\18\21(\9\24\1 \3\
\13changed_files\
\12RenameResult\"Å\1\0262:\0028\1\18\11(\9\24\1 \1\
\3key\18\13(\9\24\2 \1\
\5value\
\16SourceCodesEntry\18\20(\9\24\1 \1\
\12package_root\18\19(\9\24\2 \1\
\11symbol_path\18B2,.com.kcl.api.RenameCodeArgs.SourceCodesEntry(\11\24\3 \3\
\12source_codes\18\16(\9\24\4 \1\
\8new_name\
\14RenameCodeArgs\"\1\0263:\0028\1\18\11(\9\24\1 \1\
\3key\18\13(\9\24\2 \1\
\5value\
\17ChangedCodesEntry\18F2/.com.kcl.api.RenameCodeResult.ChangedCodesEntry(\11\24\1 \3\
\13changed_codes\
\16RenameCodeResult\"†\1\18/2\28.com.kcl.api.ExecProgramArgs(\11\24\1 \1\
\9exec_args\18\16(\9\24\2 \3\
\8pkg_list\18\18(\9\24\3 \1\
\
run_regexp\18\17(\8\24\4 \1\
\9fail_fast\18\16(\8\24\5 \1\
\8coverage\
\8TestArgs\"h\18'2\25.com.kcl.api.TestCaseInfo(\11\24\2 \3\
\4info\01812\31.com.kcl.api.TestCoverageReport(\11\24\3 \1\
\8coverage\
\
TestResult\"¿\1\26/:\0028\1\18\11(\9\24\1 \1\
\3key\18\13(\4\24\2 \1\
\5value\
\13LineHitsEntry\18\12(\9\24\1 \1\
\4name\18\13(\9\24\2 \1\
\5error\18\16(\4\24\3 \1\
\8duration\18\19(\9\24\4 \1\
\11log_message\18:2'.com.kcl.api.TestCaseInfo.LineHitsEntry(\11\24\5 \3\
\9line_hits\
\12TestCaseInfo\"¾\1\26/:\0028\1\18\11(\4\24\1 \1\
\3key\18\13(\4\24\2 \1\
\5value\
\13LineHitsEntry\18\16(\9\24\1 \1\
\8filename\18\21(\4\24\2 \3\
\13covered_lines\18\24(\4\24\3 \3\
\16executable_lines\18:2'.com.kcl.api.FileCoverage.LineHitsEntry(\11\24\4 \3\
\9line_hits\
\12FileCoverage\"Ç\1\26G:\0028\1\18\11(\9\24\1 \1\
\3key\18(2\25.com.kcl.api.FileCoverage(\11\24\2 \1\
\5value\
\
FilesEntry\01892*.com.kcl.api.TestCoverageReport.FilesEntry(\11\24\1 \3\
\5files\18-2\28.com.kcl.api.CoverageSummary(\11\24\2 \1\
\7summary\
\18TestCoverageReport\"G\18\15(\4\24\1 \1\
\7covered\18\18(\4\24\2 \1\
\
executable\18\15(\1\24\3 \1\
\7percent\
\15CoverageSummary\"?\18\21(\9\24\1 \1\
\13manifest_path\18\14(\8\24\2 \1\
\6vendor\
\22UpdateDependenciesArgs\"K\18/2\24.com.kcl.api.ExternalPkg(\11\24\3 \3\
\13external_pkgs\
\24UpdateDependenciesResult\"û\5\26G:\0028\1\18\11(\9\24\1 \1\
\3key\18#2\20.com.kcl.api.KclType(\11\24\2 \1\
\5value\
\15PropertiesEntry\26E:\0028\1\18\11(\9\24\1 \1\
\3key\18#2\20.com.kcl.api.Example(\11\24\2 \1\
\5value\
\13ExamplesEntryB\11\
\9_functionB\18\
\16_index_signature\18\12(\9\24\1 \1\
\4type\18)2\20.com.kcl.api.KclType(\11\24\2 \3\
\11union_types\18\15(\9\24\3 \1\
\7default\18\19(\9\24\4 \1\
\11schema_name\18\18(\9\24\5 \1\
\
schema_doc\01882$.com.kcl.api.KclType.PropertiesEntry(\11\24\6 \3\
\
properties\18\16(\9\24\7 \3\
\8required\18!2\20.com.kcl.api.KclType(\11\24\8 \1\
\3key\18\"2\20.com.kcl.api.KclType(\11\24\9 \1\
\4item\18\12(\5\24\
 \1\
\4line\18*2\22.com.kcl.api.Decorator(\11\24\11 \3\
\
decorators\18\16(\9\24\12 \1\
\8filename\18\16(\9\24\13 \1\
\8pkg_path\18\19(\9\24\14 \1\
\11description\01842\".com.kcl.api.KclType.ExamplesEntry(\11\24\15 \3\
\8examples\18)2\20.com.kcl.api.KclType(\11\24\16 \1\
\11base_schema\18-2\25.com.kcl.api.FunctionType(\11\24\17 \1H\0\
\8function\01862\27.com.kcl.api.IndexSignature(\11\24\18 \1H\1\
\15index_signature\
\7KclType\"_\18&2\22.com.kcl.api.Parameter(\11\24\1 \3\
\6params\18'2\20.com.kcl.api.KclType(\11\24\2 \1\
\9return_ty\
\12FunctionType\";\18\12(\9\24\1 \1\
\4name\18 2\20.com.kcl.api.KclType(\11\24\2 \1\
\2ty\
\9Parameter\"Š\1B\11\
\9_key_name\18\18(\9\24\1 \1H\0\
\8key_name\18!2\20.com.kcl.api.KclType(\11\24\2 \1\
\3key\18!2\20.com.kcl.api.KclType(\11\24\3 \1\
\3val\18\17(\8\24\4 \1\
\9any_other\
\14IndexSignature\"•\1\26/:\0028\1\18\11(\9\24\1 \1\
\3key\18\13(\9\24\2 \1\
\5value\
\13KeywordsEntry\18\12(\9\24\1 \1\
\4name\18\17(\9\24\2 \3\
\9arguments\01862$.com.kcl.api.Decorator.KeywordsEntry(\11\24\3 \3\
\8keywords\
\9Decorator\">\18\15(\9\24\1 \1\
\7summary\18\19(\9\24\2 \1\
\11description\18\13(\9\24\3 \1\
\5value\
\7ExampleB\20Z\5.;apiª\2\
KclLib.API"