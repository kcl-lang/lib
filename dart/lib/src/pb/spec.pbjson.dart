// This is a generated file - do not edit.
//
// Generated from spec.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use externalPkgDescriptor instead')
const ExternalPkg$json = {
  '1': 'ExternalPkg',
  '2': [
    {'1': 'pkg_name', '3': 1, '4': 1, '5': 9, '10': 'pkgName'},
    {'1': 'pkg_path', '3': 2, '4': 1, '5': 9, '10': 'pkgPath'},
  ],
};

/// Descriptor for `ExternalPkg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List externalPkgDescriptor = $convert.base64Decode(
    'CgtFeHRlcm5hbFBrZxIZCghwa2dfbmFtZRgBIAEoCVIHcGtnTmFtZRIZCghwa2dfcGF0aBgCIA'
    'EoCVIHcGtnUGF0aA==');

@$core.Deprecated('Use argumentDescriptor instead')
const Argument$json = {
  '1': 'Argument',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `Argument`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List argumentDescriptor = $convert.base64Decode(
    'CghBcmd1bWVudBISCgRuYW1lGAEgASgJUgRuYW1lEhQKBXZhbHVlGAIgASgJUgV2YWx1ZQ==');

@$core.Deprecated('Use errorDescriptor instead')
const Error$json = {
  '1': 'Error',
  '2': [
    {'1': 'level', '3': 1, '4': 1, '5': 9, '10': 'level'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
    {
      '1': 'messages',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Message',
      '10': 'messages'
    },
  ],
};

/// Descriptor for `Error`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorDescriptor = $convert.base64Decode(
    'CgVFcnJvchIUCgVsZXZlbBgBIAEoCVIFbGV2ZWwSEgoEY29kZRgCIAEoCVIEY29kZRIwCghtZX'
    'NzYWdlcxgDIAMoCzIULmNvbS5rY2wuYXBpLk1lc3NhZ2VSCG1lc3NhZ2Vz');

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {'1': 'msg', '3': 1, '4': 1, '5': 9, '10': 'msg'},
    {
      '1': 'pos',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.Position',
      '10': 'pos'
    },
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEhAKA21zZxgBIAEoCVIDbXNnEicKA3BvcxgCIAEoCzIVLmNvbS5rY2wuYXBpLl'
    'Bvc2l0aW9uUgNwb3M=');

@$core.Deprecated('Use pingArgsDescriptor instead')
const PingArgs$json = {
  '1': 'PingArgs',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `PingArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingArgsDescriptor =
    $convert.base64Decode('CghQaW5nQXJncxIUCgV2YWx1ZRgBIAEoCVIFdmFsdWU=');

@$core.Deprecated('Use pingResultDescriptor instead')
const PingResult$json = {
  '1': 'PingResult',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `PingResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResultDescriptor =
    $convert.base64Decode('CgpQaW5nUmVzdWx0EhQKBXZhbHVlGAEgASgJUgV2YWx1ZQ==');

@$core.Deprecated('Use getVersionArgsDescriptor instead')
const GetVersionArgs$json = {
  '1': 'GetVersionArgs',
};

/// Descriptor for `GetVersionArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getVersionArgsDescriptor =
    $convert.base64Decode('Cg5HZXRWZXJzaW9uQXJncw==');

@$core.Deprecated('Use getVersionResultDescriptor instead')
const GetVersionResult$json = {
  '1': 'GetVersionResult',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 9, '10': 'version'},
    {'1': 'checksum', '3': 2, '4': 1, '5': 9, '10': 'checksum'},
    {'1': 'git_sha', '3': 3, '4': 1, '5': 9, '10': 'gitSha'},
    {'1': 'version_info', '3': 4, '4': 1, '5': 9, '10': 'versionInfo'},
  ],
};

/// Descriptor for `GetVersionResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getVersionResultDescriptor = $convert.base64Decode(
    'ChBHZXRWZXJzaW9uUmVzdWx0EhgKB3ZlcnNpb24YASABKAlSB3ZlcnNpb24SGgoIY2hlY2tzdW'
    '0YAiABKAlSCGNoZWNrc3VtEhcKB2dpdF9zaGEYAyABKAlSBmdpdFNoYRIhCgx2ZXJzaW9uX2lu'
    'Zm8YBCABKAlSC3ZlcnNpb25JbmZv');

@$core.Deprecated('Use listMethodArgsDescriptor instead')
const ListMethodArgs$json = {
  '1': 'ListMethodArgs',
};

/// Descriptor for `ListMethodArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMethodArgsDescriptor =
    $convert.base64Decode('Cg5MaXN0TWV0aG9kQXJncw==');

@$core.Deprecated('Use listMethodResultDescriptor instead')
const ListMethodResult$json = {
  '1': 'ListMethodResult',
  '2': [
    {'1': 'method_name_list', '3': 1, '4': 3, '5': 9, '10': 'methodNameList'},
  ],
};

/// Descriptor for `ListMethodResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMethodResultDescriptor = $convert.base64Decode(
    'ChBMaXN0TWV0aG9kUmVzdWx0EigKEG1ldGhvZF9uYW1lX2xpc3QYASADKAlSDm1ldGhvZE5hbW'
    'VMaXN0');

@$core.Deprecated('Use parseFileArgsDescriptor instead')
const ParseFileArgs$json = {
  '1': 'ParseFileArgs',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'source', '3': 2, '4': 1, '5': 9, '10': 'source'},
    {
      '1': 'external_pkgs',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.ExternalPkg',
      '10': 'externalPkgs'
    },
  ],
};

/// Descriptor for `ParseFileArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parseFileArgsDescriptor = $convert.base64Decode(
    'Cg1QYXJzZUZpbGVBcmdzEhIKBHBhdGgYASABKAlSBHBhdGgSFgoGc291cmNlGAIgASgJUgZzb3'
    'VyY2USPQoNZXh0ZXJuYWxfcGtncxgDIAMoCzIYLmNvbS5rY2wuYXBpLkV4dGVybmFsUGtnUgxl'
    'eHRlcm5hbFBrZ3M=');

@$core.Deprecated('Use parseFileResultDescriptor instead')
const ParseFileResult$json = {
  '1': 'ParseFileResult',
  '2': [
    {'1': 'ast_json', '3': 1, '4': 1, '5': 9, '10': 'astJson'},
    {'1': 'deps', '3': 2, '4': 3, '5': 9, '10': 'deps'},
    {
      '1': 'errors',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Error',
      '10': 'errors'
    },
  ],
};

/// Descriptor for `ParseFileResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parseFileResultDescriptor = $convert.base64Decode(
    'Cg9QYXJzZUZpbGVSZXN1bHQSGQoIYXN0X2pzb24YASABKAlSB2FzdEpzb24SEgoEZGVwcxgCIA'
    'MoCVIEZGVwcxIqCgZlcnJvcnMYAyADKAsyEi5jb20ua2NsLmFwaS5FcnJvclIGZXJyb3Jz');

@$core.Deprecated('Use parseProgramArgsDescriptor instead')
const ParseProgramArgs$json = {
  '1': 'ParseProgramArgs',
  '2': [
    {'1': 'paths', '3': 1, '4': 3, '5': 9, '10': 'paths'},
    {'1': 'sources', '3': 2, '4': 3, '5': 9, '10': 'sources'},
    {
      '1': 'external_pkgs',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.ExternalPkg',
      '10': 'externalPkgs'
    },
  ],
};

/// Descriptor for `ParseProgramArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parseProgramArgsDescriptor = $convert.base64Decode(
    'ChBQYXJzZVByb2dyYW1BcmdzEhQKBXBhdGhzGAEgAygJUgVwYXRocxIYCgdzb3VyY2VzGAIgAy'
    'gJUgdzb3VyY2VzEj0KDWV4dGVybmFsX3BrZ3MYAyADKAsyGC5jb20ua2NsLmFwaS5FeHRlcm5h'
    'bFBrZ1IMZXh0ZXJuYWxQa2dz');

@$core.Deprecated('Use parseProgramResultDescriptor instead')
const ParseProgramResult$json = {
  '1': 'ParseProgramResult',
  '2': [
    {'1': 'ast_json', '3': 1, '4': 1, '5': 9, '10': 'astJson'},
    {'1': 'paths', '3': 2, '4': 3, '5': 9, '10': 'paths'},
    {
      '1': 'errors',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Error',
      '10': 'errors'
    },
  ],
};

/// Descriptor for `ParseProgramResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parseProgramResultDescriptor = $convert.base64Decode(
    'ChJQYXJzZVByb2dyYW1SZXN1bHQSGQoIYXN0X2pzb24YASABKAlSB2FzdEpzb24SFAoFcGF0aH'
    'MYAiADKAlSBXBhdGhzEioKBmVycm9ycxgDIAMoCzISLmNvbS5rY2wuYXBpLkVycm9yUgZlcnJv'
    'cnM=');

@$core.Deprecated('Use loadPackageArgsDescriptor instead')
const LoadPackageArgs$json = {
  '1': 'LoadPackageArgs',
  '2': [
    {
      '1': 'parse_args',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ParseProgramArgs',
      '10': 'parseArgs'
    },
    {'1': 'resolve_ast', '3': 2, '4': 1, '5': 8, '10': 'resolveAst'},
    {'1': 'load_builtin', '3': 3, '4': 1, '5': 8, '10': 'loadBuiltin'},
    {'1': 'with_ast_index', '3': 4, '4': 1, '5': 8, '10': 'withAstIndex'},
  ],
};

/// Descriptor for `LoadPackageArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadPackageArgsDescriptor = $convert.base64Decode(
    'Cg9Mb2FkUGFja2FnZUFyZ3MSPAoKcGFyc2VfYXJncxgBIAEoCzIdLmNvbS5rY2wuYXBpLlBhcn'
    'NlUHJvZ3JhbUFyZ3NSCXBhcnNlQXJncxIfCgtyZXNvbHZlX2FzdBgCIAEoCFIKcmVzb2x2ZUFz'
    'dBIhCgxsb2FkX2J1aWx0aW4YAyABKAhSC2xvYWRCdWlsdGluEiQKDndpdGhfYXN0X2luZGV4GA'
    'QgASgIUgx3aXRoQXN0SW5kZXg=');

@$core.Deprecated('Use loadPackageResultDescriptor instead')
const LoadPackageResult$json = {
  '1': 'LoadPackageResult',
  '2': [
    {'1': 'program', '3': 1, '4': 1, '5': 9, '10': 'program'},
    {'1': 'paths', '3': 2, '4': 3, '5': 9, '10': 'paths'},
    {
      '1': 'parse_errors',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Error',
      '10': 'parseErrors'
    },
    {
      '1': 'type_errors',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Error',
      '10': 'typeErrors'
    },
    {
      '1': 'scopes',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.LoadPackageResult.ScopesEntry',
      '10': 'scopes'
    },
    {
      '1': 'symbols',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.LoadPackageResult.SymbolsEntry',
      '10': 'symbols'
    },
    {
      '1': 'node_symbol_map',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.LoadPackageResult.NodeSymbolMapEntry',
      '10': 'nodeSymbolMap'
    },
    {
      '1': 'symbol_node_map',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.LoadPackageResult.SymbolNodeMapEntry',
      '10': 'symbolNodeMap'
    },
    {
      '1': 'fully_qualified_name_map',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.LoadPackageResult.FullyQualifiedNameMapEntry',
      '10': 'fullyQualifiedNameMap'
    },
    {
      '1': 'pkg_scope_map',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.LoadPackageResult.PkgScopeMapEntry',
      '10': 'pkgScopeMap'
    },
    {
      '1': 'imports',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.LoadPackageResult.ImportsEntry',
      '10': 'imports'
    },
    {
      '1': 'kcl_mod',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclMod',
      '10': 'kclMod'
    },
    {
      '1': 'apps',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.AppInfo',
      '10': 'apps'
    },
  ],
  '3': [
    LoadPackageResult_ScopesEntry$json,
    LoadPackageResult_SymbolsEntry$json,
    LoadPackageResult_NodeSymbolMapEntry$json,
    LoadPackageResult_SymbolNodeMapEntry$json,
    LoadPackageResult_FullyQualifiedNameMapEntry$json,
    LoadPackageResult_PkgScopeMapEntry$json,
    LoadPackageResult_ImportsEntry$json
  ],
};

@$core.Deprecated('Use loadPackageResultDescriptor instead')
const LoadPackageResult_ScopesEntry$json = {
  '1': 'ScopesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.Scope',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use loadPackageResultDescriptor instead')
const LoadPackageResult_SymbolsEntry$json = {
  '1': 'SymbolsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.Symbol',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use loadPackageResultDescriptor instead')
const LoadPackageResult_NodeSymbolMapEntry$json = {
  '1': 'NodeSymbolMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.SymbolIndex',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use loadPackageResultDescriptor instead')
const LoadPackageResult_SymbolNodeMapEntry$json = {
  '1': 'SymbolNodeMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use loadPackageResultDescriptor instead')
const LoadPackageResult_FullyQualifiedNameMapEntry$json = {
  '1': 'FullyQualifiedNameMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.SymbolIndex',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use loadPackageResultDescriptor instead')
const LoadPackageResult_PkgScopeMapEntry$json = {
  '1': 'PkgScopeMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ScopeIndex',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use loadPackageResultDescriptor instead')
const LoadPackageResult_ImportsEntry$json = {
  '1': 'ImportsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.FileImports',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `LoadPackageResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadPackageResultDescriptor = $convert.base64Decode(
    'ChFMb2FkUGFja2FnZVJlc3VsdBIYCgdwcm9ncmFtGAEgASgJUgdwcm9ncmFtEhQKBXBhdGhzGA'
    'IgAygJUgVwYXRocxI1CgxwYXJzZV9lcnJvcnMYAyADKAsyEi5jb20ua2NsLmFwaS5FcnJvclIL'
    'cGFyc2VFcnJvcnMSMwoLdHlwZV9lcnJvcnMYBCADKAsyEi5jb20ua2NsLmFwaS5FcnJvclIKdH'
    'lwZUVycm9ycxJCCgZzY29wZXMYBSADKAsyKi5jb20ua2NsLmFwaS5Mb2FkUGFja2FnZVJlc3Vs'
    'dC5TY29wZXNFbnRyeVIGc2NvcGVzEkUKB3N5bWJvbHMYBiADKAsyKy5jb20ua2NsLmFwaS5Mb2'
    'FkUGFja2FnZVJlc3VsdC5TeW1ib2xzRW50cnlSB3N5bWJvbHMSWQoPbm9kZV9zeW1ib2xfbWFw'
    'GAcgAygLMjEuY29tLmtjbC5hcGkuTG9hZFBhY2thZ2VSZXN1bHQuTm9kZVN5bWJvbE1hcEVudH'
    'J5Ug1ub2RlU3ltYm9sTWFwElkKD3N5bWJvbF9ub2RlX21hcBgIIAMoCzIxLmNvbS5rY2wuYXBp'
    'LkxvYWRQYWNrYWdlUmVzdWx0LlN5bWJvbE5vZGVNYXBFbnRyeVINc3ltYm9sTm9kZU1hcBJyCh'
    'hmdWxseV9xdWFsaWZpZWRfbmFtZV9tYXAYCSADKAsyOS5jb20ua2NsLmFwaS5Mb2FkUGFja2Fn'
    'ZVJlc3VsdC5GdWxseVF1YWxpZmllZE5hbWVNYXBFbnRyeVIVZnVsbHlRdWFsaWZpZWROYW1lTW'
    'FwElMKDXBrZ19zY29wZV9tYXAYCiADKAsyLy5jb20ua2NsLmFwaS5Mb2FkUGFja2FnZVJlc3Vs'
    'dC5Qa2dTY29wZU1hcEVudHJ5Ugtwa2dTY29wZU1hcBJFCgdpbXBvcnRzGAsgAygLMisuY29tLm'
    'tjbC5hcGkuTG9hZFBhY2thZ2VSZXN1bHQuSW1wb3J0c0VudHJ5UgdpbXBvcnRzEiwKB2tjbF9t'
    'b2QYDCABKAsyEy5jb20ua2NsLmFwaS5LY2xNb2RSBmtjbE1vZBIoCgRhcHBzGA0gAygLMhQuY2'
    '9tLmtjbC5hcGkuQXBwSW5mb1IEYXBwcxpNCgtTY29wZXNFbnRyeRIQCgNrZXkYASABKAlSA2tl'
    'eRIoCgV2YWx1ZRgCIAEoCzISLmNvbS5rY2wuYXBpLlNjb3BlUgV2YWx1ZToCOAEaTwoMU3ltYm'
    '9sc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EikKBXZhbHVlGAIgASgLMhMuY29tLmtjbC5hcGku'
    'U3ltYm9sUgV2YWx1ZToCOAEaWgoSTm9kZVN5bWJvbE1hcEVudHJ5EhAKA2tleRgBIAEoCVIDa2'
    'V5Ei4KBXZhbHVlGAIgASgLMhguY29tLmtjbC5hcGkuU3ltYm9sSW5kZXhSBXZhbHVlOgI4ARpA'
    'ChJTeW1ib2xOb2RlTWFwRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBX'
    'ZhbHVlOgI4ARpiChpGdWxseVF1YWxpZmllZE5hbWVNYXBFbnRyeRIQCgNrZXkYASABKAlSA2tl'
    'eRIuCgV2YWx1ZRgCIAEoCzIYLmNvbS5rY2wuYXBpLlN5bWJvbEluZGV4UgV2YWx1ZToCOAEaVw'
    'oQUGtnU2NvcGVNYXBFbnRyeRIQCgNrZXkYASABKAlSA2tleRItCgV2YWx1ZRgCIAEoCzIXLmNv'
    'bS5rY2wuYXBpLlNjb3BlSW5kZXhSBXZhbHVlOgI4ARpUCgxJbXBvcnRzRW50cnkSEAoDa2V5GA'
    'EgASgJUgNrZXkSLgoFdmFsdWUYAiABKAsyGC5jb20ua2NsLmFwaS5GaWxlSW1wb3J0c1IFdmFs'
    'dWU6AjgB');

@$core.Deprecated('Use fileImportsDescriptor instead')
const FileImports$json = {
  '1': 'FileImports',
  '2': [
    {
      '1': 'imports',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.ImportInfo',
      '10': 'imports'
    },
  ],
};

/// Descriptor for `FileImports`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileImportsDescriptor = $convert.base64Decode(
    'CgtGaWxlSW1wb3J0cxIxCgdpbXBvcnRzGAEgAygLMhcuY29tLmtjbC5hcGkuSW1wb3J0SW5mb1'
    'IHaW1wb3J0cw==');

@$core.Deprecated('Use importInfoDescriptor instead')
const ImportInfo$json = {
  '1': 'ImportInfo',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'resolved', '3': 2, '4': 1, '5': 9, '10': 'resolved'},
  ],
};

/// Descriptor for `ImportInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importInfoDescriptor = $convert.base64Decode(
    'CgpJbXBvcnRJbmZvEhIKBHBhdGgYASABKAlSBHBhdGgSGgoIcmVzb2x2ZWQYAiABKAlSCHJlc2'
    '9sdmVk');

@$core.Deprecated('Use kclModDescriptor instead')
const KclMod$json = {
  '1': 'KclMod',
  '2': [
    {
      '1': 'package',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclModPackage',
      '10': 'package'
    },
    {
      '1': 'profile',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclModProfile',
      '10': 'profile'
    },
    {
      '1': 'dependencies',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.KclMod.DependenciesEntry',
      '10': 'dependencies'
    },
  ],
  '3': [KclMod_DependenciesEntry$json],
};

@$core.Deprecated('Use kclModDescriptor instead')
const KclMod_DependenciesEntry$json = {
  '1': 'DependenciesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclModDependency',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `KclMod`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kclModDescriptor = $convert.base64Decode(
    'CgZLY2xNb2QSNAoHcGFja2FnZRgBIAEoCzIaLmNvbS5rY2wuYXBpLktjbE1vZFBhY2thZ2VSB3'
    'BhY2thZ2USNAoHcHJvZmlsZRgCIAEoCzIaLmNvbS5rY2wuYXBpLktjbE1vZFByb2ZpbGVSB3By'
    'b2ZpbGUSSQoMZGVwZW5kZW5jaWVzGAMgAygLMiUuY29tLmtjbC5hcGkuS2NsTW9kLkRlcGVuZG'
    'VuY2llc0VudHJ5UgxkZXBlbmRlbmNpZXMaXgoRRGVwZW5kZW5jaWVzRW50cnkSEAoDa2V5GAEg'
    'ASgJUgNrZXkSMwoFdmFsdWUYAiABKAsyHS5jb20ua2NsLmFwaS5LY2xNb2REZXBlbmRlbmN5Ug'
    'V2YWx1ZToCOAE=');

@$core.Deprecated('Use kclModPackageDescriptor instead')
const KclModPackage$json = {
  '1': 'KclModPackage',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'edition', '3': 2, '4': 1, '5': 9, '10': 'edition'},
    {'1': 'version', '3': 3, '4': 1, '5': 9, '10': 'version'},
    {'1': 'description', '3': 4, '4': 1, '5': 9, '10': 'description'},
    {'1': 'include', '3': 5, '4': 3, '5': 9, '10': 'include'},
    {'1': 'exclude', '3': 6, '4': 3, '5': 9, '10': 'exclude'},
  ],
};

/// Descriptor for `KclModPackage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kclModPackageDescriptor = $convert.base64Decode(
    'Cg1LY2xNb2RQYWNrYWdlEhIKBG5hbWUYASABKAlSBG5hbWUSGAoHZWRpdGlvbhgCIAEoCVIHZW'
    'RpdGlvbhIYCgd2ZXJzaW9uGAMgASgJUgd2ZXJzaW9uEiAKC2Rlc2NyaXB0aW9uGAQgASgJUgtk'
    'ZXNjcmlwdGlvbhIYCgdpbmNsdWRlGAUgAygJUgdpbmNsdWRlEhgKB2V4Y2x1ZGUYBiADKAlSB2'
    'V4Y2x1ZGU=');

@$core.Deprecated('Use kclModProfileDescriptor instead')
const KclModProfile$json = {
  '1': 'KclModProfile',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 9, '10': 'entries'},
    {'1': 'disable_none', '3': 2, '4': 1, '5': 8, '10': 'disableNone'},
    {'1': 'sort_keys', '3': 3, '4': 1, '5': 8, '10': 'sortKeys'},
    {'1': 'selectors', '3': 4, '4': 3, '5': 9, '10': 'selectors'},
    {'1': 'overrides', '3': 5, '4': 3, '5': 9, '10': 'overrides'},
    {'1': 'options', '3': 6, '4': 3, '5': 9, '10': 'options'},
  ],
};

/// Descriptor for `KclModProfile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kclModProfileDescriptor = $convert.base64Decode(
    'Cg1LY2xNb2RQcm9maWxlEhgKB2VudHJpZXMYASADKAlSB2VudHJpZXMSIQoMZGlzYWJsZV9ub2'
    '5lGAIgASgIUgtkaXNhYmxlTm9uZRIbCglzb3J0X2tleXMYAyABKAhSCHNvcnRLZXlzEhwKCXNl'
    'bGVjdG9ycxgEIAMoCVIJc2VsZWN0b3JzEhwKCW92ZXJyaWRlcxgFIAMoCVIJb3ZlcnJpZGVzEh'
    'gKB29wdGlvbnMYBiADKAlSB29wdGlvbnM=');

@$core.Deprecated('Use kclModDependencyDescriptor instead')
const KclModDependency$json = {
  '1': 'KclModDependency',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 9, '10': 'version'},
    {
      '1': 'git',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclModGitSource',
      '10': 'git'
    },
    {
      '1': 'oci',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclModOciSource',
      '10': 'oci'
    },
    {
      '1': 'local',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclModLocalSource',
      '10': 'local'
    },
  ],
};

/// Descriptor for `KclModDependency`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kclModDependencyDescriptor = $convert.base64Decode(
    'ChBLY2xNb2REZXBlbmRlbmN5EhgKB3ZlcnNpb24YASABKAlSB3ZlcnNpb24SLgoDZ2l0GAIgAS'
    'gLMhwuY29tLmtjbC5hcGkuS2NsTW9kR2l0U291cmNlUgNnaXQSLgoDb2NpGAMgASgLMhwuY29t'
    'LmtjbC5hcGkuS2NsTW9kT2NpU291cmNlUgNvY2kSNAoFbG9jYWwYBCABKAsyHi5jb20ua2NsLm'
    'FwaS5LY2xNb2RMb2NhbFNvdXJjZVIFbG9jYWw=');

@$core.Deprecated('Use kclModGitSourceDescriptor instead')
const KclModGitSource$json = {
  '1': 'KclModGitSource',
  '2': [
    {'1': 'git', '3': 1, '4': 1, '5': 9, '10': 'git'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'commit', '3': 3, '4': 1, '5': 9, '10': 'commit'},
    {'1': 'tag', '3': 4, '4': 1, '5': 9, '10': 'tag'},
    {'1': 'version', '3': 5, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `KclModGitSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kclModGitSourceDescriptor = $convert.base64Decode(
    'Cg9LY2xNb2RHaXRTb3VyY2USEAoDZ2l0GAEgASgJUgNnaXQSFgoGYnJhbmNoGAIgASgJUgZicm'
    'FuY2gSFgoGY29tbWl0GAMgASgJUgZjb21taXQSEAoDdGFnGAQgASgJUgN0YWcSGAoHdmVyc2lv'
    'bhgFIAEoCVIHdmVyc2lvbg==');

@$core.Deprecated('Use kclModOciSourceDescriptor instead')
const KclModOciSource$json = {
  '1': 'KclModOciSource',
  '2': [
    {'1': 'oci', '3': 1, '4': 1, '5': 9, '10': 'oci'},
    {'1': 'tag', '3': 2, '4': 1, '5': 9, '10': 'tag'},
  ],
};

/// Descriptor for `KclModOciSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kclModOciSourceDescriptor = $convert.base64Decode(
    'Cg9LY2xNb2RPY2lTb3VyY2USEAoDb2NpGAEgASgJUgNvY2kSEAoDdGFnGAIgASgJUgN0YWc=');

@$core.Deprecated('Use kclModLocalSourceDescriptor instead')
const KclModLocalSource$json = {
  '1': 'KclModLocalSource',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `KclModLocalSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kclModLocalSourceDescriptor = $convert
    .base64Decode('ChFLY2xNb2RMb2NhbFNvdXJjZRISCgRwYXRoGAEgASgJUgRwYXRo');

@$core.Deprecated('Use appInfoDescriptor instead')
const AppInfo$json = {
  '1': 'AppInfo',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'has_kcl_mod', '3': 2, '4': 1, '5': 8, '10': 'hasKclMod'},
  ],
};

/// Descriptor for `AppInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appInfoDescriptor = $convert.base64Decode(
    'CgdBcHBJbmZvEhIKBHBhdGgYASABKAlSBHBhdGgSHgoLaGFzX2tjbF9tb2QYAiABKAhSCWhhc0'
    'tjbE1vZA==');

@$core.Deprecated('Use listOptionsResultDescriptor instead')
const ListOptionsResult$json = {
  '1': 'ListOptionsResult',
  '2': [
    {
      '1': 'options',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.OptionHelp',
      '10': 'options'
    },
  ],
};

/// Descriptor for `ListOptionsResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listOptionsResultDescriptor = $convert.base64Decode(
    'ChFMaXN0T3B0aW9uc1Jlc3VsdBIxCgdvcHRpb25zGAIgAygLMhcuY29tLmtjbC5hcGkuT3B0aW'
    '9uSGVscFIHb3B0aW9ucw==');

@$core.Deprecated('Use optionHelpDescriptor instead')
const OptionHelp$json = {
  '1': 'OptionHelp',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type', '3': 2, '4': 1, '5': 9, '10': 'type'},
    {'1': 'required', '3': 3, '4': 1, '5': 8, '10': 'required'},
    {'1': 'default_value', '3': 4, '4': 1, '5': 9, '10': 'defaultValue'},
    {'1': 'help', '3': 5, '4': 1, '5': 9, '10': 'help'},
  ],
};

/// Descriptor for `OptionHelp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List optionHelpDescriptor = $convert.base64Decode(
    'CgpPcHRpb25IZWxwEhIKBG5hbWUYASABKAlSBG5hbWUSEgoEdHlwZRgCIAEoCVIEdHlwZRIaCg'
    'hyZXF1aXJlZBgDIAEoCFIIcmVxdWlyZWQSIwoNZGVmYXVsdF92YWx1ZRgEIAEoCVIMZGVmYXVs'
    'dFZhbHVlEhIKBGhlbHAYBSABKAlSBGhlbHA=');

@$core.Deprecated('Use symbolDescriptor instead')
const Symbol$json = {
  '1': 'Symbol',
  '2': [
    {
      '1': 'ty',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'ty'
    },
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'owner',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.SymbolIndex',
      '10': 'owner'
    },
    {
      '1': 'def',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.SymbolIndex',
      '10': 'def'
    },
    {
      '1': 'attrs',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.SymbolIndex',
      '10': 'attrs'
    },
    {'1': 'is_global', '3': 6, '4': 1, '5': 8, '10': 'isGlobal'},
  ],
};

/// Descriptor for `Symbol`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List symbolDescriptor = $convert.base64Decode(
    'CgZTeW1ib2wSJAoCdHkYASABKAsyFC5jb20ua2NsLmFwaS5LY2xUeXBlUgJ0eRISCgRuYW1lGA'
    'IgASgJUgRuYW1lEi4KBW93bmVyGAMgASgLMhguY29tLmtjbC5hcGkuU3ltYm9sSW5kZXhSBW93'
    'bmVyEioKA2RlZhgEIAEoCzIYLmNvbS5rY2wuYXBpLlN5bWJvbEluZGV4UgNkZWYSLgoFYXR0cn'
    'MYBSADKAsyGC5jb20ua2NsLmFwaS5TeW1ib2xJbmRleFIFYXR0cnMSGwoJaXNfZ2xvYmFsGAYg'
    'ASgIUghpc0dsb2JhbA==');

@$core.Deprecated('Use scopeDescriptor instead')
const Scope$json = {
  '1': 'Scope',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    {
      '1': 'parent',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ScopeIndex',
      '10': 'parent'
    },
    {
      '1': 'owner',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.SymbolIndex',
      '10': 'owner'
    },
    {
      '1': 'children',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.ScopeIndex',
      '10': 'children'
    },
    {
      '1': 'defs',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.SymbolIndex',
      '10': 'defs'
    },
  ],
};

/// Descriptor for `Scope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scopeDescriptor = $convert.base64Decode(
    'CgVTY29wZRISCgRraW5kGAEgASgJUgRraW5kEi8KBnBhcmVudBgCIAEoCzIXLmNvbS5rY2wuYX'
    'BpLlNjb3BlSW5kZXhSBnBhcmVudBIuCgVvd25lchgDIAEoCzIYLmNvbS5rY2wuYXBpLlN5bWJv'
    'bEluZGV4UgVvd25lchIzCghjaGlsZHJlbhgEIAMoCzIXLmNvbS5rY2wuYXBpLlNjb3BlSW5kZX'
    'hSCGNoaWxkcmVuEiwKBGRlZnMYBSADKAsyGC5jb20ua2NsLmFwaS5TeW1ib2xJbmRleFIEZGVm'
    'cw==');

@$core.Deprecated('Use symbolIndexDescriptor instead')
const SymbolIndex$json = {
  '1': 'SymbolIndex',
  '2': [
    {'1': 'i', '3': 1, '4': 1, '5': 4, '10': 'i'},
    {'1': 'g', '3': 2, '4': 1, '5': 4, '10': 'g'},
    {'1': 'kind', '3': 3, '4': 1, '5': 9, '10': 'kind'},
  ],
};

/// Descriptor for `SymbolIndex`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List symbolIndexDescriptor = $convert.base64Decode(
    'CgtTeW1ib2xJbmRleBIMCgFpGAEgASgEUgFpEgwKAWcYAiABKARSAWcSEgoEa2luZBgDIAEoCV'
    'IEa2luZA==');

@$core.Deprecated('Use scopeIndexDescriptor instead')
const ScopeIndex$json = {
  '1': 'ScopeIndex',
  '2': [
    {'1': 'i', '3': 1, '4': 1, '5': 4, '10': 'i'},
    {'1': 'g', '3': 2, '4': 1, '5': 4, '10': 'g'},
    {'1': 'kind', '3': 3, '4': 1, '5': 9, '10': 'kind'},
  ],
};

/// Descriptor for `ScopeIndex`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scopeIndexDescriptor = $convert.base64Decode(
    'CgpTY29wZUluZGV4EgwKAWkYASABKARSAWkSDAoBZxgCIAEoBFIBZxISCgRraW5kGAMgASgJUg'
    'RraW5k');

@$core.Deprecated('Use execProgramArgsDescriptor instead')
const ExecProgramArgs$json = {
  '1': 'ExecProgramArgs',
  '2': [
    {'1': 'work_dir', '3': 1, '4': 1, '5': 9, '10': 'workDir'},
    {'1': 'k_filename_list', '3': 2, '4': 3, '5': 9, '10': 'kFilenameList'},
    {'1': 'k_code_list', '3': 3, '4': 3, '5': 9, '10': 'kCodeList'},
    {
      '1': 'args',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Argument',
      '10': 'args'
    },
    {'1': 'overrides', '3': 5, '4': 3, '5': 9, '10': 'overrides'},
    {
      '1': 'disable_yaml_result',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'disableYamlResult'
    },
    {
      '1': 'print_override_ast',
      '3': 7,
      '4': 1,
      '5': 8,
      '10': 'printOverrideAst'
    },
    {
      '1': 'strict_range_check',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'strictRangeCheck'
    },
    {'1': 'disable_none', '3': 9, '4': 1, '5': 8, '10': 'disableNone'},
    {'1': 'verbose', '3': 10, '4': 1, '5': 5, '10': 'verbose'},
    {'1': 'debug', '3': 11, '4': 1, '5': 5, '10': 'debug'},
    {'1': 'sort_keys', '3': 12, '4': 1, '5': 8, '10': 'sortKeys'},
    {
      '1': 'external_pkgs',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.ExternalPkg',
      '10': 'externalPkgs'
    },
    {
      '1': 'include_schema_type_path',
      '3': 14,
      '4': 1,
      '5': 8,
      '10': 'includeSchemaTypePath'
    },
    {'1': 'compile_only', '3': 15, '4': 1, '5': 8, '10': 'compileOnly'},
    {'1': 'show_hidden', '3': 16, '4': 1, '5': 8, '10': 'showHidden'},
    {'1': 'path_selector', '3': 17, '4': 3, '5': 9, '10': 'pathSelector'},
    {'1': 'fast_eval', '3': 18, '4': 1, '5': 8, '10': 'fastEval'},
    {'1': 'error_format', '3': 19, '4': 1, '5': 9, '10': 'errorFormat'},
    {'1': 'format', '3': 20, '4': 1, '5': 9, '10': 'format'},
    {
      '1': 'emit_attribute_metadata',
      '3': 21,
      '4': 1,
      '5': 8,
      '10': 'emitAttributeMetadata'
    },
    {
      '1': 'sourcemap_output',
      '3': 22,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'sourcemapOutput',
      '17': true
    },
  ],
  '8': [
    {'1': '_sourcemap_output'},
  ],
};

/// Descriptor for `ExecProgramArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List execProgramArgsDescriptor = $convert.base64Decode(
    'Cg9FeGVjUHJvZ3JhbUFyZ3MSGQoId29ya19kaXIYASABKAlSB3dvcmtEaXISJgoPa19maWxlbm'
    'FtZV9saXN0GAIgAygJUg1rRmlsZW5hbWVMaXN0Eh4KC2tfY29kZV9saXN0GAMgAygJUglrQ29k'
    'ZUxpc3QSKQoEYXJncxgEIAMoCzIVLmNvbS5rY2wuYXBpLkFyZ3VtZW50UgRhcmdzEhwKCW92ZX'
    'JyaWRlcxgFIAMoCVIJb3ZlcnJpZGVzEi4KE2Rpc2FibGVfeWFtbF9yZXN1bHQYBiABKAhSEWRp'
    'c2FibGVZYW1sUmVzdWx0EiwKEnByaW50X292ZXJyaWRlX2FzdBgHIAEoCFIQcHJpbnRPdmVycm'
    'lkZUFzdBIsChJzdHJpY3RfcmFuZ2VfY2hlY2sYCCABKAhSEHN0cmljdFJhbmdlQ2hlY2sSIQoM'
    'ZGlzYWJsZV9ub25lGAkgASgIUgtkaXNhYmxlTm9uZRIYCgd2ZXJib3NlGAogASgFUgd2ZXJib3'
    'NlEhQKBWRlYnVnGAsgASgFUgVkZWJ1ZxIbCglzb3J0X2tleXMYDCABKAhSCHNvcnRLZXlzEj0K'
    'DWV4dGVybmFsX3BrZ3MYDSADKAsyGC5jb20ua2NsLmFwaS5FeHRlcm5hbFBrZ1IMZXh0ZXJuYW'
    'xQa2dzEjcKGGluY2x1ZGVfc2NoZW1hX3R5cGVfcGF0aBgOIAEoCFIVaW5jbHVkZVNjaGVtYVR5'
    'cGVQYXRoEiEKDGNvbXBpbGVfb25seRgPIAEoCFILY29tcGlsZU9ubHkSHwoLc2hvd19oaWRkZW'
    '4YECABKAhSCnNob3dIaWRkZW4SIwoNcGF0aF9zZWxlY3RvchgRIAMoCVIMcGF0aFNlbGVjdG9y'
    'EhsKCWZhc3RfZXZhbBgSIAEoCFIIZmFzdEV2YWwSIQoMZXJyb3JfZm9ybWF0GBMgASgJUgtlcn'
    'JvckZvcm1hdBIWCgZmb3JtYXQYFCABKAlSBmZvcm1hdBI2ChdlbWl0X2F0dHJpYnV0ZV9tZXRh'
    'ZGF0YRgVIAEoCFIVZW1pdEF0dHJpYnV0ZU1ldGFkYXRhEi4KEHNvdXJjZW1hcF9vdXRwdXQYFi'
    'ABKAlIAFIPc291cmNlbWFwT3V0cHV0iAEBQhMKEV9zb3VyY2VtYXBfb3V0cHV0');

@$core.Deprecated('Use execProgramResultDescriptor instead')
const ExecProgramResult$json = {
  '1': 'ExecProgramResult',
  '2': [
    {'1': 'json_result', '3': 1, '4': 1, '5': 9, '10': 'jsonResult'},
    {'1': 'yaml_result', '3': 2, '4': 1, '5': 9, '10': 'yamlResult'},
    {'1': 'log_message', '3': 3, '4': 1, '5': 9, '10': 'logMessage'},
    {'1': 'err_message', '3': 4, '4': 1, '5': 9, '10': 'errMessage'},
    {
      '1': 'sourcemap',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'sourcemap',
      '17': true
    },
  ],
  '8': [
    {'1': '_sourcemap'},
  ],
};

/// Descriptor for `ExecProgramResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List execProgramResultDescriptor = $convert.base64Decode(
    'ChFFeGVjUHJvZ3JhbVJlc3VsdBIfCgtqc29uX3Jlc3VsdBgBIAEoCVIKanNvblJlc3VsdBIfCg'
    't5YW1sX3Jlc3VsdBgCIAEoCVIKeWFtbFJlc3VsdBIfCgtsb2dfbWVzc2FnZRgDIAEoCVIKbG9n'
    'TWVzc2FnZRIfCgtlcnJfbWVzc2FnZRgEIAEoCVIKZXJyTWVzc2FnZRIhCglzb3VyY2VtYXAYBS'
    'ABKAlIAFIJc291cmNlbWFwiAEBQgwKCl9zb3VyY2VtYXA=');

@$core.Deprecated('Use formatCodeArgsDescriptor instead')
const FormatCodeArgs$json = {
  '1': 'FormatCodeArgs',
  '2': [
    {'1': 'source', '3': 1, '4': 1, '5': 9, '10': 'source'},
  ],
};

/// Descriptor for `FormatCodeArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List formatCodeArgsDescriptor = $convert
    .base64Decode('Cg5Gb3JtYXRDb2RlQXJncxIWCgZzb3VyY2UYASABKAlSBnNvdXJjZQ==');

@$core.Deprecated('Use formatCodeResultDescriptor instead')
const FormatCodeResult$json = {
  '1': 'FormatCodeResult',
  '2': [
    {'1': 'formatted', '3': 1, '4': 1, '5': 12, '10': 'formatted'},
  ],
};

/// Descriptor for `FormatCodeResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List formatCodeResultDescriptor = $convert.base64Decode(
    'ChBGb3JtYXRDb2RlUmVzdWx0EhwKCWZvcm1hdHRlZBgBIAEoDFIJZm9ybWF0dGVk');

@$core.Deprecated('Use formatPathArgsDescriptor instead')
const FormatPathArgs$json = {
  '1': 'FormatPathArgs',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'dry_run', '3': 2, '4': 1, '5': 8, '10': 'dryRun'},
  ],
};

/// Descriptor for `FormatPathArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List formatPathArgsDescriptor = $convert.base64Decode(
    'Cg5Gb3JtYXRQYXRoQXJncxISCgRwYXRoGAEgASgJUgRwYXRoEhcKB2RyeV9ydW4YAiABKAhSBm'
    'RyeVJ1bg==');

@$core.Deprecated('Use formatPathResultDescriptor instead')
const FormatPathResult$json = {
  '1': 'FormatPathResult',
  '2': [
    {'1': 'changed_paths', '3': 1, '4': 3, '5': 9, '10': 'changedPaths'},
  ],
};

/// Descriptor for `FormatPathResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List formatPathResultDescriptor = $convert.base64Decode(
    'ChBGb3JtYXRQYXRoUmVzdWx0EiMKDWNoYW5nZWRfcGF0aHMYASADKAlSDGNoYW5nZWRQYXRocw'
    '==');

@$core.Deprecated('Use lintPathArgsDescriptor instead')
const LintPathArgs$json = {
  '1': 'LintPathArgs',
  '2': [
    {'1': 'paths', '3': 1, '4': 3, '5': 9, '10': 'paths'},
  ],
};

/// Descriptor for `LintPathArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lintPathArgsDescriptor =
    $convert.base64Decode('CgxMaW50UGF0aEFyZ3MSFAoFcGF0aHMYASADKAlSBXBhdGhz');

@$core.Deprecated('Use lintPathResultDescriptor instead')
const LintPathResult$json = {
  '1': 'LintPathResult',
  '2': [
    {'1': 'results', '3': 1, '4': 3, '5': 9, '10': 'results'},
  ],
};

/// Descriptor for `LintPathResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lintPathResultDescriptor = $convert
    .base64Decode('Cg5MaW50UGF0aFJlc3VsdBIYCgdyZXN1bHRzGAEgAygJUgdyZXN1bHRz');

@$core.Deprecated('Use overrideFileArgsDescriptor instead')
const OverrideFileArgs$json = {
  '1': 'OverrideFileArgs',
  '2': [
    {'1': 'file', '3': 1, '4': 1, '5': 9, '10': 'file'},
    {'1': 'specs', '3': 2, '4': 3, '5': 9, '10': 'specs'},
    {'1': 'import_paths', '3': 3, '4': 3, '5': 9, '10': 'importPaths'},
  ],
};

/// Descriptor for `OverrideFileArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List overrideFileArgsDescriptor = $convert.base64Decode(
    'ChBPdmVycmlkZUZpbGVBcmdzEhIKBGZpbGUYASABKAlSBGZpbGUSFAoFc3BlY3MYAiADKAlSBX'
    'NwZWNzEiEKDGltcG9ydF9wYXRocxgDIAMoCVILaW1wb3J0UGF0aHM=');

@$core.Deprecated('Use overrideFileResultDescriptor instead')
const OverrideFileResult$json = {
  '1': 'OverrideFileResult',
  '2': [
    {'1': 'result', '3': 1, '4': 1, '5': 8, '10': 'result'},
    {
      '1': 'parse_errors',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Error',
      '10': 'parseErrors'
    },
  ],
};

/// Descriptor for `OverrideFileResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List overrideFileResultDescriptor = $convert.base64Decode(
    'ChJPdmVycmlkZUZpbGVSZXN1bHQSFgoGcmVzdWx0GAEgASgIUgZyZXN1bHQSNQoMcGFyc2VfZX'
    'Jyb3JzGAIgAygLMhIuY29tLmtjbC5hcGkuRXJyb3JSC3BhcnNlRXJyb3Jz');

@$core.Deprecated('Use listVariablesOptionsDescriptor instead')
const ListVariablesOptions$json = {
  '1': 'ListVariablesOptions',
  '2': [
    {'1': 'merge_program', '3': 1, '4': 1, '5': 8, '10': 'mergeProgram'},
  ],
};

/// Descriptor for `ListVariablesOptions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listVariablesOptionsDescriptor = $convert.base64Decode(
    'ChRMaXN0VmFyaWFibGVzT3B0aW9ucxIjCg1tZXJnZV9wcm9ncmFtGAEgASgIUgxtZXJnZVByb2'
    'dyYW0=');

@$core.Deprecated('Use variableListDescriptor instead')
const VariableList$json = {
  '1': 'VariableList',
  '2': [
    {
      '1': 'variables',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Variable',
      '10': 'variables'
    },
  ],
};

/// Descriptor for `VariableList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List variableListDescriptor = $convert.base64Decode(
    'CgxWYXJpYWJsZUxpc3QSMwoJdmFyaWFibGVzGAEgAygLMhUuY29tLmtjbC5hcGkuVmFyaWFibG'
    'VSCXZhcmlhYmxlcw==');

@$core.Deprecated('Use listVariablesArgsDescriptor instead')
const ListVariablesArgs$json = {
  '1': 'ListVariablesArgs',
  '2': [
    {'1': 'files', '3': 1, '4': 3, '5': 9, '10': 'files'},
    {'1': 'specs', '3': 2, '4': 3, '5': 9, '10': 'specs'},
    {
      '1': 'options',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ListVariablesOptions',
      '10': 'options'
    },
  ],
};

/// Descriptor for `ListVariablesArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listVariablesArgsDescriptor = $convert.base64Decode(
    'ChFMaXN0VmFyaWFibGVzQXJncxIUCgVmaWxlcxgBIAMoCVIFZmlsZXMSFAoFc3BlY3MYAiADKA'
    'lSBXNwZWNzEjsKB29wdGlvbnMYAyABKAsyIS5jb20ua2NsLmFwaS5MaXN0VmFyaWFibGVzT3B0'
    'aW9uc1IHb3B0aW9ucw==');

@$core.Deprecated('Use listVariablesResultDescriptor instead')
const ListVariablesResult$json = {
  '1': 'ListVariablesResult',
  '2': [
    {
      '1': 'variables',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.ListVariablesResult.VariablesEntry',
      '10': 'variables'
    },
    {
      '1': 'unsupported_codes',
      '3': 2,
      '4': 3,
      '5': 9,
      '10': 'unsupportedCodes'
    },
    {
      '1': 'parse_errors',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Error',
      '10': 'parseErrors'
    },
  ],
  '3': [ListVariablesResult_VariablesEntry$json],
};

@$core.Deprecated('Use listVariablesResultDescriptor instead')
const ListVariablesResult_VariablesEntry$json = {
  '1': 'VariablesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.VariableList',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `ListVariablesResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listVariablesResultDescriptor = $convert.base64Decode(
    'ChNMaXN0VmFyaWFibGVzUmVzdWx0Ek0KCXZhcmlhYmxlcxgBIAMoCzIvLmNvbS5rY2wuYXBpLk'
    'xpc3RWYXJpYWJsZXNSZXN1bHQuVmFyaWFibGVzRW50cnlSCXZhcmlhYmxlcxIrChF1bnN1cHBv'
    'cnRlZF9jb2RlcxgCIAMoCVIQdW5zdXBwb3J0ZWRDb2RlcxI1CgxwYXJzZV9lcnJvcnMYAyADKA'
    'syEi5jb20ua2NsLmFwaS5FcnJvclILcGFyc2VFcnJvcnMaVwoOVmFyaWFibGVzRW50cnkSEAoD'
    'a2V5GAEgASgJUgNrZXkSLwoFdmFsdWUYAiABKAsyGS5jb20ua2NsLmFwaS5WYXJpYWJsZUxpc3'
    'RSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use variableDescriptor instead')
const Variable$json = {
  '1': 'Variable',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
    {'1': 'type_name', '3': 2, '4': 1, '5': 9, '10': 'typeName'},
    {'1': 'op_sym', '3': 3, '4': 1, '5': 9, '10': 'opSym'},
    {
      '1': 'list_items',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Variable',
      '10': 'listItems'
    },
    {
      '1': 'dict_entries',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.MapEntry',
      '10': 'dictEntries'
    },
  ],
};

/// Descriptor for `Variable`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List variableDescriptor = $convert.base64Decode(
    'CghWYXJpYWJsZRIUCgV2YWx1ZRgBIAEoCVIFdmFsdWUSGwoJdHlwZV9uYW1lGAIgASgJUgh0eX'
    'BlTmFtZRIVCgZvcF9zeW0YAyABKAlSBW9wU3ltEjQKCmxpc3RfaXRlbXMYBCADKAsyFS5jb20u'
    'a2NsLmFwaS5WYXJpYWJsZVIJbGlzdEl0ZW1zEjgKDGRpY3RfZW50cmllcxgFIAMoCzIVLmNvbS'
    '5rY2wuYXBpLk1hcEVudHJ5UgtkaWN0RW50cmllcw==');

@$core.Deprecated('Use mapEntryDescriptor instead')
const MapEntry$json = {
  '1': 'MapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.Variable',
      '10': 'value'
    },
  ],
};

/// Descriptor for `MapEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mapEntryDescriptor = $convert.base64Decode(
    'CghNYXBFbnRyeRIQCgNrZXkYASABKAlSA2tleRIrCgV2YWx1ZRgCIAEoCzIVLmNvbS5rY2wuYX'
    'BpLlZhcmlhYmxlUgV2YWx1ZQ==');

@$core.Deprecated('Use getSchemaTypeMappingArgsDescriptor instead')
const GetSchemaTypeMappingArgs$json = {
  '1': 'GetSchemaTypeMappingArgs',
  '2': [
    {
      '1': 'exec_args',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ExecProgramArgs',
      '10': 'execArgs'
    },
    {'1': 'schema_name', '3': 2, '4': 1, '5': 9, '10': 'schemaName'},
  ],
};

/// Descriptor for `GetSchemaTypeMappingArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSchemaTypeMappingArgsDescriptor = $convert.base64Decode(
    'ChhHZXRTY2hlbWFUeXBlTWFwcGluZ0FyZ3MSOQoJZXhlY19hcmdzGAEgASgLMhwuY29tLmtjbC'
    '5hcGkuRXhlY1Byb2dyYW1BcmdzUghleGVjQXJncxIfCgtzY2hlbWFfbmFtZRgCIAEoCVIKc2No'
    'ZW1hTmFtZQ==');

@$core.Deprecated('Use getSchemaTypeMappingResultDescriptor instead')
const GetSchemaTypeMappingResult$json = {
  '1': 'GetSchemaTypeMappingResult',
  '2': [
    {
      '1': 'schema_type_mapping',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.GetSchemaTypeMappingResult.SchemaTypeMappingEntry',
      '10': 'schemaTypeMapping'
    },
  ],
  '3': [GetSchemaTypeMappingResult_SchemaTypeMappingEntry$json],
};

@$core.Deprecated('Use getSchemaTypeMappingResultDescriptor instead')
const GetSchemaTypeMappingResult_SchemaTypeMappingEntry$json = {
  '1': 'SchemaTypeMappingEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `GetSchemaTypeMappingResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSchemaTypeMappingResultDescriptor = $convert.base64Decode(
    'ChpHZXRTY2hlbWFUeXBlTWFwcGluZ1Jlc3VsdBJuChNzY2hlbWFfdHlwZV9tYXBwaW5nGAEgAy'
    'gLMj4uY29tLmtjbC5hcGkuR2V0U2NoZW1hVHlwZU1hcHBpbmdSZXN1bHQuU2NoZW1hVHlwZU1h'
    'cHBpbmdFbnRyeVIRc2NoZW1hVHlwZU1hcHBpbmcaWgoWU2NoZW1hVHlwZU1hcHBpbmdFbnRyeR'
    'IQCgNrZXkYASABKAlSA2tleRIqCgV2YWx1ZRgCIAEoCzIULmNvbS5rY2wuYXBpLktjbFR5cGVS'
    'BXZhbHVlOgI4AQ==');

@$core.Deprecated('Use getSchemaTypeMappingUnderPathResultDescriptor instead')
const GetSchemaTypeMappingUnderPathResult$json = {
  '1': 'GetSchemaTypeMappingUnderPathResult',
  '2': [
    {
      '1': 'schema_type_mapping',
      '3': 1,
      '4': 3,
      '5': 11,
      '6':
          '.com.kcl.api.GetSchemaTypeMappingUnderPathResult.SchemaTypeMappingEntry',
      '10': 'schemaTypeMapping'
    },
  ],
  '3': [GetSchemaTypeMappingUnderPathResult_SchemaTypeMappingEntry$json],
};

@$core.Deprecated('Use getSchemaTypeMappingUnderPathResultDescriptor instead')
const GetSchemaTypeMappingUnderPathResult_SchemaTypeMappingEntry$json = {
  '1': 'SchemaTypeMappingEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.SchemaTypes',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `GetSchemaTypeMappingUnderPathResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSchemaTypeMappingUnderPathResultDescriptor =
    $convert.base64Decode(
        'CiNHZXRTY2hlbWFUeXBlTWFwcGluZ1VuZGVyUGF0aFJlc3VsdBJ3ChNzY2hlbWFfdHlwZV9tYX'
        'BwaW5nGAEgAygLMkcuY29tLmtjbC5hcGkuR2V0U2NoZW1hVHlwZU1hcHBpbmdVbmRlclBhdGhS'
        'ZXN1bHQuU2NoZW1hVHlwZU1hcHBpbmdFbnRyeVIRc2NoZW1hVHlwZU1hcHBpbmcaXgoWU2NoZW'
        '1hVHlwZU1hcHBpbmdFbnRyeRIQCgNrZXkYASABKAlSA2tleRIuCgV2YWx1ZRgCIAEoCzIYLmNv'
        'bS5rY2wuYXBpLlNjaGVtYVR5cGVzUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use schemaTypesDescriptor instead')
const SchemaTypes$json = {
  '1': 'SchemaTypes',
  '2': [
    {
      '1': 'schema_type',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'schemaType'
    },
  ],
};

/// Descriptor for `SchemaTypes`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schemaTypesDescriptor = $convert.base64Decode(
    'CgtTY2hlbWFUeXBlcxI1CgtzY2hlbWFfdHlwZRgBIAMoCzIULmNvbS5rY2wuYXBpLktjbFR5cG'
    'VSCnNjaGVtYVR5cGU=');

@$core.Deprecated('Use validateCodeArgsDescriptor instead')
const ValidateCodeArgs$json = {
  '1': 'ValidateCodeArgs',
  '2': [
    {'1': 'datafile', '3': 1, '4': 1, '5': 9, '10': 'datafile'},
    {'1': 'data', '3': 2, '4': 1, '5': 9, '10': 'data'},
    {'1': 'file', '3': 3, '4': 1, '5': 9, '10': 'file'},
    {'1': 'code', '3': 4, '4': 1, '5': 9, '10': 'code'},
    {'1': 'schema', '3': 5, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'attribute_name', '3': 6, '4': 1, '5': 9, '10': 'attributeName'},
    {'1': 'format', '3': 7, '4': 1, '5': 9, '10': 'format'},
    {
      '1': 'external_pkgs',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.ExternalPkg',
      '10': 'externalPkgs'
    },
  ],
};

/// Descriptor for `ValidateCodeArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List validateCodeArgsDescriptor = $convert.base64Decode(
    'ChBWYWxpZGF0ZUNvZGVBcmdzEhoKCGRhdGFmaWxlGAEgASgJUghkYXRhZmlsZRISCgRkYXRhGA'
    'IgASgJUgRkYXRhEhIKBGZpbGUYAyABKAlSBGZpbGUSEgoEY29kZRgEIAEoCVIEY29kZRIWCgZz'
    'Y2hlbWEYBSABKAlSBnNjaGVtYRIlCg5hdHRyaWJ1dGVfbmFtZRgGIAEoCVINYXR0cmlidXRlTm'
    'FtZRIWCgZmb3JtYXQYByABKAlSBmZvcm1hdBI9Cg1leHRlcm5hbF9wa2dzGAggAygLMhguY29t'
    'LmtjbC5hcGkuRXh0ZXJuYWxQa2dSDGV4dGVybmFsUGtncw==');

@$core.Deprecated('Use validateCodeResultDescriptor instead')
const ValidateCodeResult$json = {
  '1': 'ValidateCodeResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'err_message', '3': 2, '4': 1, '5': 9, '10': 'errMessage'},
  ],
};

/// Descriptor for `ValidateCodeResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List validateCodeResultDescriptor = $convert.base64Decode(
    'ChJWYWxpZGF0ZUNvZGVSZXN1bHQSGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIfCgtlcnJfbW'
    'Vzc2FnZRgCIAEoCVIKZXJyTWVzc2FnZQ==');

@$core.Deprecated('Use positionDescriptor instead')
const Position$json = {
  '1': 'Position',
  '2': [
    {'1': 'line', '3': 1, '4': 1, '5': 3, '10': 'line'},
    {'1': 'column', '3': 2, '4': 1, '5': 3, '10': 'column'},
    {'1': 'filename', '3': 3, '4': 1, '5': 9, '10': 'filename'},
  ],
};

/// Descriptor for `Position`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List positionDescriptor = $convert.base64Decode(
    'CghQb3NpdGlvbhISCgRsaW5lGAEgASgDUgRsaW5lEhYKBmNvbHVtbhgCIAEoA1IGY29sdW1uEh'
    'oKCGZpbGVuYW1lGAMgASgJUghmaWxlbmFtZQ==');

@$core.Deprecated('Use loadSettingsFilesArgsDescriptor instead')
const LoadSettingsFilesArgs$json = {
  '1': 'LoadSettingsFilesArgs',
  '2': [
    {'1': 'work_dir', '3': 1, '4': 1, '5': 9, '10': 'workDir'},
    {'1': 'files', '3': 2, '4': 3, '5': 9, '10': 'files'},
  ],
};

/// Descriptor for `LoadSettingsFilesArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadSettingsFilesArgsDescriptor = $convert.base64Decode(
    'ChVMb2FkU2V0dGluZ3NGaWxlc0FyZ3MSGQoId29ya19kaXIYASABKAlSB3dvcmtEaXISFAoFZm'
    'lsZXMYAiADKAlSBWZpbGVz');

@$core.Deprecated('Use loadSettingsFilesResultDescriptor instead')
const LoadSettingsFilesResult$json = {
  '1': 'LoadSettingsFilesResult',
  '2': [
    {
      '1': 'kcl_cli_configs',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.CliConfig',
      '10': 'kclCliConfigs'
    },
    {
      '1': 'kcl_options',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.KeyValuePair',
      '10': 'kclOptions'
    },
  ],
};

/// Descriptor for `LoadSettingsFilesResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadSettingsFilesResultDescriptor = $convert.base64Decode(
    'ChdMb2FkU2V0dGluZ3NGaWxlc1Jlc3VsdBI+Cg9rY2xfY2xpX2NvbmZpZ3MYASABKAsyFi5jb2'
    '0ua2NsLmFwaS5DbGlDb25maWdSDWtjbENsaUNvbmZpZ3MSOgoLa2NsX29wdGlvbnMYAiADKAsy'
    'GS5jb20ua2NsLmFwaS5LZXlWYWx1ZVBhaXJSCmtjbE9wdGlvbnM=');

@$core.Deprecated('Use cliConfigDescriptor instead')
const CliConfig$json = {
  '1': 'CliConfig',
  '2': [
    {'1': 'files', '3': 1, '4': 3, '5': 9, '10': 'files'},
    {'1': 'output', '3': 2, '4': 1, '5': 9, '10': 'output'},
    {'1': 'overrides', '3': 3, '4': 3, '5': 9, '10': 'overrides'},
    {'1': 'path_selector', '3': 4, '4': 3, '5': 9, '10': 'pathSelector'},
    {
      '1': 'strict_range_check',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'strictRangeCheck'
    },
    {'1': 'disable_none', '3': 6, '4': 1, '5': 8, '10': 'disableNone'},
    {'1': 'verbose', '3': 7, '4': 1, '5': 3, '10': 'verbose'},
    {'1': 'debug', '3': 8, '4': 1, '5': 8, '10': 'debug'},
    {'1': 'sort_keys', '3': 9, '4': 1, '5': 8, '10': 'sortKeys'},
    {'1': 'show_hidden', '3': 10, '4': 1, '5': 8, '10': 'showHidden'},
    {
      '1': 'include_schema_type_path',
      '3': 11,
      '4': 1,
      '5': 8,
      '10': 'includeSchemaTypePath'
    },
    {'1': 'fast_eval', '3': 12, '4': 1, '5': 8, '10': 'fastEval'},
  ],
};

/// Descriptor for `CliConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cliConfigDescriptor = $convert.base64Decode(
    'CglDbGlDb25maWcSFAoFZmlsZXMYASADKAlSBWZpbGVzEhYKBm91dHB1dBgCIAEoCVIGb3V0cH'
    'V0EhwKCW92ZXJyaWRlcxgDIAMoCVIJb3ZlcnJpZGVzEiMKDXBhdGhfc2VsZWN0b3IYBCADKAlS'
    'DHBhdGhTZWxlY3RvchIsChJzdHJpY3RfcmFuZ2VfY2hlY2sYBSABKAhSEHN0cmljdFJhbmdlQ2'
    'hlY2sSIQoMZGlzYWJsZV9ub25lGAYgASgIUgtkaXNhYmxlTm9uZRIYCgd2ZXJib3NlGAcgASgD'
    'Ugd2ZXJib3NlEhQKBWRlYnVnGAggASgIUgVkZWJ1ZxIbCglzb3J0X2tleXMYCSABKAhSCHNvcn'
    'RLZXlzEh8KC3Nob3dfaGlkZGVuGAogASgIUgpzaG93SGlkZGVuEjcKGGluY2x1ZGVfc2NoZW1h'
    'X3R5cGVfcGF0aBgLIAEoCFIVaW5jbHVkZVNjaGVtYVR5cGVQYXRoEhsKCWZhc3RfZXZhbBgMIA'
    'EoCFIIZmFzdEV2YWw=');

@$core.Deprecated('Use keyValuePairDescriptor instead')
const KeyValuePair$json = {
  '1': 'KeyValuePair',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `KeyValuePair`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyValuePairDescriptor = $convert.base64Decode(
    'CgxLZXlWYWx1ZVBhaXISEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVl');

@$core.Deprecated('Use renameArgsDescriptor instead')
const RenameArgs$json = {
  '1': 'RenameArgs',
  '2': [
    {'1': 'package_root', '3': 1, '4': 1, '5': 9, '10': 'packageRoot'},
    {'1': 'symbol_path', '3': 2, '4': 1, '5': 9, '10': 'symbolPath'},
    {'1': 'file_paths', '3': 3, '4': 3, '5': 9, '10': 'filePaths'},
    {'1': 'new_name', '3': 4, '4': 1, '5': 9, '10': 'newName'},
  ],
};

/// Descriptor for `RenameArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameArgsDescriptor = $convert.base64Decode(
    'CgpSZW5hbWVBcmdzEiEKDHBhY2thZ2Vfcm9vdBgBIAEoCVILcGFja2FnZVJvb3QSHwoLc3ltYm'
    '9sX3BhdGgYAiABKAlSCnN5bWJvbFBhdGgSHQoKZmlsZV9wYXRocxgDIAMoCVIJZmlsZVBhdGhz'
    'EhkKCG5ld19uYW1lGAQgASgJUgduZXdOYW1l');

@$core.Deprecated('Use renameResultDescriptor instead')
const RenameResult$json = {
  '1': 'RenameResult',
  '2': [
    {'1': 'changed_files', '3': 1, '4': 3, '5': 9, '10': 'changedFiles'},
  ],
};

/// Descriptor for `RenameResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameResultDescriptor = $convert.base64Decode(
    'CgxSZW5hbWVSZXN1bHQSIwoNY2hhbmdlZF9maWxlcxgBIAMoCVIMY2hhbmdlZEZpbGVz');

@$core.Deprecated('Use renameCodeArgsDescriptor instead')
const RenameCodeArgs$json = {
  '1': 'RenameCodeArgs',
  '2': [
    {'1': 'package_root', '3': 1, '4': 1, '5': 9, '10': 'packageRoot'},
    {'1': 'symbol_path', '3': 2, '4': 1, '5': 9, '10': 'symbolPath'},
    {
      '1': 'source_codes',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.RenameCodeArgs.SourceCodesEntry',
      '10': 'sourceCodes'
    },
    {'1': 'new_name', '3': 4, '4': 1, '5': 9, '10': 'newName'},
  ],
  '3': [RenameCodeArgs_SourceCodesEntry$json],
};

@$core.Deprecated('Use renameCodeArgsDescriptor instead')
const RenameCodeArgs_SourceCodesEntry$json = {
  '1': 'SourceCodesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `RenameCodeArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameCodeArgsDescriptor = $convert.base64Decode(
    'Cg5SZW5hbWVDb2RlQXJncxIhCgxwYWNrYWdlX3Jvb3QYASABKAlSC3BhY2thZ2VSb290Eh8KC3'
    'N5bWJvbF9wYXRoGAIgASgJUgpzeW1ib2xQYXRoEk8KDHNvdXJjZV9jb2RlcxgDIAMoCzIsLmNv'
    'bS5rY2wuYXBpLlJlbmFtZUNvZGVBcmdzLlNvdXJjZUNvZGVzRW50cnlSC3NvdXJjZUNvZGVzEh'
    'kKCG5ld19uYW1lGAQgASgJUgduZXdOYW1lGj4KEFNvdXJjZUNvZGVzRW50cnkSEAoDa2V5GAEg'
    'ASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use renameCodeResultDescriptor instead')
const RenameCodeResult$json = {
  '1': 'RenameCodeResult',
  '2': [
    {
      '1': 'changed_codes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.RenameCodeResult.ChangedCodesEntry',
      '10': 'changedCodes'
    },
  ],
  '3': [RenameCodeResult_ChangedCodesEntry$json],
};

@$core.Deprecated('Use renameCodeResultDescriptor instead')
const RenameCodeResult_ChangedCodesEntry$json = {
  '1': 'ChangedCodesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `RenameCodeResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameCodeResultDescriptor = $convert.base64Decode(
    'ChBSZW5hbWVDb2RlUmVzdWx0ElQKDWNoYW5nZWRfY29kZXMYASADKAsyLy5jb20ua2NsLmFwaS'
    '5SZW5hbWVDb2RlUmVzdWx0LkNoYW5nZWRDb2Rlc0VudHJ5UgxjaGFuZ2VkQ29kZXMaPwoRQ2hh'
    'bmdlZENvZGVzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOg'
    'I4AQ==');

@$core.Deprecated('Use testArgsDescriptor instead')
const TestArgs$json = {
  '1': 'TestArgs',
  '2': [
    {
      '1': 'exec_args',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ExecProgramArgs',
      '10': 'execArgs'
    },
    {'1': 'pkg_list', '3': 2, '4': 3, '5': 9, '10': 'pkgList'},
    {'1': 'run_regexp', '3': 3, '4': 1, '5': 9, '10': 'runRegexp'},
    {'1': 'fail_fast', '3': 4, '4': 1, '5': 8, '10': 'failFast'},
    {'1': 'coverage', '3': 5, '4': 1, '5': 8, '10': 'coverage'},
  ],
};

/// Descriptor for `TestArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testArgsDescriptor = $convert.base64Decode(
    'CghUZXN0QXJncxI5CglleGVjX2FyZ3MYASABKAsyHC5jb20ua2NsLmFwaS5FeGVjUHJvZ3JhbU'
    'FyZ3NSCGV4ZWNBcmdzEhkKCHBrZ19saXN0GAIgAygJUgdwa2dMaXN0Eh0KCnJ1bl9yZWdleHAY'
    'AyABKAlSCXJ1blJlZ2V4cBIbCglmYWlsX2Zhc3QYBCABKAhSCGZhaWxGYXN0EhoKCGNvdmVyYW'
    'dlGAUgASgIUghjb3ZlcmFnZQ==');

@$core.Deprecated('Use testResultDescriptor instead')
const TestResult$json = {
  '1': 'TestResult',
  '2': [
    {
      '1': 'info',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.TestCaseInfo',
      '10': 'info'
    },
    {
      '1': 'coverage',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.TestCoverageReport',
      '10': 'coverage'
    },
  ],
};

/// Descriptor for `TestResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testResultDescriptor = $convert.base64Decode(
    'CgpUZXN0UmVzdWx0Ei0KBGluZm8YAiADKAsyGS5jb20ua2NsLmFwaS5UZXN0Q2FzZUluZm9SBG'
    'luZm8SOwoIY292ZXJhZ2UYAyABKAsyHy5jb20ua2NsLmFwaS5UZXN0Q292ZXJhZ2VSZXBvcnRS'
    'CGNvdmVyYWdl');

@$core.Deprecated('Use testCaseInfoDescriptor instead')
const TestCaseInfo$json = {
  '1': 'TestCaseInfo',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
    {'1': 'duration', '3': 3, '4': 1, '5': 4, '10': 'duration'},
    {'1': 'log_message', '3': 4, '4': 1, '5': 9, '10': 'logMessage'},
    {
      '1': 'line_hits',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.TestCaseInfo.LineHitsEntry',
      '10': 'lineHits'
    },
  ],
  '3': [TestCaseInfo_LineHitsEntry$json],
};

@$core.Deprecated('Use testCaseInfoDescriptor instead')
const TestCaseInfo_LineHitsEntry$json = {
  '1': 'LineHitsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 4, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `TestCaseInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testCaseInfoDescriptor = $convert.base64Decode(
    'CgxUZXN0Q2FzZUluZm8SEgoEbmFtZRgBIAEoCVIEbmFtZRIUCgVlcnJvchgCIAEoCVIFZXJyb3'
    'ISGgoIZHVyYXRpb24YAyABKARSCGR1cmF0aW9uEh8KC2xvZ19tZXNzYWdlGAQgASgJUgpsb2dN'
    'ZXNzYWdlEkQKCWxpbmVfaGl0cxgFIAMoCzInLmNvbS5rY2wuYXBpLlRlc3RDYXNlSW5mby5MaW'
    '5lSGl0c0VudHJ5UghsaW5lSGl0cxo7Cg1MaW5lSGl0c0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5'
    'EhQKBXZhbHVlGAIgASgEUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use fileCoverageDescriptor instead')
const FileCoverage$json = {
  '1': 'FileCoverage',
  '2': [
    {'1': 'filename', '3': 1, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'covered_lines', '3': 2, '4': 3, '5': 4, '10': 'coveredLines'},
    {'1': 'executable_lines', '3': 3, '4': 3, '5': 4, '10': 'executableLines'},
    {
      '1': 'line_hits',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.FileCoverage.LineHitsEntry',
      '10': 'lineHits'
    },
  ],
  '3': [FileCoverage_LineHitsEntry$json],
};

@$core.Deprecated('Use fileCoverageDescriptor instead')
const FileCoverage_LineHitsEntry$json = {
  '1': 'LineHitsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 4, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 4, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `FileCoverage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileCoverageDescriptor = $convert.base64Decode(
    'CgxGaWxlQ292ZXJhZ2USGgoIZmlsZW5hbWUYASABKAlSCGZpbGVuYW1lEiMKDWNvdmVyZWRfbG'
    'luZXMYAiADKARSDGNvdmVyZWRMaW5lcxIpChBleGVjdXRhYmxlX2xpbmVzGAMgAygEUg9leGVj'
    'dXRhYmxlTGluZXMSRAoJbGluZV9oaXRzGAQgAygLMicuY29tLmtjbC5hcGkuRmlsZUNvdmVyYW'
    'dlLkxpbmVIaXRzRW50cnlSCGxpbmVIaXRzGjsKDUxpbmVIaXRzRW50cnkSEAoDa2V5GAEgASgE'
    'UgNrZXkSFAoFdmFsdWUYAiABKARSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use testCoverageReportDescriptor instead')
const TestCoverageReport$json = {
  '1': 'TestCoverageReport',
  '2': [
    {
      '1': 'files',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.TestCoverageReport.FilesEntry',
      '10': 'files'
    },
    {
      '1': 'summary',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.CoverageSummary',
      '10': 'summary'
    },
  ],
  '3': [TestCoverageReport_FilesEntry$json],
};

@$core.Deprecated('Use testCoverageReportDescriptor instead')
const TestCoverageReport_FilesEntry$json = {
  '1': 'FilesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.FileCoverage',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `TestCoverageReport`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testCoverageReportDescriptor = $convert.base64Decode(
    'ChJUZXN0Q292ZXJhZ2VSZXBvcnQSQAoFZmlsZXMYASADKAsyKi5jb20ua2NsLmFwaS5UZXN0Q2'
    '92ZXJhZ2VSZXBvcnQuRmlsZXNFbnRyeVIFZmlsZXMSNgoHc3VtbWFyeRgCIAEoCzIcLmNvbS5r'
    'Y2wuYXBpLkNvdmVyYWdlU3VtbWFyeVIHc3VtbWFyeRpTCgpGaWxlc0VudHJ5EhAKA2tleRgBIA'
    'EoCVIDa2V5Ei8KBXZhbHVlGAIgASgLMhkuY29tLmtjbC5hcGkuRmlsZUNvdmVyYWdlUgV2YWx1'
    'ZToCOAE=');

@$core.Deprecated('Use coverageSummaryDescriptor instead')
const CoverageSummary$json = {
  '1': 'CoverageSummary',
  '2': [
    {'1': 'covered', '3': 1, '4': 1, '5': 4, '10': 'covered'},
    {'1': 'executable', '3': 2, '4': 1, '5': 4, '10': 'executable'},
    {'1': 'percent', '3': 3, '4': 1, '5': 1, '10': 'percent'},
  ],
};

/// Descriptor for `CoverageSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List coverageSummaryDescriptor = $convert.base64Decode(
    'Cg9Db3ZlcmFnZVN1bW1hcnkSGAoHY292ZXJlZBgBIAEoBFIHY292ZXJlZBIeCgpleGVjdXRhYm'
    'xlGAIgASgEUgpleGVjdXRhYmxlEhgKB3BlcmNlbnQYAyABKAFSB3BlcmNlbnQ=');

@$core.Deprecated('Use formatTestReportArgsDescriptor instead')
const FormatTestReportArgs$json = {
  '1': 'FormatTestReportArgs',
  '2': [
    {
      '1': 'result',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.TestResult',
      '10': 'result'
    },
  ],
};

/// Descriptor for `FormatTestReportArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List formatTestReportArgsDescriptor = $convert.base64Decode(
    'ChRGb3JtYXRUZXN0UmVwb3J0QXJncxIvCgZyZXN1bHQYASABKAsyFy5jb20ua2NsLmFwaS5UZX'
    'N0UmVzdWx0UgZyZXN1bHQ=');

@$core.Deprecated('Use formatTestReportResultDescriptor instead')
const FormatTestReportResult$json = {
  '1': 'FormatTestReportResult',
  '2': [
    {'1': 'report', '3': 1, '4': 1, '5': 9, '10': 'report'},
  ],
};

/// Descriptor for `FormatTestReportResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List formatTestReportResultDescriptor =
    $convert.base64Decode(
        'ChZGb3JtYXRUZXN0UmVwb3J0UmVzdWx0EhYKBnJlcG9ydBgBIAEoCVIGcmVwb3J0');

@$core.Deprecated('Use updateDependenciesArgsDescriptor instead')
const UpdateDependenciesArgs$json = {
  '1': 'UpdateDependenciesArgs',
  '2': [
    {'1': 'manifest_path', '3': 1, '4': 1, '5': 9, '10': 'manifestPath'},
    {'1': 'vendor', '3': 2, '4': 1, '5': 8, '10': 'vendor'},
  ],
};

/// Descriptor for `UpdateDependenciesArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateDependenciesArgsDescriptor =
    $convert.base64Decode(
        'ChZVcGRhdGVEZXBlbmRlbmNpZXNBcmdzEiMKDW1hbmlmZXN0X3BhdGgYASABKAlSDG1hbmlmZX'
        'N0UGF0aBIWCgZ2ZW5kb3IYAiABKAhSBnZlbmRvcg==');

@$core.Deprecated('Use updateDependenciesResultDescriptor instead')
const UpdateDependenciesResult$json = {
  '1': 'UpdateDependenciesResult',
  '2': [
    {
      '1': 'external_pkgs',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.ExternalPkg',
      '10': 'externalPkgs'
    },
  ],
};

/// Descriptor for `UpdateDependenciesResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateDependenciesResultDescriptor =
    $convert.base64Decode(
        'ChhVcGRhdGVEZXBlbmRlbmNpZXNSZXN1bHQSPQoNZXh0ZXJuYWxfcGtncxgDIAMoCzIYLmNvbS'
        '5rY2wuYXBpLkV4dGVybmFsUGtnUgxleHRlcm5hbFBrZ3M=');

@$core.Deprecated('Use generateTomlArgsDescriptor instead')
const GenerateTomlArgs$json = {
  '1': 'GenerateTomlArgs',
  '2': [
    {
      '1': 'exec_args',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ExecProgramArgs',
      '10': 'execArgs'
    },
    {'1': 'sort_keys', '3': 2, '4': 1, '5': 8, '10': 'sortKeys'},
  ],
};

/// Descriptor for `GenerateTomlArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateTomlArgsDescriptor = $convert.base64Decode(
    'ChBHZW5lcmF0ZVRvbWxBcmdzEjkKCWV4ZWNfYXJncxgBIAEoCzIcLmNvbS5rY2wuYXBpLkV4ZW'
    'NQcm9ncmFtQXJnc1IIZXhlY0FyZ3MSGwoJc29ydF9rZXlzGAIgASgIUghzb3J0S2V5cw==');

@$core.Deprecated('Use generateTomlResultDescriptor instead')
const GenerateTomlResult$json = {
  '1': 'GenerateTomlResult',
  '2': [
    {'1': 'toml', '3': 1, '4': 1, '5': 9, '10': 'toml'},
  ],
};

/// Descriptor for `GenerateTomlResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateTomlResultDescriptor = $convert
    .base64Decode('ChJHZW5lcmF0ZVRvbWxSZXN1bHQSEgoEdG9tbBgBIAEoCVIEdG9tbA==');

@$core.Deprecated('Use generateKclArgsDescriptor instead')
const GenerateKclArgs$json = {
  '1': 'GenerateKclArgs',
  '2': [
    {'1': 'source', '3': 1, '4': 1, '5': 9, '10': 'source'},
    {'1': 'filename', '3': 2, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'format', '3': 3, '4': 1, '5': 9, '10': 'format'},
  ],
};

/// Descriptor for `GenerateKclArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateKclArgsDescriptor = $convert.base64Decode(
    'Cg9HZW5lcmF0ZUtjbEFyZ3MSFgoGc291cmNlGAEgASgJUgZzb3VyY2USGgoIZmlsZW5hbWUYAi'
    'ABKAlSCGZpbGVuYW1lEhYKBmZvcm1hdBgDIAEoCVIGZm9ybWF0');

@$core.Deprecated('Use generateKclResultDescriptor instead')
const GenerateKclResult$json = {
  '1': 'GenerateKclResult',
  '2': [
    {'1': 'kcl', '3': 1, '4': 1, '5': 9, '10': 'kcl'},
  ],
};

/// Descriptor for `GenerateKclResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateKclResultDescriptor = $convert
    .base64Decode('ChFHZW5lcmF0ZUtjbFJlc3VsdBIQCgNrY2wYASABKAlSA2tjbA==');

@$core.Deprecated('Use generateOpenAPIArgsDescriptor instead')
const GenerateOpenAPIArgs$json = {
  '1': 'GenerateOpenAPIArgs',
  '2': [
    {
      '1': 'parse_args',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ParseProgramArgs',
      '10': 'parseArgs'
    },
    {'1': 'version', '3': 2, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `GenerateOpenAPIArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateOpenAPIArgsDescriptor = $convert.base64Decode(
    'ChNHZW5lcmF0ZU9wZW5BUElBcmdzEjwKCnBhcnNlX2FyZ3MYASABKAsyHS5jb20ua2NsLmFwaS'
    '5QYXJzZVByb2dyYW1BcmdzUglwYXJzZUFyZ3MSGAoHdmVyc2lvbhgCIAEoCVIHdmVyc2lvbg==');

@$core.Deprecated('Use generateOpenAPIResultDescriptor instead')
const GenerateOpenAPIResult$json = {
  '1': 'GenerateOpenAPIResult',
  '2': [
    {'1': 'spec', '3': 1, '4': 1, '5': 9, '10': 'spec'},
  ],
};

/// Descriptor for `GenerateOpenAPIResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateOpenAPIResultDescriptor =
    $convert.base64Decode(
        'ChVHZW5lcmF0ZU9wZW5BUElSZXN1bHQSEgoEc3BlYxgBIAEoCVIEc3BlYw==');

@$core.Deprecated('Use generateProtoArgsDescriptor instead')
const GenerateProtoArgs$json = {
  '1': 'GenerateProtoArgs',
  '2': [
    {
      '1': 'parse_args',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ParseProgramArgs',
      '10': 'parseArgs'
    },
    {'1': 'package', '3': 2, '4': 1, '5': 9, '10': 'package'},
  ],
};

/// Descriptor for `GenerateProtoArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateProtoArgsDescriptor = $convert.base64Decode(
    'ChFHZW5lcmF0ZVByb3RvQXJncxI8CgpwYXJzZV9hcmdzGAEgASgLMh0uY29tLmtjbC5hcGkuUG'
    'Fyc2VQcm9ncmFtQXJnc1IJcGFyc2VBcmdzEhgKB3BhY2thZ2UYAiABKAlSB3BhY2thZ2U=');

@$core.Deprecated('Use generateProtoResultDescriptor instead')
const GenerateProtoResult$json = {
  '1': 'GenerateProtoResult',
  '2': [
    {'1': 'proto', '3': 1, '4': 1, '5': 9, '10': 'proto'},
  ],
};

/// Descriptor for `GenerateProtoResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateProtoResultDescriptor =
    $convert.base64Decode(
        'ChNHZW5lcmF0ZVByb3RvUmVzdWx0EhQKBXByb3RvGAEgASgJUgVwcm90bw==');

@$core.Deprecated('Use generateDocArgsDescriptor instead')
const GenerateDocArgs$json = {
  '1': 'GenerateDocArgs',
  '2': [
    {
      '1': 'parse_args',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.ParseProgramArgs',
      '10': 'parseArgs'
    },
    {'1': 'format', '3': 2, '4': 1, '5': 9, '10': 'format'},
  ],
};

/// Descriptor for `GenerateDocArgs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateDocArgsDescriptor = $convert.base64Decode(
    'Cg9HZW5lcmF0ZURvY0FyZ3MSPAoKcGFyc2VfYXJncxgBIAEoCzIdLmNvbS5rY2wuYXBpLlBhcn'
    'NlUHJvZ3JhbUFyZ3NSCXBhcnNlQXJncxIWCgZmb3JtYXQYAiABKAlSBmZvcm1hdA==');

@$core.Deprecated('Use generateDocResultDescriptor instead')
const GenerateDocResult$json = {
  '1': 'GenerateDocResult',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 9, '10': 'content'},
  ],
};

/// Descriptor for `GenerateDocResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateDocResultDescriptor = $convert.base64Decode(
    'ChFHZW5lcmF0ZURvY1Jlc3VsdBIYCgdjb250ZW50GAEgASgJUgdjb250ZW50');

@$core.Deprecated('Use kclTypeDescriptor instead')
const KclType$json = {
  '1': 'KclType',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 9, '10': 'type'},
    {
      '1': 'union_types',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'unionTypes'
    },
    {'1': 'default', '3': 3, '4': 1, '5': 9, '10': 'default'},
    {'1': 'schema_name', '3': 4, '4': 1, '5': 9, '10': 'schemaName'},
    {'1': 'schema_doc', '3': 5, '4': 1, '5': 9, '10': 'schemaDoc'},
    {
      '1': 'properties',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.KclType.PropertiesEntry',
      '10': 'properties'
    },
    {'1': 'required', '3': 7, '4': 3, '5': 9, '10': 'required'},
    {
      '1': 'key',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'key'
    },
    {
      '1': 'item',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'item'
    },
    {'1': 'line', '3': 10, '4': 1, '5': 5, '10': 'line'},
    {
      '1': 'decorators',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Decorator',
      '10': 'decorators'
    },
    {'1': 'filename', '3': 12, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'pkg_path', '3': 13, '4': 1, '5': 9, '10': 'pkgPath'},
    {'1': 'description', '3': 14, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'examples',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.KclType.ExamplesEntry',
      '10': 'examples'
    },
    {
      '1': 'base_schema',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'baseSchema'
    },
    {
      '1': 'function',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.FunctionType',
      '9': 0,
      '10': 'function',
      '17': true
    },
    {
      '1': 'index_signature',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.IndexSignature',
      '9': 1,
      '10': 'indexSignature',
      '17': true
    },
  ],
  '3': [KclType_PropertiesEntry$json, KclType_ExamplesEntry$json],
  '8': [
    {'1': '_function'},
    {'1': '_index_signature'},
  ],
};

@$core.Deprecated('Use kclTypeDescriptor instead')
const KclType_PropertiesEntry$json = {
  '1': 'PropertiesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use kclTypeDescriptor instead')
const KclType_ExamplesEntry$json = {
  '1': 'ExamplesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.Example',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `KclType`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kclTypeDescriptor = $convert.base64Decode(
    'CgdLY2xUeXBlEhIKBHR5cGUYASABKAlSBHR5cGUSNQoLdW5pb25fdHlwZXMYAiADKAsyFC5jb2'
    '0ua2NsLmFwaS5LY2xUeXBlUgp1bmlvblR5cGVzEhgKB2RlZmF1bHQYAyABKAlSB2RlZmF1bHQS'
    'HwoLc2NoZW1hX25hbWUYBCABKAlSCnNjaGVtYU5hbWUSHQoKc2NoZW1hX2RvYxgFIAEoCVIJc2'
    'NoZW1hRG9jEkQKCnByb3BlcnRpZXMYBiADKAsyJC5jb20ua2NsLmFwaS5LY2xUeXBlLlByb3Bl'
    'cnRpZXNFbnRyeVIKcHJvcGVydGllcxIaCghyZXF1aXJlZBgHIAMoCVIIcmVxdWlyZWQSJgoDa2'
    'V5GAggASgLMhQuY29tLmtjbC5hcGkuS2NsVHlwZVIDa2V5EigKBGl0ZW0YCSABKAsyFC5jb20u'
    'a2NsLmFwaS5LY2xUeXBlUgRpdGVtEhIKBGxpbmUYCiABKAVSBGxpbmUSNgoKZGVjb3JhdG9ycx'
    'gLIAMoCzIWLmNvbS5rY2wuYXBpLkRlY29yYXRvclIKZGVjb3JhdG9ycxIaCghmaWxlbmFtZRgM'
    'IAEoCVIIZmlsZW5hbWUSGQoIcGtnX3BhdGgYDSABKAlSB3BrZ1BhdGgSIAoLZGVzY3JpcHRpb2'
    '4YDiABKAlSC2Rlc2NyaXB0aW9uEj4KCGV4YW1wbGVzGA8gAygLMiIuY29tLmtjbC5hcGkuS2Ns'
    'VHlwZS5FeGFtcGxlc0VudHJ5UghleGFtcGxlcxI1CgtiYXNlX3NjaGVtYRgQIAEoCzIULmNvbS'
    '5rY2wuYXBpLktjbFR5cGVSCmJhc2VTY2hlbWESOgoIZnVuY3Rpb24YESABKAsyGS5jb20ua2Ns'
    'LmFwaS5GdW5jdGlvblR5cGVIAFIIZnVuY3Rpb26IAQESSQoPaW5kZXhfc2lnbmF0dXJlGBIgAS'
    'gLMhsuY29tLmtjbC5hcGkuSW5kZXhTaWduYXR1cmVIAVIOaW5kZXhTaWduYXR1cmWIAQEaUwoP'
    'UHJvcGVydGllc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EioKBXZhbHVlGAIgASgLMhQuY29tLm'
    'tjbC5hcGkuS2NsVHlwZVIFdmFsdWU6AjgBGlEKDUV4YW1wbGVzRW50cnkSEAoDa2V5GAEgASgJ'
    'UgNrZXkSKgoFdmFsdWUYAiABKAsyFC5jb20ua2NsLmFwaS5FeGFtcGxlUgV2YWx1ZToCOAFCCw'
    'oJX2Z1bmN0aW9uQhIKEF9pbmRleF9zaWduYXR1cmU=');

@$core.Deprecated('Use functionTypeDescriptor instead')
const FunctionType$json = {
  '1': 'FunctionType',
  '2': [
    {
      '1': 'params',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Parameter',
      '10': 'params'
    },
    {
      '1': 'return_ty',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'returnTy'
    },
  ],
};

/// Descriptor for `FunctionType`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List functionTypeDescriptor = $convert.base64Decode(
    'CgxGdW5jdGlvblR5cGUSLgoGcGFyYW1zGAEgAygLMhYuY29tLmtjbC5hcGkuUGFyYW1ldGVyUg'
    'ZwYXJhbXMSMQoJcmV0dXJuX3R5GAIgASgLMhQuY29tLmtjbC5hcGkuS2NsVHlwZVIIcmV0dXJu'
    'VHk=');

@$core.Deprecated('Use parameterDescriptor instead')
const Parameter$json = {
  '1': 'Parameter',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'ty',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'ty'
    },
  ],
};

/// Descriptor for `Parameter`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parameterDescriptor = $convert.base64Decode(
    'CglQYXJhbWV0ZXISEgoEbmFtZRgBIAEoCVIEbmFtZRIkCgJ0eRgCIAEoCzIULmNvbS5rY2wuYX'
    'BpLktjbFR5cGVSAnR5');

@$core.Deprecated('Use indexSignatureDescriptor instead')
const IndexSignature$json = {
  '1': 'IndexSignature',
  '2': [
    {
      '1': 'key_name',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'keyName',
      '17': true
    },
    {
      '1': 'key',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'key'
    },
    {
      '1': 'val',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.com.kcl.api.KclType',
      '10': 'val'
    },
    {'1': 'any_other', '3': 4, '4': 1, '5': 8, '10': 'anyOther'},
  ],
  '8': [
    {'1': '_key_name'},
  ],
};

/// Descriptor for `IndexSignature`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List indexSignatureDescriptor = $convert.base64Decode(
    'Cg5JbmRleFNpZ25hdHVyZRIeCghrZXlfbmFtZRgBIAEoCUgAUgdrZXlOYW1liAEBEiYKA2tleR'
    'gCIAEoCzIULmNvbS5rY2wuYXBpLktjbFR5cGVSA2tleRImCgN2YWwYAyABKAsyFC5jb20ua2Ns'
    'LmFwaS5LY2xUeXBlUgN2YWwSGwoJYW55X290aGVyGAQgASgIUghhbnlPdGhlckILCglfa2V5X2'
    '5hbWU=');

@$core.Deprecated('Use decoratorDescriptor instead')
const Decorator$json = {
  '1': 'Decorator',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'arguments', '3': 2, '4': 3, '5': 9, '10': 'arguments'},
    {
      '1': 'keywords',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.com.kcl.api.Decorator.KeywordsEntry',
      '10': 'keywords'
    },
  ],
  '3': [Decorator_KeywordsEntry$json],
};

@$core.Deprecated('Use decoratorDescriptor instead')
const Decorator_KeywordsEntry$json = {
  '1': 'KeywordsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Decorator`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decoratorDescriptor = $convert.base64Decode(
    'CglEZWNvcmF0b3ISEgoEbmFtZRgBIAEoCVIEbmFtZRIcCglhcmd1bWVudHMYAiADKAlSCWFyZ3'
    'VtZW50cxJACghrZXl3b3JkcxgDIAMoCzIkLmNvbS5rY2wuYXBpLkRlY29yYXRvci5LZXl3b3Jk'
    'c0VudHJ5UghrZXl3b3Jkcxo7Cg1LZXl3b3Jkc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBX'
    'ZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use exampleDescriptor instead')
const Example$json = {
  '1': 'Example',
  '2': [
    {'1': 'summary', '3': 1, '4': 1, '5': 9, '10': 'summary'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'value', '3': 3, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `Example`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exampleDescriptor = $convert.base64Decode(
    'CgdFeGFtcGxlEhgKB3N1bW1hcnkYASABKAlSB3N1bW1hcnkSIAoLZGVzY3JpcHRpb24YAiABKA'
    'lSC2Rlc2NyaXB0aW9uEhQKBXZhbHVlGAMgASgJUgV2YWx1ZQ==');

const $core.Map<$core.String, $core.dynamic> BuiltinServiceBase$json = {
  '1': 'BuiltinService',
  '2': [
    {'1': 'Ping', '2': '.com.kcl.api.PingArgs', '3': '.com.kcl.api.PingResult'},
    {
      '1': 'ListMethod',
      '2': '.com.kcl.api.ListMethodArgs',
      '3': '.com.kcl.api.ListMethodResult'
    },
  ],
};

@$core.Deprecated('Use builtinServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    BuiltinServiceBase$messageJson = {
  '.com.kcl.api.PingArgs': PingArgs$json,
  '.com.kcl.api.PingResult': PingResult$json,
  '.com.kcl.api.ListMethodArgs': ListMethodArgs$json,
  '.com.kcl.api.ListMethodResult': ListMethodResult$json,
};

/// Descriptor for `BuiltinService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List builtinServiceDescriptor = $convert.base64Decode(
    'Cg5CdWlsdGluU2VydmljZRI2CgRQaW5nEhUuY29tLmtjbC5hcGkuUGluZ0FyZ3MaFy5jb20ua2'
    'NsLmFwaS5QaW5nUmVzdWx0EkgKCkxpc3RNZXRob2QSGy5jb20ua2NsLmFwaS5MaXN0TWV0aG9k'
    'QXJncxodLmNvbS5rY2wuYXBpLkxpc3RNZXRob2RSZXN1bHQ=');

const $core.Map<$core.String, $core.dynamic> KclServiceBase$json = {
  '1': 'KclService',
  '2': [
    {'1': 'Ping', '2': '.com.kcl.api.PingArgs', '3': '.com.kcl.api.PingResult'},
    {
      '1': 'GetVersion',
      '2': '.com.kcl.api.GetVersionArgs',
      '3': '.com.kcl.api.GetVersionResult'
    },
    {
      '1': 'ParseProgram',
      '2': '.com.kcl.api.ParseProgramArgs',
      '3': '.com.kcl.api.ParseProgramResult'
    },
    {
      '1': 'ParseFile',
      '2': '.com.kcl.api.ParseFileArgs',
      '3': '.com.kcl.api.ParseFileResult'
    },
    {
      '1': 'LoadPackage',
      '2': '.com.kcl.api.LoadPackageArgs',
      '3': '.com.kcl.api.LoadPackageResult'
    },
    {
      '1': 'ListOptions',
      '2': '.com.kcl.api.ParseProgramArgs',
      '3': '.com.kcl.api.ListOptionsResult'
    },
    {
      '1': 'ListVariables',
      '2': '.com.kcl.api.ListVariablesArgs',
      '3': '.com.kcl.api.ListVariablesResult'
    },
    {
      '1': 'ExecProgram',
      '2': '.com.kcl.api.ExecProgramArgs',
      '3': '.com.kcl.api.ExecProgramResult'
    },
    {
      '1': 'OverrideFile',
      '2': '.com.kcl.api.OverrideFileArgs',
      '3': '.com.kcl.api.OverrideFileResult'
    },
    {
      '1': 'GetSchemaTypeMapping',
      '2': '.com.kcl.api.GetSchemaTypeMappingArgs',
      '3': '.com.kcl.api.GetSchemaTypeMappingResult'
    },
    {
      '1': 'GetSchemaTypeMappingUnderPath',
      '2': '.com.kcl.api.GetSchemaTypeMappingArgs',
      '3': '.com.kcl.api.GetSchemaTypeMappingUnderPathResult'
    },
    {
      '1': 'FormatCode',
      '2': '.com.kcl.api.FormatCodeArgs',
      '3': '.com.kcl.api.FormatCodeResult'
    },
    {
      '1': 'FormatPath',
      '2': '.com.kcl.api.FormatPathArgs',
      '3': '.com.kcl.api.FormatPathResult'
    },
    {
      '1': 'LintPath',
      '2': '.com.kcl.api.LintPathArgs',
      '3': '.com.kcl.api.LintPathResult'
    },
    {
      '1': 'ValidateCode',
      '2': '.com.kcl.api.ValidateCodeArgs',
      '3': '.com.kcl.api.ValidateCodeResult'
    },
    {
      '1': 'LoadSettingsFiles',
      '2': '.com.kcl.api.LoadSettingsFilesArgs',
      '3': '.com.kcl.api.LoadSettingsFilesResult'
    },
    {
      '1': 'Rename',
      '2': '.com.kcl.api.RenameArgs',
      '3': '.com.kcl.api.RenameResult'
    },
    {
      '1': 'RenameCode',
      '2': '.com.kcl.api.RenameCodeArgs',
      '3': '.com.kcl.api.RenameCodeResult'
    },
    {'1': 'Test', '2': '.com.kcl.api.TestArgs', '3': '.com.kcl.api.TestResult'},
    {
      '1': 'FormatTestReport',
      '2': '.com.kcl.api.FormatTestReportArgs',
      '3': '.com.kcl.api.FormatTestReportResult'
    },
    {
      '1': 'UpdateDependencies',
      '2': '.com.kcl.api.UpdateDependenciesArgs',
      '3': '.com.kcl.api.UpdateDependenciesResult'
    },
    {
      '1': 'GenerateToml',
      '2': '.com.kcl.api.GenerateTomlArgs',
      '3': '.com.kcl.api.GenerateTomlResult'
    },
    {
      '1': 'GenerateKcl',
      '2': '.com.kcl.api.GenerateKclArgs',
      '3': '.com.kcl.api.GenerateKclResult'
    },
    {
      '1': 'GenerateOpenAPI',
      '2': '.com.kcl.api.GenerateOpenAPIArgs',
      '3': '.com.kcl.api.GenerateOpenAPIResult'
    },
    {
      '1': 'GenerateProto',
      '2': '.com.kcl.api.GenerateProtoArgs',
      '3': '.com.kcl.api.GenerateProtoResult'
    },
    {
      '1': 'GenerateDoc',
      '2': '.com.kcl.api.GenerateDocArgs',
      '3': '.com.kcl.api.GenerateDocResult'
    },
  ],
};

@$core.Deprecated('Use kclServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    KclServiceBase$messageJson = {
  '.com.kcl.api.PingArgs': PingArgs$json,
  '.com.kcl.api.PingResult': PingResult$json,
  '.com.kcl.api.GetVersionArgs': GetVersionArgs$json,
  '.com.kcl.api.GetVersionResult': GetVersionResult$json,
  '.com.kcl.api.ParseProgramArgs': ParseProgramArgs$json,
  '.com.kcl.api.ExternalPkg': ExternalPkg$json,
  '.com.kcl.api.ParseProgramResult': ParseProgramResult$json,
  '.com.kcl.api.Error': Error$json,
  '.com.kcl.api.Message': Message$json,
  '.com.kcl.api.Position': Position$json,
  '.com.kcl.api.ParseFileArgs': ParseFileArgs$json,
  '.com.kcl.api.ParseFileResult': ParseFileResult$json,
  '.com.kcl.api.LoadPackageArgs': LoadPackageArgs$json,
  '.com.kcl.api.LoadPackageResult': LoadPackageResult$json,
  '.com.kcl.api.LoadPackageResult.ScopesEntry':
      LoadPackageResult_ScopesEntry$json,
  '.com.kcl.api.Scope': Scope$json,
  '.com.kcl.api.ScopeIndex': ScopeIndex$json,
  '.com.kcl.api.SymbolIndex': SymbolIndex$json,
  '.com.kcl.api.LoadPackageResult.SymbolsEntry':
      LoadPackageResult_SymbolsEntry$json,
  '.com.kcl.api.Symbol': Symbol$json,
  '.com.kcl.api.KclType': KclType$json,
  '.com.kcl.api.KclType.PropertiesEntry': KclType_PropertiesEntry$json,
  '.com.kcl.api.Decorator': Decorator$json,
  '.com.kcl.api.Decorator.KeywordsEntry': Decorator_KeywordsEntry$json,
  '.com.kcl.api.KclType.ExamplesEntry': KclType_ExamplesEntry$json,
  '.com.kcl.api.Example': Example$json,
  '.com.kcl.api.FunctionType': FunctionType$json,
  '.com.kcl.api.Parameter': Parameter$json,
  '.com.kcl.api.IndexSignature': IndexSignature$json,
  '.com.kcl.api.LoadPackageResult.NodeSymbolMapEntry':
      LoadPackageResult_NodeSymbolMapEntry$json,
  '.com.kcl.api.LoadPackageResult.SymbolNodeMapEntry':
      LoadPackageResult_SymbolNodeMapEntry$json,
  '.com.kcl.api.LoadPackageResult.FullyQualifiedNameMapEntry':
      LoadPackageResult_FullyQualifiedNameMapEntry$json,
  '.com.kcl.api.LoadPackageResult.PkgScopeMapEntry':
      LoadPackageResult_PkgScopeMapEntry$json,
  '.com.kcl.api.LoadPackageResult.ImportsEntry':
      LoadPackageResult_ImportsEntry$json,
  '.com.kcl.api.FileImports': FileImports$json,
  '.com.kcl.api.ImportInfo': ImportInfo$json,
  '.com.kcl.api.KclMod': KclMod$json,
  '.com.kcl.api.KclModPackage': KclModPackage$json,
  '.com.kcl.api.KclModProfile': KclModProfile$json,
  '.com.kcl.api.KclMod.DependenciesEntry': KclMod_DependenciesEntry$json,
  '.com.kcl.api.KclModDependency': KclModDependency$json,
  '.com.kcl.api.KclModGitSource': KclModGitSource$json,
  '.com.kcl.api.KclModOciSource': KclModOciSource$json,
  '.com.kcl.api.KclModLocalSource': KclModLocalSource$json,
  '.com.kcl.api.AppInfo': AppInfo$json,
  '.com.kcl.api.ListOptionsResult': ListOptionsResult$json,
  '.com.kcl.api.OptionHelp': OptionHelp$json,
  '.com.kcl.api.ListVariablesArgs': ListVariablesArgs$json,
  '.com.kcl.api.ListVariablesOptions': ListVariablesOptions$json,
  '.com.kcl.api.ListVariablesResult': ListVariablesResult$json,
  '.com.kcl.api.ListVariablesResult.VariablesEntry':
      ListVariablesResult_VariablesEntry$json,
  '.com.kcl.api.VariableList': VariableList$json,
  '.com.kcl.api.Variable': Variable$json,
  '.com.kcl.api.MapEntry': MapEntry$json,
  '.com.kcl.api.ExecProgramArgs': ExecProgramArgs$json,
  '.com.kcl.api.Argument': Argument$json,
  '.com.kcl.api.ExecProgramResult': ExecProgramResult$json,
  '.com.kcl.api.OverrideFileArgs': OverrideFileArgs$json,
  '.com.kcl.api.OverrideFileResult': OverrideFileResult$json,
  '.com.kcl.api.GetSchemaTypeMappingArgs': GetSchemaTypeMappingArgs$json,
  '.com.kcl.api.GetSchemaTypeMappingResult': GetSchemaTypeMappingResult$json,
  '.com.kcl.api.GetSchemaTypeMappingResult.SchemaTypeMappingEntry':
      GetSchemaTypeMappingResult_SchemaTypeMappingEntry$json,
  '.com.kcl.api.GetSchemaTypeMappingUnderPathResult':
      GetSchemaTypeMappingUnderPathResult$json,
  '.com.kcl.api.GetSchemaTypeMappingUnderPathResult.SchemaTypeMappingEntry':
      GetSchemaTypeMappingUnderPathResult_SchemaTypeMappingEntry$json,
  '.com.kcl.api.SchemaTypes': SchemaTypes$json,
  '.com.kcl.api.FormatCodeArgs': FormatCodeArgs$json,
  '.com.kcl.api.FormatCodeResult': FormatCodeResult$json,
  '.com.kcl.api.FormatPathArgs': FormatPathArgs$json,
  '.com.kcl.api.FormatPathResult': FormatPathResult$json,
  '.com.kcl.api.LintPathArgs': LintPathArgs$json,
  '.com.kcl.api.LintPathResult': LintPathResult$json,
  '.com.kcl.api.ValidateCodeArgs': ValidateCodeArgs$json,
  '.com.kcl.api.ValidateCodeResult': ValidateCodeResult$json,
  '.com.kcl.api.LoadSettingsFilesArgs': LoadSettingsFilesArgs$json,
  '.com.kcl.api.LoadSettingsFilesResult': LoadSettingsFilesResult$json,
  '.com.kcl.api.CliConfig': CliConfig$json,
  '.com.kcl.api.KeyValuePair': KeyValuePair$json,
  '.com.kcl.api.RenameArgs': RenameArgs$json,
  '.com.kcl.api.RenameResult': RenameResult$json,
  '.com.kcl.api.RenameCodeArgs': RenameCodeArgs$json,
  '.com.kcl.api.RenameCodeArgs.SourceCodesEntry':
      RenameCodeArgs_SourceCodesEntry$json,
  '.com.kcl.api.RenameCodeResult': RenameCodeResult$json,
  '.com.kcl.api.RenameCodeResult.ChangedCodesEntry':
      RenameCodeResult_ChangedCodesEntry$json,
  '.com.kcl.api.TestArgs': TestArgs$json,
  '.com.kcl.api.TestResult': TestResult$json,
  '.com.kcl.api.TestCaseInfo': TestCaseInfo$json,
  '.com.kcl.api.TestCaseInfo.LineHitsEntry': TestCaseInfo_LineHitsEntry$json,
  '.com.kcl.api.TestCoverageReport': TestCoverageReport$json,
  '.com.kcl.api.TestCoverageReport.FilesEntry':
      TestCoverageReport_FilesEntry$json,
  '.com.kcl.api.FileCoverage': FileCoverage$json,
  '.com.kcl.api.FileCoverage.LineHitsEntry': FileCoverage_LineHitsEntry$json,
  '.com.kcl.api.CoverageSummary': CoverageSummary$json,
  '.com.kcl.api.FormatTestReportArgs': FormatTestReportArgs$json,
  '.com.kcl.api.FormatTestReportResult': FormatTestReportResult$json,
  '.com.kcl.api.UpdateDependenciesArgs': UpdateDependenciesArgs$json,
  '.com.kcl.api.UpdateDependenciesResult': UpdateDependenciesResult$json,
  '.com.kcl.api.GenerateTomlArgs': GenerateTomlArgs$json,
  '.com.kcl.api.GenerateTomlResult': GenerateTomlResult$json,
  '.com.kcl.api.GenerateKclArgs': GenerateKclArgs$json,
  '.com.kcl.api.GenerateKclResult': GenerateKclResult$json,
  '.com.kcl.api.GenerateOpenAPIArgs': GenerateOpenAPIArgs$json,
  '.com.kcl.api.GenerateOpenAPIResult': GenerateOpenAPIResult$json,
  '.com.kcl.api.GenerateProtoArgs': GenerateProtoArgs$json,
  '.com.kcl.api.GenerateProtoResult': GenerateProtoResult$json,
  '.com.kcl.api.GenerateDocArgs': GenerateDocArgs$json,
  '.com.kcl.api.GenerateDocResult': GenerateDocResult$json,
};

/// Descriptor for `KclService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List kclServiceDescriptor = $convert.base64Decode(
    'CgpLY2xTZXJ2aWNlEjYKBFBpbmcSFS5jb20ua2NsLmFwaS5QaW5nQXJncxoXLmNvbS5rY2wuYX'
    'BpLlBpbmdSZXN1bHQSSAoKR2V0VmVyc2lvbhIbLmNvbS5rY2wuYXBpLkdldFZlcnNpb25Bcmdz'
    'Gh0uY29tLmtjbC5hcGkuR2V0VmVyc2lvblJlc3VsdBJOCgxQYXJzZVByb2dyYW0SHS5jb20ua2'
    'NsLmFwaS5QYXJzZVByb2dyYW1BcmdzGh8uY29tLmtjbC5hcGkuUGFyc2VQcm9ncmFtUmVzdWx0'
    'EkUKCVBhcnNlRmlsZRIaLmNvbS5rY2wuYXBpLlBhcnNlRmlsZUFyZ3MaHC5jb20ua2NsLmFwaS'
    '5QYXJzZUZpbGVSZXN1bHQSSwoLTG9hZFBhY2thZ2USHC5jb20ua2NsLmFwaS5Mb2FkUGFja2Fn'
    'ZUFyZ3MaHi5jb20ua2NsLmFwaS5Mb2FkUGFja2FnZVJlc3VsdBJMCgtMaXN0T3B0aW9ucxIdLm'
    'NvbS5rY2wuYXBpLlBhcnNlUHJvZ3JhbUFyZ3MaHi5jb20ua2NsLmFwaS5MaXN0T3B0aW9uc1Jl'
    'c3VsdBJRCg1MaXN0VmFyaWFibGVzEh4uY29tLmtjbC5hcGkuTGlzdFZhcmlhYmxlc0FyZ3MaIC'
    '5jb20ua2NsLmFwaS5MaXN0VmFyaWFibGVzUmVzdWx0EksKC0V4ZWNQcm9ncmFtEhwuY29tLmtj'
    'bC5hcGkuRXhlY1Byb2dyYW1BcmdzGh4uY29tLmtjbC5hcGkuRXhlY1Byb2dyYW1SZXN1bHQSTg'
    'oMT3ZlcnJpZGVGaWxlEh0uY29tLmtjbC5hcGkuT3ZlcnJpZGVGaWxlQXJncxofLmNvbS5rY2wu'
    'YXBpLk92ZXJyaWRlRmlsZVJlc3VsdBJmChRHZXRTY2hlbWFUeXBlTWFwcGluZxIlLmNvbS5rY2'
    'wuYXBpLkdldFNjaGVtYVR5cGVNYXBwaW5nQXJncxonLmNvbS5rY2wuYXBpLkdldFNjaGVtYVR5'
    'cGVNYXBwaW5nUmVzdWx0EngKHUdldFNjaGVtYVR5cGVNYXBwaW5nVW5kZXJQYXRoEiUuY29tLm'
    'tjbC5hcGkuR2V0U2NoZW1hVHlwZU1hcHBpbmdBcmdzGjAuY29tLmtjbC5hcGkuR2V0U2NoZW1h'
    'VHlwZU1hcHBpbmdVbmRlclBhdGhSZXN1bHQSSAoKRm9ybWF0Q29kZRIbLmNvbS5rY2wuYXBpLk'
    'Zvcm1hdENvZGVBcmdzGh0uY29tLmtjbC5hcGkuRm9ybWF0Q29kZVJlc3VsdBJICgpGb3JtYXRQ'
    'YXRoEhsuY29tLmtjbC5hcGkuRm9ybWF0UGF0aEFyZ3MaHS5jb20ua2NsLmFwaS5Gb3JtYXRQYX'
    'RoUmVzdWx0EkIKCExpbnRQYXRoEhkuY29tLmtjbC5hcGkuTGludFBhdGhBcmdzGhsuY29tLmtj'
    'bC5hcGkuTGludFBhdGhSZXN1bHQSTgoMVmFsaWRhdGVDb2RlEh0uY29tLmtjbC5hcGkuVmFsaW'
    'RhdGVDb2RlQXJncxofLmNvbS5rY2wuYXBpLlZhbGlkYXRlQ29kZVJlc3VsdBJdChFMb2FkU2V0'
    'dGluZ3NGaWxlcxIiLmNvbS5rY2wuYXBpLkxvYWRTZXR0aW5nc0ZpbGVzQXJncxokLmNvbS5rY2'
    'wuYXBpLkxvYWRTZXR0aW5nc0ZpbGVzUmVzdWx0EjwKBlJlbmFtZRIXLmNvbS5rY2wuYXBpLlJl'
    'bmFtZUFyZ3MaGS5jb20ua2NsLmFwaS5SZW5hbWVSZXN1bHQSSAoKUmVuYW1lQ29kZRIbLmNvbS'
    '5rY2wuYXBpLlJlbmFtZUNvZGVBcmdzGh0uY29tLmtjbC5hcGkuUmVuYW1lQ29kZVJlc3VsdBI2'
    'CgRUZXN0EhUuY29tLmtjbC5hcGkuVGVzdEFyZ3MaFy5jb20ua2NsLmFwaS5UZXN0UmVzdWx0El'
    'oKEEZvcm1hdFRlc3RSZXBvcnQSIS5jb20ua2NsLmFwaS5Gb3JtYXRUZXN0UmVwb3J0QXJncxoj'
    'LmNvbS5rY2wuYXBpLkZvcm1hdFRlc3RSZXBvcnRSZXN1bHQSYAoSVXBkYXRlRGVwZW5kZW5jaW'
    'VzEiMuY29tLmtjbC5hcGkuVXBkYXRlRGVwZW5kZW5jaWVzQXJncxolLmNvbS5rY2wuYXBpLlVw'
    'ZGF0ZURlcGVuZGVuY2llc1Jlc3VsdBJOCgxHZW5lcmF0ZVRvbWwSHS5jb20ua2NsLmFwaS5HZW'
    '5lcmF0ZVRvbWxBcmdzGh8uY29tLmtjbC5hcGkuR2VuZXJhdGVUb21sUmVzdWx0EksKC0dlbmVy'
    'YXRlS2NsEhwuY29tLmtjbC5hcGkuR2VuZXJhdGVLY2xBcmdzGh4uY29tLmtjbC5hcGkuR2VuZX'
    'JhdGVLY2xSZXN1bHQSVwoPR2VuZXJhdGVPcGVuQVBJEiAuY29tLmtjbC5hcGkuR2VuZXJhdGVP'
    'cGVuQVBJQXJncxoiLmNvbS5rY2wuYXBpLkdlbmVyYXRlT3BlbkFQSVJlc3VsdBJRCg1HZW5lcm'
    'F0ZVByb3RvEh4uY29tLmtjbC5hcGkuR2VuZXJhdGVQcm90b0FyZ3MaIC5jb20ua2NsLmFwaS5H'
    'ZW5lcmF0ZVByb3RvUmVzdWx0EksKC0dlbmVyYXRlRG9jEhwuY29tLmtjbC5hcGkuR2VuZXJhdG'
    'VEb2NBcmdzGh4uY29tLmtjbC5hcGkuR2VuZXJhdGVEb2NSZXN1bHQ=');
