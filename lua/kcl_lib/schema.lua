return "\
ñK\"1\
\11ExternalPkg\18\16\24\1 \1\
\8pkg_name(\9\18\16\24\2 \1\
\8pkg_path(\9\"'\
\8Argument\18\12\24\1 \1\
\4name(\9\18\13\24\2 \1\
\5value(\9\"L\
\5Error\18\13\24\1 \1\
\5level(\9\18\12\24\2 \1\
\4code(\9\18&\24\3 \3\
\8messages(\0112\20.com.kcl.api.Message\":\
\7Message\18\11\24\1 \1\
\3msg(\9\18\"\24\2 \1\
\3pos(\0112\21.com.kcl.api.Position\"\25\
\8PingArgs\18\13\24\1 \1\
\5value(\9\"\27\
\
PingResult\18\13\24\1 \1\
\5value(\9\"\16\
\14GetVersionArgs\"\\\
\16GetVersionResult\18\15\24\1 \1\
\7version(\9\18\16\24\2 \1\
\8checksum(\9\18\15\24\3 \1\
\7git_sha(\9\18\20\24\4 \1\
\12version_info(\9\"\16\
\14ListMethodArgs\",\
\16ListMethodResult\18\24\24\1 \3\
\16method_name_list(\9\"^\
\13ParseFileArgs\18\12\24\1 \1\
\4path(\9\18\14\24\2 \1\
\6source(\9\18/\24\3 \3\
\13external_pkgs(\0112\24.com.kcl.api.ExternalPkg\"U\
\15ParseFileResult\18\16\24\1 \1\
\8ast_json(\9\18\12\24\2 \3\
\4deps(\9\18\"\24\3 \3\
\6errors(\0112\18.com.kcl.api.Error\"c\
\16ParseProgramArgs\18\13\24\1 \3\
\5paths(\9\18\15\24\2 \3\
\7sources(\9\18/\24\3 \3\
\13external_pkgs(\0112\24.com.kcl.api.ExternalPkg\"Y\
\18ParseProgramResult\18\16\24\1 \1\
\8ast_json(\9\18\13\24\2 \3\
\5paths(\9\18\"\24\3 \3\
\6errors(\0112\18.com.kcl.api.Error\"‡\1\
\15LoadPackageArgs\0181\24\1 \1\
\
parse_args(\0112\29.com.kcl.api.ParseProgramArgs\18\19\24\2 \1\
\11resolve_ast(\8\18\20\24\3 \1\
\12load_builtin(\8\18\22\24\4 \1\
\14with_ast_index(\8\"ð\7\
\17LoadPackageResult\18\15\24\1 \1\
\7program(\9\18\13\24\2 \3\
\5paths(\9\18(\24\3 \3\
\12parse_errors(\0112\18.com.kcl.api.Error\18'\24\4 \3\
\11type_errors(\0112\18.com.kcl.api.Error\18:\24\5 \3\
\6scopes(\0112*.com.kcl.api.LoadPackageResult.ScopesEntry\18<\24\6 \3\
\7symbols(\0112+.com.kcl.api.LoadPackageResult.SymbolsEntry\18J\24\7 \3\
\15node_symbol_map(\01121.com.kcl.api.LoadPackageResult.NodeSymbolMapEntry\18J\24\8 \3\
\15symbol_node_map(\01121.com.kcl.api.LoadPackageResult.SymbolNodeMapEntry\18[\24\9 \3\
\24fully_qualified_name_map(\01129.com.kcl.api.LoadPackageResult.FullyQualifiedNameMapEntry\18F\24\
 \3\
\13pkg_scope_map(\0112/.com.kcl.api.LoadPackageResult.PkgScopeMapEntry\26A\
\11ScopesEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18!\24\2 \1\
\5value(\0112\18.com.kcl.api.Scope\26C\
\12SymbolsEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18\"\24\2 \1\
\5value(\0112\19.com.kcl.api.Symbol\26N\
\18NodeSymbolMapEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18'\24\2 \1\
\5value(\0112\24.com.kcl.api.SymbolIndex\0264\
\18SymbolNodeMapEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18\13\24\2 \1\
\5value(\9\26V\
\26FullyQualifiedNameMapEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18'\24\2 \1\
\5value(\0112\24.com.kcl.api.SymbolIndex\26K\
\16PkgScopeMapEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18&\24\2 \1\
\5value(\0112\23.com.kcl.api.ScopeIndex\"=\
\17ListOptionsResult\18(\24\2 \3\
\7options(\0112\23.com.kcl.api.OptionHelp\"_\
\
OptionHelp\18\12\24\1 \1\
\4name(\9\18\12\24\2 \1\
\4type(\9\18\16\24\3 \1\
\8required(\8\18\21\24\4 \1\
\13default_value(\9\18\12\24\5 \1\
\4help(\9\"Ä\1\
\6Symbol\18 \24\1 \1\
\2ty(\0112\20.com.kcl.api.KclType\18\12\24\2 \1\
\4name(\9\18'\24\3 \1\
\5owner(\0112\24.com.kcl.api.SymbolIndex\18%\24\4 \1\
\3def(\0112\24.com.kcl.api.SymbolIndex\18'\24\5 \3\
\5attrs(\0112\24.com.kcl.api.SymbolIndex\18\17\24\6 \1\
\9is_global(\8\"º\1\
\5Scope\18\12\24\1 \1\
\4kind(\9\18'\24\2 \1\
\6parent(\0112\23.com.kcl.api.ScopeIndex\18'\24\3 \1\
\5owner(\0112\24.com.kcl.api.SymbolIndex\18)\24\4 \3\
\8children(\0112\23.com.kcl.api.ScopeIndex\18&\24\5 \3\
\4defs(\0112\24.com.kcl.api.SymbolIndex\"1\
\11SymbolIndex\18\9\24\1 \1\
\1i(\4\18\9\24\2 \1\
\1g(\4\18\12\24\3 \1\
\4kind(\9\"0\
\
ScopeIndex\18\9\24\1 \1\
\1i(\4\18\9\24\2 \1\
\1g(\4\18\12\24\3 \1\
\4kind(\9\"¦\4\
\15ExecProgramArgsB\19\
\17_sourcemap_output\18\16\24\1 \1\
\8work_dir(\9\18\23\24\2 \3\
\15k_filename_list(\9\18\19\24\3 \3\
\11k_code_list(\9\18#\24\4 \3\
\4args(\0112\21.com.kcl.api.Argument\18\17\24\5 \3\
\9overrides(\9\18\27\24\6 \1\
\19disable_yaml_result(\8\18\26\24\7 \1\
\18print_override_ast(\8\18\26\24\8 \1\
\18strict_range_check(\8\18\20\24\9 \1\
\12disable_none(\8\18\15\24\
 \1\
\7verbose(\5\18\13\24\11 \1\
\5debug(\5\18\17\24\12 \1\
\9sort_keys(\8\18/\24\13 \3\
\13external_pkgs(\0112\24.com.kcl.api.ExternalPkg\18 \24\14 \1\
\24include_schema_type_path(\8\18\20\24\15 \1\
\12compile_only(\8\18\19\24\16 \1\
\11show_hidden(\8\18\21\24\17 \3\
\13path_selector(\9\18\17\24\18 \1\
\9fast_eval(\8\18\20\24\19 \1\
\12error_format(\9\18\14\24\20 \1\
\6format(\9\18\26\24\22 \1\
\16sourcemap_output(\9H\0\"Š\1\
\17ExecProgramResultB\12\
\
_sourcemap\18\19\24\1 \1\
\11json_result(\9\18\19\24\2 \1\
\11yaml_result(\9\18\19\24\3 \1\
\11log_message(\9\18\19\24\4 \1\
\11err_message(\9\18\19\24\5 \1\
\9sourcemap(\9H\0\" \
\14FormatCodeArgs\18\14\24\1 \1\
\6source(\9\"%\
\16FormatCodeResult\18\17\24\1 \1\
\9formatted(\12\"/\
\14FormatPathArgs\18\12\24\1 \1\
\4path(\9\18\15\24\2 \1\
\7dry_run(\8\")\
\16FormatPathResult\18\21\24\1 \3\
\13changed_paths(\9\"\29\
\12LintPathArgs\18\13\24\1 \3\
\5paths(\9\"!\
\14LintPathResult\18\15\24\1 \3\
\7results(\9\"E\
\16OverrideFileArgs\18\12\24\1 \1\
\4file(\9\18\13\24\2 \3\
\5specs(\9\18\20\24\3 \3\
\12import_paths(\9\"N\
\18OverrideFileResult\18\14\24\1 \1\
\6result(\8\18(\24\2 \3\
\12parse_errors(\0112\18.com.kcl.api.Error\"-\
\20ListVariablesOptions\18\21\24\1 \1\
\13merge_program(\8\"8\
\12VariableList\18(\24\1 \3\
\9variables(\0112\21.com.kcl.api.Variable\"e\
\17ListVariablesArgs\18\13\24\1 \3\
\5files(\9\18\13\24\2 \3\
\5specs(\9\0182\24\3 \1\
\7options(\0112!.com.kcl.api.ListVariablesOptions\"ë\1\
\19ListVariablesResult\18B\24\1 \3\
\9variables(\0112/.com.kcl.api.ListVariablesResult.VariablesEntry\18\25\24\2 \3\
\17unsupported_codes(\9\18(\24\3 \3\
\12parse_errors(\0112\18.com.kcl.api.Error\26K\
\14VariablesEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18(\24\2 \1\
\5value(\0112\25.com.kcl.api.VariableList\"”\1\
\8Variable\18\13\24\1 \1\
\5value(\9\18\17\24\2 \1\
\9type_name(\9\18\14\24\3 \1\
\6op_sym(\9\18)\24\4 \3\
\
list_items(\0112\21.com.kcl.api.Variable\18+\24\5 \3\
\12dict_entries(\0112\21.com.kcl.api.MapEntry\"=\
\8MapEntry\18\11\24\1 \1\
\3key(\9\18$\24\2 \1\
\5value(\0112\21.com.kcl.api.Variable\"`\
\24GetSchemaTypeMappingArgs\18/\24\1 \1\
\9exec_args(\0112\28.com.kcl.api.ExecProgramArgs\18\19\24\2 \1\
\11schema_name(\9\"É\1\
\26GetSchemaTypeMappingResult\18[\24\1 \3\
\19schema_type_mapping(\0112>.com.kcl.api.GetSchemaTypeMappingResult.SchemaTypeMappingEntry\26N\
\22SchemaTypeMappingEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18#\24\2 \1\
\5value(\0112\20.com.kcl.api.KclType\"ß\1\
#GetSchemaTypeMappingUnderPathResult\18d\24\1 \3\
\19schema_type_mapping(\0112G.com.kcl.api.GetSchemaTypeMappingUnderPathResult.SchemaTypeMappingEntry\26R\
\22SchemaTypeMappingEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18'\24\2 \1\
\5value(\0112\24.com.kcl.api.SchemaTypes\"8\
\11SchemaTypes\18)\24\1 \3\
\11schema_type(\0112\20.com.kcl.api.KclType\"·\1\
\16ValidateCodeArgs\18\16\24\1 \1\
\8datafile(\9\18\12\24\2 \1\
\4data(\9\18\12\24\3 \1\
\4file(\9\18\12\24\4 \1\
\4code(\9\18\14\24\5 \1\
\6schema(\9\18\22\24\6 \1\
\14attribute_name(\9\18\14\24\7 \1\
\6format(\9\18/\24\8 \3\
\13external_pkgs(\0112\24.com.kcl.api.ExternalPkg\":\
\18ValidateCodeResult\18\15\24\1 \1\
\7success(\8\18\19\24\2 \1\
\11err_message(\9\":\
\8Position\18\12\24\1 \1\
\4line(\3\18\14\24\2 \1\
\6column(\3\18\16\24\3 \1\
\8filename(\9\"8\
\21LoadSettingsFilesArgs\18\16\24\1 \1\
\8work_dir(\9\18\13\24\2 \3\
\5files(\9\"z\
\23LoadSettingsFilesResult\18/\24\1 \1\
\15kcl_cli_configs(\0112\22.com.kcl.api.CliConfig\18.\24\2 \3\
\11kcl_options(\0112\25.com.kcl.api.KeyValuePair\"ƒ\2\
\9CliConfig\18\13\24\1 \3\
\5files(\9\18\14\24\2 \1\
\6output(\9\18\17\24\3 \3\
\9overrides(\9\18\21\24\4 \3\
\13path_selector(\9\18\26\24\5 \1\
\18strict_range_check(\8\18\20\24\6 \1\
\12disable_none(\8\18\15\24\7 \1\
\7verbose(\3\18\13\24\8 \1\
\5debug(\8\18\17\24\9 \1\
\9sort_keys(\8\18\19\24\
 \1\
\11show_hidden(\8\18 \24\11 \1\
\24include_schema_type_path(\8\18\17\24\12 \1\
\9fast_eval(\8\"*\
\12KeyValuePair\18\11\24\1 \1\
\3key(\9\18\13\24\2 \1\
\5value(\9\"]\
\
RenameArgs\18\20\24\1 \1\
\12package_root(\9\18\19\24\2 \1\
\11symbol_path(\9\18\18\24\3 \3\
\
file_paths(\9\18\16\24\4 \1\
\8new_name(\9\"%\
\12RenameResult\18\21\24\1 \3\
\13changed_files(\9\"Å\1\
\14RenameCodeArgs\18\20\24\1 \1\
\12package_root(\9\18\19\24\2 \1\
\11symbol_path(\9\18B\24\3 \3\
\12source_codes(\0112,.com.kcl.api.RenameCodeArgs.SourceCodesEntry\18\16\24\4 \1\
\8new_name(\9\0262\
\16SourceCodesEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18\13\24\2 \1\
\5value(\9\"\1\
\16RenameCodeResult\18F\24\1 \3\
\13changed_codes(\0112/.com.kcl.api.RenameCodeResult.ChangedCodesEntry\0263\
\17ChangedCodesEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18\13\24\2 \1\
\5value(\9\"t\
\8TestArgs\18/\24\1 \1\
\9exec_args(\0112\28.com.kcl.api.ExecProgramArgs\18\16\24\2 \3\
\8pkg_list(\9\18\18\24\3 \1\
\
run_regexp(\9\18\17\24\4 \1\
\9fail_fast(\8\"5\
\
TestResult\18'\24\2 \3\
\4info(\0112\25.com.kcl.api.TestCaseInfo\"R\
\12TestCaseInfo\18\12\24\1 \1\
\4name(\9\18\13\24\2 \1\
\5error(\9\18\16\24\3 \1\
\8duration(\4\18\19\24\4 \1\
\11log_message(\9\"?\
\22UpdateDependenciesArgs\18\21\24\1 \1\
\13manifest_path(\9\18\14\24\2 \1\
\6vendor(\8\"K\
\24UpdateDependenciesResult\18/\24\3 \3\
\13external_pkgs(\0112\24.com.kcl.api.ExternalPkg\"û\5\
\7KclTypeB\11\
\9_functionB\18\
\16_index_signature\18\12\24\1 \1\
\4type(\9\18)\24\2 \3\
\11union_types(\0112\20.com.kcl.api.KclType\18\15\24\3 \1\
\7default(\9\18\19\24\4 \1\
\11schema_name(\9\18\18\24\5 \1\
\
schema_doc(\9\0188\24\6 \3\
\
properties(\0112$.com.kcl.api.KclType.PropertiesEntry\18\16\24\7 \3\
\8required(\9\18!\24\8 \1\
\3key(\0112\20.com.kcl.api.KclType\18\"\24\9 \1\
\4item(\0112\20.com.kcl.api.KclType\18\12\24\
 \1\
\4line(\5\18*\24\11 \3\
\
decorators(\0112\22.com.kcl.api.Decorator\18\16\24\12 \1\
\8filename(\9\18\16\24\13 \1\
\8pkg_path(\9\18\19\24\14 \1\
\11description(\9\0184\24\15 \3\
\8examples(\0112\".com.kcl.api.KclType.ExamplesEntry\18)\24\16 \1\
\11base_schema(\0112\20.com.kcl.api.KclType\18-\24\17 \1\
\8function(\11H\0002\25.com.kcl.api.FunctionType\0186\24\18 \1\
\15index_signature(\11H\0012\27.com.kcl.api.IndexSignature\26G\
\15PropertiesEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18#\24\2 \1\
\5value(\0112\20.com.kcl.api.KclType\26E\
\13ExamplesEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18#\24\2 \1\
\5value(\0112\20.com.kcl.api.Example\"_\
\12FunctionType\18&\24\1 \3\
\6params(\0112\22.com.kcl.api.Parameter\18'\24\2 \1\
\9return_ty(\0112\20.com.kcl.api.KclType\";\
\9Parameter\18\12\24\1 \1\
\4name(\9\18 \24\2 \1\
\2ty(\0112\20.com.kcl.api.KclType\"Š\1\
\14IndexSignatureB\11\
\9_key_name\18\18\24\1 \1\
\8key_name(\9H\0\18!\24\2 \1\
\3key(\0112\20.com.kcl.api.KclType\18!\24\3 \1\
\3val(\0112\20.com.kcl.api.KclType\18\17\24\4 \1\
\9any_other(\8\"•\1\
\9Decorator\18\12\24\1 \1\
\4name(\9\18\17\24\2 \3\
\9arguments(\9\0186\24\3 \3\
\8keywords(\0112$.com.kcl.api.Decorator.KeywordsEntry\26/\
\13KeywordsEntry:\0028\1\18\11\24\1 \1\
\3key(\9\18\13\24\2 \1\
\5value(\9\">\
\7Example\18\15\24\1 \1\
\7summary(\9\18\19\24\2 \1\
\11description(\9\18\13\24\3 \1\
\5value(\9b\6proto3B\20ª\2\
KclLib.APIZ\5.;api\
\
spec.proto2’\1\
\14BuiltinService\0186\
\4Ping\26\23.com.kcl.api.PingResult\18\21.com.kcl.api.PingArgs\18H\
\
ListMethod\26\29.com.kcl.api.ListMethodResult\18\27.com.kcl.api.ListMethodArgs2»\12\
\
KclService\0186\
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
\18UpdateDependencies\26%.com.kcl.api.UpdateDependenciesResult\18#.com.kcl.api.UpdateDependenciesArgs\18\11com.kcl.api"