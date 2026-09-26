import {
  ProtoReader,
  boolField,
  bytesField,
  concatBytes,
  int64Field,
  stringField,
} from "./protobuf";
import { invokeKCLCallNative } from "./index";

export interface ExternalPkg {
  pkgName: string;
  pkgPath: string;
}

export interface Argument {
  name: string;
  value: string;
}

export interface Position {
  line: number;
  column: number;
  filename: string;
}

export interface KclErrorMessage {
  msg: string;
  pos?: Position;
}

export interface KclError {
  level: string;
  code: string;
  messages: KclErrorMessage[];
}

export interface PingArgs {
  value?: string;
}

export interface PingResult {
  value: string;
}

export interface GetVersionResult {
  version: string;
  checksum: string;
  gitSha: string;
  versionInfo: string;
}

export interface ParseProgramArgs {
  paths?: string[];
  sources?: string[];
  externalPkgs?: ExternalPkg[];
}

export interface ParseProgramResult {
  astJson: string;
  paths: string[];
  errors: KclError[];
}

export interface ParseFileArgs {
  path?: string;
  source?: string;
  externalPkgs?: ExternalPkg[];
}

export interface ParseFileResult {
  astJson: string;
  deps: string[];
  errors: KclError[];
}

export interface LoadPackageArgs {
  parseArgs?: ParseProgramArgs;
  resolveAst?: boolean;
  loadBuiltin?: boolean;
  withAstIndex?: boolean;
}

export interface LoadPackageResult {
  program: string;
  paths: string[];
  parseErrors: KclError[];
  typeErrors: KclError[];
  scopes: Record<string, Scope>;
  symbols: Record<string, Symbol>;
  nodeSymbolMap: Record<string, SymbolIndex>;
  symbolNodeMap: Record<string, string>;
  fullyQualifiedNameMap: Record<string, SymbolIndex>;
  pkgScopeMap: Record<string, ScopeIndex>;
}

export interface OptionHelp {
  name: string;
  type: string;
  required: boolean;
  defaultValue: string;
  help: string;
}

export interface ListOptionsResult {
  options: OptionHelp[];
}

export interface ListVariablesOptions {
  mergeProgram?: boolean;
}

export interface ListVariablesArgs {
  files?: string[];
  specs?: string[];
  options?: ListVariablesOptions;
}

export interface Variable {
  value: string;
  typeName: string;
  opSym: string;
  listItems: Variable[];
  dictEntries: MapEntry[];
}

export interface MapEntry {
  key: string;
  value?: Variable;
}

export interface ListVariablesResult {
  variables: Record<string, Variable[]>;
  unsupportedCodes: string[];
  parseErrors: KclError[];
}

export interface OverrideFileArgs {
  file?: string;
  specs?: string[];
  importPaths?: string[];
}

export interface OverrideFileResult {
  result: boolean;
  parseErrors: KclError[];
}

export interface ExecProgramArgs {
  workDir?: string;
  kFilenameList?: string[];
  kCodeList?: string[];
  args?: Argument[];
  overrides?: string[];
  disableYamlResult?: boolean;
  printOverrideAst?: boolean;
  strictRangeCheck?: boolean;
  disableNone?: boolean;
  verbose?: number;
  debug?: number;
  sortKeys?: boolean;
  externalPkgs?: ExternalPkg[];
  includeSchemaTypePath?: boolean;
  compileOnly?: boolean;
  showHidden?: boolean;
  pathSelector?: string[];
  fastEval?: boolean;
  errorFormat?: string;
}

export interface GetSchemaTypeMappingArgs {
  execArgs?: ExecProgramArgs;
  schemaName?: string;
}

export interface GetSchemaTypeMappingResult {
  schemaTypeMapping: Record<string, KclType>;
}

export interface SchemaTypes {
  schemaType: KclType[];
}

export interface GetSchemaTypeMappingUnderPathResult {
  schemaTypeMapping: Record<string, SchemaTypes>;
}

export interface FormatPathArgs {
  path?: string;
  dryRun?: boolean;
}

export interface FormatPathResult {
  changedPaths: string[];
}

export interface LintPathArgs {
  paths?: string[];
}

export interface LintPathResult {
  results: string[];
}

export interface ValidateCodeArgs {
  datafile?: string;
  data?: string;
  file?: string;
  code?: string;
  schema?: string;
  attributeName?: string;
  format?: string;
  externalPkgs?: ExternalPkg[];
}

export interface ValidateCodeResult {
  success: boolean;
  errMessage: string;
}

export interface LoadSettingsFilesArgs {
  workDir?: string;
  files?: string[];
}

export interface CliConfig {
  files: string[];
  output: string;
  overrides: string[];
  pathSelector: string[];
  strictRangeCheck: boolean;
  disableNone: boolean;
  verbose: number;
  debug: boolean;
  sortKeys: boolean;
  showHidden: boolean;
  includeSchemaTypePath: boolean;
  fastEval: boolean;
}

export interface KeyValuePair {
  key: string;
  value: string;
}

export interface LoadSettingsFilesResult {
  kclCliConfigs: CliConfig;
  kclOptions: KeyValuePair[];
}

export interface RenameArgs {
  packageRoot?: string;
  symbolPath?: string;
  filePaths?: string[];
  newName?: string;
}

export interface RenameResult {
  changedFiles: string[];
}

export interface RenameCodeArgs {
  packageRoot?: string;
  symbolPath?: string;
  sourceCodes?: Record<string, string>;
  newName?: string;
}

export interface RenameCodeResult {
  changedCodes: Record<string, string>;
}

export interface TestArgs {
  execArgs?: ExecProgramArgs;
  pkgList?: string[];
  runRegexp?: string;
  failFast?: boolean;
}

export interface TestCaseInfo {
  name: string;
  error: string;
  duration: number;
  logMessage: string;
}

export interface TestResult {
  info: TestCaseInfo[];
}

export interface UpdateDependenciesArgs {
  manifestPath?: string;
  vendor?: boolean;
}

export interface UpdateDependenciesResult {
  externalPkgs: ExternalPkg[];
}

export interface SymbolIndex {
  i: number;
  g: number;
  kind: string;
}

export interface ScopeIndex {
  i: number;
  g: number;
  kind: string;
}

export interface Symbol {
  ty?: KclType;
  name: string;
  owner?: SymbolIndex;
  def?: SymbolIndex;
  attrs: SymbolIndex[];
  isGlobal: boolean;
}

export interface Scope {
  kind: string;
  parent?: ScopeIndex;
  owner?: SymbolIndex;
  children: ScopeIndex[];
  defs: SymbolIndex[];
}

export interface Decorator {
  name: string;
  arguments: string[];
  keywords: Record<string, string>;
}

export interface Example {
  summary: string;
  description: string;
  value: string;
}

export interface Parameter {
  name: string;
  ty?: KclType;
}

export interface FunctionType {
  params: Parameter[];
  returnTy?: KclType;
}

export interface IndexSignature {
  keyName?: string;
  key?: KclType;
  val?: KclType;
  anyOther: boolean;
}

export interface KclType {
  type: string;
  unionTypes: KclType[];
  default: string;
  schemaName: string;
  schemaDoc: string;
  properties: Record<string, KclType>;
  required: string[];
  key?: KclType;
  item?: KclType;
  line: number;
  decorators: Decorator[];
  filename: string;
  pkgPath: string;
  description: string;
  examples: Record<string, Example>;
  baseSchema?: KclType;
  function?: FunctionType;
  indexSignature?: IndexSignature;
}

const KCL_SERVICE = "KclService.";

function encodeExternalPkg(pkg: ExternalPkg): Uint8Array {
  return concatBytes(stringField(1, pkg.pkgName), stringField(2, pkg.pkgPath));
}

function encodeExternalPkgs(field: number, pkgs?: ExternalPkg[]): Uint8Array {
  return concatBytes(
    ...(pkgs ?? []).map((p) => bytesField(field, encodeExternalPkg(p)))
  );
}

function encodeStringList(field: number, values?: string[]): Uint8Array {
  return concatBytes(...(values ?? []).map((v) => stringField(field, v)));
}

function encodeArgument(arg: Argument): Uint8Array {
  return concatBytes(stringField(1, arg.name), stringField(2, arg.value));
}

function encodeParseProgramArgs(args: ParseProgramArgs): Uint8Array {
  return concatBytes(
    encodeStringList(1, args.paths),
    encodeStringList(2, args.sources),
    encodeExternalPkgs(3, args.externalPkgs)
  );
}

function encodeExecProgramArgs(args: ExecProgramArgs): Uint8Array {
  return concatBytes(
    stringField(1, args.workDir),
    encodeStringList(2, args.kFilenameList),
    encodeStringList(3, args.kCodeList),
    concatBytes(
      ...(args.args ?? []).map((a) => bytesField(4, encodeArgument(a)))
    ),
    encodeStringList(5, args.overrides),
    boolField(6, args.disableYamlResult ?? false),
    boolField(7, args.printOverrideAst ?? false),
    boolField(8, args.strictRangeCheck ?? false),
    boolField(9, args.disableNone ?? false),
    int64Field(10, args.verbose ?? 0),
    int64Field(11, args.debug ?? 0),
    boolField(12, args.sortKeys ?? false),
    encodeExternalPkgs(13, args.externalPkgs),
    boolField(14, args.includeSchemaTypePath ?? false),
    boolField(15, args.compileOnly ?? false),
    boolField(16, args.showHidden ?? false),
    encodeStringList(17, args.pathSelector),
    boolField(18, args.fastEval ?? false),
    stringField(19, args.errorFormat)
  );
}

function decodePosition(r: ProtoReader): Position {
  const pos: Position = { line: 0, column: 0, filename: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        pos.line = r.readInt64();
        break;
      case 2:
        pos.column = r.readInt64();
        break;
      case 3:
        pos.filename = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return pos;
}

function decodeErrorMessage(r: ProtoReader): KclErrorMessage {
  const msg: KclErrorMessage = { msg: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        msg.msg = r.readString();
        break;
      case 2:
        msg.pos = decodePosition(r.readMessage());
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return msg;
}

function decodeError(r: ProtoReader): KclError {
  const err: KclError = { level: "", code: "", messages: [] };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        err.level = r.readString();
        break;
      case 2:
        err.code = r.readString();
        break;
      case 3:
        err.messages.push(decodeErrorMessage(r.readMessage()));
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return err;
}

function decodeExternalPkg(r: ProtoReader): ExternalPkg {
  const pkg: ExternalPkg = { pkgName: "", pkgPath: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        pkg.pkgName = r.readString();
        break;
      case 2:
        pkg.pkgPath = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return pkg;
}

function decodeSymbolIndex(r: ProtoReader): SymbolIndex {
  const idx: SymbolIndex = { i: 0, g: 0, kind: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        idx.i = r.readUint64();
        break;
      case 2:
        idx.g = r.readUint64();
        break;
      case 3:
        idx.kind = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return idx;
}

function decodeScopeIndex(r: ProtoReader): ScopeIndex {
  const idx: ScopeIndex = { i: 0, g: 0, kind: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        idx.i = r.readUint64();
        break;
      case 2:
        idx.g = r.readUint64();
        break;
      case 3:
        idx.kind = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return idx;
}

function decodeDecorator(r: ProtoReader): Decorator {
  const dec: Decorator = { name: "", arguments: [], keywords: {} };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        dec.name = r.readString();
        break;
      case 2:
        dec.arguments.push(r.readString());
        break;
      case 3: {
        const entry = r.readMessage();
        let key = "";
        let value = "";
        while (!entry.eof) {
          const t = entry.readTag();
          if (t >>> 3 === 1) key = entry.readString();
          else if (t >>> 3 === 2) value = entry.readString();
          else entry.skip(t & 7);
        }
        dec.keywords[key] = value;
        break;
      }
      default:
        r.skip(tag & 7);
    }
  }
  return dec;
}

function decodeExample(r: ProtoReader): Example {
  const ex: Example = { summary: "", description: "", value: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        ex.summary = r.readString();
        break;
      case 2:
        ex.description = r.readString();
        break;
      case 3:
        ex.value = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return ex;
}

function decodeParameter(r: ProtoReader): Parameter {
  const param: Parameter = { name: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        param.name = r.readString();
        break;
      case 2:
        param.ty = decodeKclType(r.readMessage());
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return param;
}

function decodeFunctionType(r: ProtoReader): FunctionType {
  const fn: FunctionType = { params: [] };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        fn.params.push(decodeParameter(r.readMessage()));
        break;
      case 2:
        fn.returnTy = decodeKclType(r.readMessage());
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return fn;
}

function decodeIndexSignature(r: ProtoReader): IndexSignature {
  const sig: IndexSignature = { anyOther: false };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        sig.keyName = r.readString();
        break;
      case 2:
        sig.key = decodeKclType(r.readMessage());
        break;
      case 3:
        sig.val = decodeKclType(r.readMessage());
        break;
      case 4:
        sig.anyOther = r.readBool();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return sig;
}

function decodeKclType(r: ProtoReader): KclType {
  const ty: KclType = {
    type: "",
    unionTypes: [],
    default: "",
    schemaName: "",
    schemaDoc: "",
    properties: {},
    required: [],
    decorators: [],
    filename: "",
    pkgPath: "",
    description: "",
    examples: {},
    line: 0,
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        ty.type = r.readString();
        break;
      case 2:
        ty.unionTypes.push(decodeKclType(r.readMessage()));
        break;
      case 3:
        ty.default = r.readString();
        break;
      case 4:
        ty.schemaName = r.readString();
        break;
      case 5:
        ty.schemaDoc = r.readString();
        break;
      case 6: {
        const entry = r.readMessage();
        let key = "";
        let value: KclType | undefined;
        while (!entry.eof) {
          const t = entry.readTag();
          if (t >>> 3 === 1) key = entry.readString();
          else if (t >>> 3 === 2) value = decodeKclType(entry.readMessage());
          else entry.skip(t & 7);
        }
        ty.properties[key] = value as KclType;
        break;
      }
      case 7:
        ty.required.push(r.readString());
        break;
      case 8:
        ty.key = decodeKclType(r.readMessage());
        break;
      case 9:
        ty.item = decodeKclType(r.readMessage());
        break;
      case 10:
        ty.line = r.readInt64();
        break;
      case 11:
        ty.decorators.push(decodeDecorator(r.readMessage()));
        break;
      case 12:
        ty.filename = r.readString();
        break;
      case 13:
        ty.pkgPath = r.readString();
        break;
      case 14:
        ty.description = r.readString();
        break;
      case 15: {
        const entry = r.readMessage();
        let key = "";
        let value: Example | undefined;
        while (!entry.eof) {
          const t = entry.readTag();
          if (t >>> 3 === 1) key = entry.readString();
          else if (t >>> 3 === 2) value = decodeExample(entry.readMessage());
          else entry.skip(t & 7);
        }
        ty.examples[key] = value as Example;
        break;
      }
      case 16:
        ty.baseSchema = decodeKclType(r.readMessage());
        break;
      case 17:
        ty.function = decodeFunctionType(r.readMessage());
        break;
      case 18:
        ty.indexSignature = decodeIndexSignature(r.readMessage());
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return ty;
}

function decodeSymbol(r: ProtoReader): Symbol {
  const sym: Symbol = { name: "", attrs: [], isGlobal: false };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        sym.ty = decodeKclType(r.readMessage());
        break;
      case 2:
        sym.name = r.readString();
        break;
      case 3:
        sym.owner = decodeSymbolIndex(r.readMessage());
        break;
      case 4:
        sym.def = decodeSymbolIndex(r.readMessage());
        break;
      case 5:
        sym.attrs.push(decodeSymbolIndex(r.readMessage()));
        break;
      case 6:
        sym.isGlobal = r.readBool();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return sym;
}

function decodeScope(r: ProtoReader): Scope {
  const scope: Scope = { kind: "", children: [], defs: [] };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        scope.kind = r.readString();
        break;
      case 2:
        scope.parent = decodeScopeIndex(r.readMessage());
        break;
      case 3:
        scope.owner = decodeSymbolIndex(r.readMessage());
        break;
      case 4:
        scope.children.push(decodeScopeIndex(r.readMessage()));
        break;
      case 5:
        scope.defs.push(decodeSymbolIndex(r.readMessage()));
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return scope;
}

function decodeOptionHelp(r: ProtoReader): OptionHelp {
  const opt: OptionHelp = {
    name: "",
    type: "",
    required: false,
    defaultValue: "",
    help: "",
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        opt.name = r.readString();
        break;
      case 2:
        opt.type = r.readString();
        break;
      case 3:
        opt.required = r.readBool();
        break;
      case 4:
        opt.defaultValue = r.readString();
        break;
      case 5:
        opt.help = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return opt;
}

function decodeVariable(r: ProtoReader): Variable {
  const v: Variable = {
    value: "",
    typeName: "",
    opSym: "",
    listItems: [],
    dictEntries: [],
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        v.value = r.readString();
        break;
      case 2:
        v.typeName = r.readString();
        break;
      case 3:
        v.opSym = r.readString();
        break;
      case 4:
        v.listItems.push(decodeVariable(r.readMessage()));
        break;
      case 5: {
        const entry = r.readMessage();
        const e: MapEntry = { key: "" };
        while (!entry.eof) {
          const t = entry.readTag();
          if (t >>> 3 === 1) e.key = entry.readString();
          else if (t >>> 3 === 2) e.value = decodeVariable(entry.readMessage());
          else entry.skip(t & 7);
        }
        v.dictEntries.push(e);
        break;
      }
      default:
        r.skip(tag & 7);
    }
  }
  return v;
}

function decodeCliConfig(r: ProtoReader): CliConfig {
  const cfg: CliConfig = {
    files: [],
    output: "",
    overrides: [],
    pathSelector: [],
    strictRangeCheck: false,
    disableNone: false,
    verbose: 0,
    debug: false,
    sortKeys: false,
    showHidden: false,
    includeSchemaTypePath: false,
    fastEval: false,
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        cfg.files.push(r.readString());
        break;
      case 2:
        cfg.output = r.readString();
        break;
      case 3:
        cfg.overrides.push(r.readString());
        break;
      case 4:
        cfg.pathSelector.push(r.readString());
        break;
      case 5:
        cfg.strictRangeCheck = r.readBool();
        break;
      case 6:
        cfg.disableNone = r.readBool();
        break;
      case 7:
        cfg.verbose = r.readInt64();
        break;
      case 8:
        cfg.debug = r.readBool();
        break;
      case 9:
        cfg.sortKeys = r.readBool();
        break;
      case 10:
        cfg.showHidden = r.readBool();
        break;
      case 11:
        cfg.includeSchemaTypePath = r.readBool();
        break;
      case 12:
        cfg.fastEval = r.readBool();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return cfg;
}

function decodeKeyValuePair(r: ProtoReader): KeyValuePair {
  const kv: KeyValuePair = { key: "", value: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        kv.key = r.readString();
        break;
      case 2:
        kv.value = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return kv;
}

function decodeTestCaseInfo(r: ProtoReader): TestCaseInfo {
  const info: TestCaseInfo = {
    name: "",
    error: "",
    duration: 0,
    logMessage: "",
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        info.name = r.readString();
        break;
      case 2:
        info.error = r.readString();
        break;
      case 3:
        info.duration = r.readUint64();
        break;
      case 4:
        info.logMessage = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return info;
}

function decodeStringMapEntry<V>(
  r: ProtoReader,
  decodeValue: (m: ProtoReader) => V
): [string, V] {
  const entry = r.readMessage();
  let key = "";
  let value: V | undefined;
  while (!entry.eof) {
    const t = entry.readTag();
    if (t >>> 3 === 1) key = entry.readString();
    else if (t >>> 3 === 2) value = decodeValue(entry);
    else entry.skip(t & 7);
  }
  return [key, value as V];
}

function callService(
  instance: WebAssembly.Instance,
  method: string,
  args: Uint8Array,
  resultBufferSize?: number
): Uint8Array {
  const result = invokeKCLCallNative(instance, {
    methodName: KCL_SERVICE + method,
    args,
    resultBufferSize,
  });
  if (
    result.length >= 6 &&
    result[0] === 0x45 &&
    result[1] === 0x52 &&
    result[2] === 0x52 &&
    result[3] === 0x4f &&
    result[4] === 0x52 &&
    result[5] === 0x3a
  ) {
    throw new Error(new TextDecoder().decode(result.slice(6)));
  }
  return result;
}

export function ping(
  instance: WebAssembly.Instance,
  args: PingArgs = {}
): PingResult {
  const result = callService(
    instance,
    "Ping",
    stringField(1, args.value ?? "")
  );
  const r = new ProtoReader(result);
  const out: PingResult = { value: "" };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 1) out.value = r.readString();
    else r.skip(tag & 7);
  }
  return out;
}

export function getVersion(instance: WebAssembly.Instance): GetVersionResult {
  const result = callService(instance, "GetVersion", new Uint8Array(0));
  const r = new ProtoReader(result);
  const out: GetVersionResult = {
    version: "",
    checksum: "",
    gitSha: "",
    versionInfo: "",
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        out.version = r.readString();
        break;
      case 2:
        out.checksum = r.readString();
        break;
      case 3:
        out.gitSha = r.readString();
        break;
      case 4:
        out.versionInfo = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return out;
}

export function parseProgram(
  instance: WebAssembly.Instance,
  args: ParseProgramArgs
): ParseProgramResult {
  const result = callService(
    instance,
    "ParseProgram",
    encodeParseProgramArgs(args)
  );
  const r = new ProtoReader(result);
  const out: ParseProgramResult = { astJson: "", paths: [], errors: [] };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        out.astJson = r.readString();
        break;
      case 2:
        out.paths.push(r.readString());
        break;
      case 3:
        out.errors.push(decodeError(r.readMessage()));
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return out;
}

export function parseFile(
  instance: WebAssembly.Instance,
  args: ParseFileArgs
): ParseFileResult {
  const encoded = concatBytes(
    stringField(1, args.path ?? ""),
    stringField(2, args.source ?? ""),
    encodeExternalPkgs(3, args.externalPkgs)
  );
  const result = callService(instance, "ParseFile", encoded);
  const r = new ProtoReader(result);
  const out: ParseFileResult = { astJson: "", deps: [], errors: [] };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        out.astJson = r.readString();
        break;
      case 2:
        out.deps.push(r.readString());
        break;
      case 3:
        out.errors.push(decodeError(r.readMessage()));
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return out;
}

export function loadPackage(
  instance: WebAssembly.Instance,
  args: LoadPackageArgs,
  resultBufferSize?: number
): LoadPackageResult {
  const encoded = concatBytes(
    bytesField(
      1,
      args.parseArgs
        ? encodeParseProgramArgs(args.parseArgs)
        : new Uint8Array(0)
    ),
    boolField(2, args.resolveAst ?? false),
    boolField(3, args.loadBuiltin ?? false),
    boolField(4, args.withAstIndex ?? false)
  );
  const result = callService(
    instance,
    "LoadPackage",
    encoded,
    resultBufferSize
  );
  const r = new ProtoReader(result);
  const out: LoadPackageResult = {
    program: "",
    paths: [],
    parseErrors: [],
    typeErrors: [],
    scopes: {},
    symbols: {},
    nodeSymbolMap: {},
    symbolNodeMap: {},
    fullyQualifiedNameMap: {},
    pkgScopeMap: {},
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        out.program = r.readString();
        break;
      case 2:
        out.paths.push(r.readString());
        break;
      case 3:
        out.parseErrors.push(decodeError(r.readMessage()));
        break;
      case 4:
        out.typeErrors.push(decodeError(r.readMessage()));
        break;
      case 5: {
        const [k, v] = decodeStringMapEntry(r, (m) =>
          decodeScope(m.readMessage())
        );
        out.scopes[k] = v;
        break;
      }
      case 6: {
        const [k, v] = decodeStringMapEntry(r, (m) =>
          decodeSymbol(m.readMessage())
        );
        out.symbols[k] = v;
        break;
      }
      case 7: {
        const [k, v] = decodeStringMapEntry(r, (m) =>
          decodeSymbolIndex(m.readMessage())
        );
        out.nodeSymbolMap[k] = v;
        break;
      }
      case 8: {
        const [k, v] = decodeStringMapEntry(r, (m) => m.readString());
        out.symbolNodeMap[k] = v;
        break;
      }
      case 9: {
        const [k, v] = decodeStringMapEntry(r, (m) =>
          decodeSymbolIndex(m.readMessage())
        );
        out.fullyQualifiedNameMap[k] = v;
        break;
      }
      case 10: {
        const [k, v] = decodeStringMapEntry(r, (m) =>
          decodeScopeIndex(m.readMessage())
        );
        out.pkgScopeMap[k] = v;
        break;
      }
      default:
        r.skip(tag & 7);
    }
  }
  return out;
}

export function listOptions(
  instance: WebAssembly.Instance,
  args: ParseProgramArgs
): ListOptionsResult {
  const result = callService(
    instance,
    "ListOptions",
    encodeParseProgramArgs(args)
  );
  const r = new ProtoReader(result);
  const out: ListOptionsResult = { options: [] };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 2) out.options.push(decodeOptionHelp(r.readMessage()));
    else r.skip(tag & 7);
  }
  return out;
}

export function listVariables(
  instance: WebAssembly.Instance,
  args: ListVariablesArgs
): ListVariablesResult {
  const encoded = concatBytes(
    encodeStringList(1, args.files),
    encodeStringList(2, args.specs),
    args.options
      ? bytesField(3, boolField(1, args.options.mergeProgram ?? false))
      : new Uint8Array(0)
  );
  const result = callService(instance, "ListVariables", encoded);
  const r = new ProtoReader(result);
  const out: ListVariablesResult = {
    variables: {},
    unsupportedCodes: [],
    parseErrors: [],
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1: {
        const [k, v] = decodeStringMapEntry(r, (m) => {
          const list = m.readMessage();
          const vars: Variable[] = [];
          while (!list.eof) {
            const t = list.readTag();
            if (t >>> 3 === 1) vars.push(decodeVariable(list.readMessage()));
            else list.skip(t & 7);
          }
          return vars;
        });
        out.variables[k] = v;
        break;
      }
      case 2:
        out.unsupportedCodes.push(r.readString());
        break;
      case 3:
        out.parseErrors.push(decodeError(r.readMessage()));
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return out;
}

export function overrideFile(
  instance: WebAssembly.Instance,
  args: OverrideFileArgs
): OverrideFileResult {
  const encoded = concatBytes(
    stringField(1, args.file ?? ""),
    encodeStringList(2, args.specs),
    encodeStringList(3, args.importPaths)
  );
  const result = callService(instance, "OverrideFile", encoded);
  const r = new ProtoReader(result);
  const out: OverrideFileResult = { result: false, parseErrors: [] };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        out.result = r.readBool();
        break;
      case 2:
        out.parseErrors.push(decodeError(r.readMessage()));
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return out;
}

export function getSchemaTypeMapping(
  instance: WebAssembly.Instance,
  args: GetSchemaTypeMappingArgs
): GetSchemaTypeMappingResult {
  const encoded = concatBytes(
    bytesField(
      1,
      args.execArgs ? encodeExecProgramArgs(args.execArgs) : new Uint8Array(0)
    ),
    stringField(2, args.schemaName ?? "")
  );
  const result = callService(instance, "GetSchemaTypeMapping", encoded);
  const r = new ProtoReader(result);
  const out: GetSchemaTypeMappingResult = { schemaTypeMapping: {} };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 1) {
      const [k, v] = decodeStringMapEntry(r, (m) =>
        decodeKclType(m.readMessage())
      );
      out.schemaTypeMapping[k] = v;
    } else {
      r.skip(tag & 7);
    }
  }
  return out;
}

export function getSchemaTypeMappingUnderPath(
  instance: WebAssembly.Instance,
  args: GetSchemaTypeMappingArgs
): GetSchemaTypeMappingUnderPathResult {
  const encoded = concatBytes(
    bytesField(
      1,
      args.execArgs ? encodeExecProgramArgs(args.execArgs) : new Uint8Array(0)
    ),
    stringField(2, args.schemaName ?? "")
  );
  const result = callService(
    instance,
    "GetSchemaTypeMappingUnderPath",
    encoded
  );
  const r = new ProtoReader(result);
  const out: GetSchemaTypeMappingUnderPathResult = { schemaTypeMapping: {} };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 1) {
      const [k, v] = decodeStringMapEntry(r, (m) => {
        const list = m.readMessage();
        const st: SchemaTypes = { schemaType: [] };
        while (!list.eof) {
          const t = list.readTag();
          if (t >>> 3 === 1)
            st.schemaType.push(decodeKclType(list.readMessage()));
          else list.skip(t & 7);
        }
        return st;
      });
      out.schemaTypeMapping[k] = v;
    } else {
      r.skip(tag & 7);
    }
  }
  return out;
}

export function formatPath(
  instance: WebAssembly.Instance,
  args: FormatPathArgs
): FormatPathResult {
  const encoded = concatBytes(
    stringField(1, args.path ?? ""),
    boolField(2, args.dryRun ?? false)
  );
  const result = callService(instance, "FormatPath", encoded);
  const r = new ProtoReader(result);
  const out: FormatPathResult = { changedPaths: [] };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 1) out.changedPaths.push(r.readString());
    else r.skip(tag & 7);
  }
  return out;
}

export function lintPath(
  instance: WebAssembly.Instance,
  args: LintPathArgs
): LintPathResult {
  const result = callService(
    instance,
    "LintPath",
    encodeStringList(1, args.paths)
  );
  const r = new ProtoReader(result);
  const out: LintPathResult = { results: [] };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 1) out.results.push(r.readString());
    else r.skip(tag & 7);
  }
  return out;
}

export function validateCode(
  instance: WebAssembly.Instance,
  args: ValidateCodeArgs
): ValidateCodeResult {
  const encoded = concatBytes(
    stringField(1, args.datafile ?? ""),
    stringField(2, args.data ?? ""),
    stringField(3, args.file ?? ""),
    stringField(4, args.code ?? ""),
    stringField(5, args.schema ?? ""),
    stringField(6, args.attributeName ?? ""),
    stringField(7, args.format ?? ""),
    encodeExternalPkgs(8, args.externalPkgs)
  );
  const result = callService(instance, "ValidateCode", encoded);
  const r = new ProtoReader(result);
  const out: ValidateCodeResult = { success: false, errMessage: "" };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        out.success = r.readBool();
        break;
      case 2:
        out.errMessage = r.readString();
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return out;
}

export function loadSettingsFiles(
  instance: WebAssembly.Instance,
  args: LoadSettingsFilesArgs
): LoadSettingsFilesResult {
  const encoded = concatBytes(
    stringField(1, args.workDir ?? ""),
    encodeStringList(2, args.files)
  );
  const result = callService(instance, "LoadSettingsFiles", encoded);
  const r = new ProtoReader(result);
  const out: LoadSettingsFilesResult = {
    kclCliConfigs: decodeCliConfig(new ProtoReader(new Uint8Array(0))),
    kclOptions: [],
  };
  while (!r.eof) {
    const tag = r.readTag();
    switch (tag >>> 3) {
      case 1:
        out.kclCliConfigs = decodeCliConfig(r.readMessage());
        break;
      case 2:
        out.kclOptions.push(decodeKeyValuePair(r.readMessage()));
        break;
      default:
        r.skip(tag & 7);
    }
  }
  return out;
}

export function rename(
  instance: WebAssembly.Instance,
  args: RenameArgs
): RenameResult {
  const encoded = concatBytes(
    stringField(1, args.packageRoot ?? ""),
    stringField(2, args.symbolPath ?? ""),
    encodeStringList(3, args.filePaths),
    stringField(4, args.newName ?? "")
  );
  const result = callService(instance, "Rename", encoded);
  const r = new ProtoReader(result);
  const out: RenameResult = { changedFiles: [] };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 1) out.changedFiles.push(r.readString());
    else r.skip(tag & 7);
  }
  return out;
}

export function renameCode(
  instance: WebAssembly.Instance,
  args: RenameCodeArgs
): RenameCodeResult {
  const entries = Object.entries(args.sourceCodes ?? {}).map(([k, v]) =>
    bytesField(3, concatBytes(stringField(1, k), stringField(2, v)))
  );
  const encoded = concatBytes(
    stringField(1, args.packageRoot ?? ""),
    stringField(2, args.symbolPath ?? ""),
    ...entries,
    stringField(4, args.newName ?? "")
  );
  const result = callService(instance, "RenameCode", encoded);
  const r = new ProtoReader(result);
  const out: RenameCodeResult = { changedCodes: {} };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 1) {
      const [k, v] = decodeStringMapEntry(r, (m) => m.readString());
      out.changedCodes[k] = v;
    } else {
      r.skip(tag & 7);
    }
  }
  return out;
}

export function test(
  instance: WebAssembly.Instance,
  args: TestArgs
): TestResult {
  const encoded = concatBytes(
    bytesField(
      1,
      args.execArgs ? encodeExecProgramArgs(args.execArgs) : new Uint8Array(0)
    ),
    encodeStringList(2, args.pkgList),
    stringField(3, args.runRegexp ?? ""),
    boolField(4, args.failFast ?? false)
  );
  const result = callService(instance, "Test", encoded);
  const r = new ProtoReader(result);
  const out: TestResult = { info: [] };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 2) out.info.push(decodeTestCaseInfo(r.readMessage()));
    else r.skip(tag & 7);
  }
  return out;
}

export function updateDependencies(
  instance: WebAssembly.Instance,
  args: UpdateDependenciesArgs
): UpdateDependenciesResult {
  const encoded = concatBytes(
    stringField(1, args.manifestPath ?? ""),
    boolField(2, args.vendor ?? false)
  );
  const result = callService(instance, "UpdateDependencies", encoded);
  const r = new ProtoReader(result);
  const out: UpdateDependenciesResult = { externalPkgs: [] };
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 3)
      out.externalPkgs.push(decodeExternalPkg(r.readMessage()));
    else r.skip(tag & 7);
  }
  return out;
}
