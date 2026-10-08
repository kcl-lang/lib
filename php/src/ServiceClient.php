<?php

declare(strict_types=1);

namespace KclLib;

use Com\Kcl\Api\ExecProgramArgs;
use Com\Kcl\Api\ExecProgramResult;
use Com\Kcl\Api\FormatCodeArgs;
use Com\Kcl\Api\FormatCodeResult;
use Com\Kcl\Api\FormatPathArgs;
use Com\Kcl\Api\FormatPathResult;
use Com\Kcl\Api\FormatTestReportArgs;
use Com\Kcl\Api\FormatTestReportResult;
use Com\Kcl\Api\GenerateDocArgs;
use Com\Kcl\Api\GenerateDocResult;
use Com\Kcl\Api\GenerateKclArgs;
use Com\Kcl\Api\GenerateKclResult;
use Com\Kcl\Api\GenerateOpenAPIArgs;
use Com\Kcl\Api\GenerateOpenAPIResult;
use Com\Kcl\Api\GenerateProtoArgs;
use Com\Kcl\Api\GenerateProtoResult;
use Com\Kcl\Api\GenerateTomlArgs;
use Com\Kcl\Api\GenerateTomlResult;
use Com\Kcl\Api\GetSchemaTypeMappingArgs;
use Com\Kcl\Api\GetSchemaTypeMappingResult;
use Com\Kcl\Api\GetSchemaTypeMappingUnderPathResult;
use Com\Kcl\Api\GetVersionArgs;
use Com\Kcl\Api\GetVersionResult;
use Com\Kcl\Api\LintPathArgs;
use Com\Kcl\Api\LintPathResult;
use Com\Kcl\Api\ListMethodArgs;
use Com\Kcl\Api\ListMethodResult;
use Com\Kcl\Api\ListOptionsResult;
use Com\Kcl\Api\ListVariablesArgs;
use Com\Kcl\Api\ListVariablesResult;
use Com\Kcl\Api\LoadPackageArgs;
use Com\Kcl\Api\LoadPackageResult;
use Com\Kcl\Api\LoadSettingsFilesArgs;
use Com\Kcl\Api\LoadSettingsFilesResult;
use Com\Kcl\Api\OverrideFileArgs;
use Com\Kcl\Api\OverrideFileResult;
use Com\Kcl\Api\ParseFileArgs;
use Com\Kcl\Api\ParseFileResult;
use Com\Kcl\Api\ParseProgramArgs;
use Com\Kcl\Api\ParseProgramResult;
use Com\Kcl\Api\PingArgs;
use Com\Kcl\Api\PingResult;
use Com\Kcl\Api\RenameArgs;
use Com\Kcl\Api\RenameCodeArgs;
use Com\Kcl\Api\RenameCodeResult;
use Com\Kcl\Api\RenameResult;
use Com\Kcl\Api\TestArgs;
use Com\Kcl\Api\TestResult;
use Com\Kcl\Api\UpdateDependenciesArgs;
use Com\Kcl\Api\UpdateDependenciesResult;
use Com\Kcl\Api\ValidateCodeArgs;
use Com\Kcl\Api\ValidateCodeResult;
use Google\Protobuf\Internal\Message;

/**
 * One method per RPC in spec/spec.proto, in the order the two services
 * declare them: BuiltinService (Ping, ListMethod) then KclService.
 *
 * Each method takes its request message (or a plain array, converted through
 * the protobuf-JSON codec — the PHP runtime accepts the proto field names,
 * so the snake_case spellings in tests/consistency/cases.json apply
 * directly), calls the native dispatcher through {@see KclLib}, and returns
 * the decoded result message. A reply beginning with the "ERROR:" prefix
 * becomes a KclException (docs/abi.md §4).
 *
 * All methods are thin by design: behavior lives in the native core exactly
 * once (docs/architecture.md §2 rule 1), so there is nothing here but
 * serialize, call, decode, raise.
 */
final class ServiceClient
{
    private KclLib $lib;

    /** @var callable|null plugin agent routed through a service handle */
    private $pluginAgent;

    public function __construct(?KclLib $lib = null, ?callable $pluginAgent = null)
    {
        $this->lib = $lib ?? KclLib::default();
        $this->pluginAgent = $pluginAgent;
    }

    // ------------------------------------------------------------------
    // BuiltinService
    // ------------------------------------------------------------------

    /** BuiltinService.ListMethod: every method exposed by the native dispatcher. */
    public function listMethod(ListMethodArgs|array $args = []): ListMethodResult
    {
        return $this->call('BuiltinService.ListMethod', $args, ListMethodResult::class);
    }

    // ------------------------------------------------------------------
    // KclService
    // ------------------------------------------------------------------

    /** KclService.Ping: returns the same value as the parameter. */
    public function ping(PingArgs|array $args): PingResult
    {
        return $this->call('KclService.Ping', $args, PingResult::class);
    }

    /** KclService.GetVersion: the kcl service version information. */
    public function getVersion(GetVersionArgs|array $args = []): GetVersionResult
    {
        return $this->call('KclService.GetVersion', $args, GetVersionResult::class);
    }

    /** KclService.ParseProgram: parse KCL programs with entry files. */
    public function parseProgram(ParseProgramArgs|array $args): ParseProgramResult
    {
        return $this->call('KclService.ParseProgram', $args, ParseProgramResult::class);
    }

    /** KclService.ParseFile: parse a single KCL file (or in-memory source). */
    public function parseFile(ParseFileArgs|array $args): ParseFileResult
    {
        return $this->call('KclService.ParseFile', $args, ParseFileResult::class);
    }

    /** KclService.LoadPackage: parse program plus semantic model information. */
    public function loadPackage(LoadPackageArgs|array $args): LoadPackageResult
    {
        return $this->call('KclService.LoadPackage', $args, LoadPackageResult::class);
    }

    /** KclService.ListOptions: all option information of the parsed program. */
    public function listOptions(ParseProgramArgs|array $args): ListOptionsResult
    {
        return $this->call('KclService.ListOptions', $args, ListOptionsResult::class);
    }

    /** KclService.ListVariables: variables of the parsed files by specs. */
    public function listVariables(ListVariablesArgs|array $args): ListVariablesResult
    {
        return $this->call('KclService.ListVariables', $args, ListVariablesResult::class);
    }

    /** KclService.ExecProgram: execute KCL files or in-memory code with args. */
    public function execProgram(ExecProgramArgs|array $args): ExecProgramResult
    {
        return $this->call('KclService.ExecProgram', $args, ExecProgramResult::class);
    }

    /** KclService.OverrideFile: override a KCL file with `-O` specs. */
    public function overrideFile(OverrideFileArgs|array $args): OverrideFileResult
    {
        return $this->call('KclService.OverrideFile', $args, OverrideFileResult::class);
    }

    /** KclService.GetSchemaTypeMapping: schema types by schema name. */
    public function getSchemaTypeMapping(GetSchemaTypeMappingArgs|array $args): GetSchemaTypeMappingResult
    {
        return $this->call('KclService.GetSchemaTypeMapping', $args, GetSchemaTypeMappingResult::class);
    }

    /** KclService.GetSchemaTypeMappingUnderPath: schema types by package. */
    public function getSchemaTypeMappingUnderPath(GetSchemaTypeMappingArgs|array $args): GetSchemaTypeMappingUnderPathResult
    {
        return $this->call('KclService.GetSchemaTypeMappingUnderPath', $args, GetSchemaTypeMappingUnderPathResult::class);
    }

    /** KclService.FormatCode: format an in-memory KCL source string. */
    public function formatCode(FormatCodeArgs|array $args): FormatCodeResult
    {
        return $this->call('KclService.FormatCode', $args, FormatCodeResult::class);
    }

    /** KclService.FormatPath: format KCL files under a path. */
    public function formatPath(FormatPathArgs|array $args): FormatPathResult
    {
        return $this->call('KclService.FormatPath', $args, FormatPathResult::class);
    }

    /** KclService.LintPath: lint files, returning diagnostics. */
    public function lintPath(LintPathArgs|array $args): LintPathResult
    {
        return $this->call('KclService.LintPath', $args, LintPathResult::class);
    }

    /** KclService.ValidateCode: validate data against a schema. */
    public function validateCode(ValidateCodeArgs|array $args): ValidateCodeResult
    {
        return $this->call('KclService.ValidateCode', $args, ValidateCodeResult::class);
    }

    /** KclService.LoadSettingsFiles: merged kcl.yaml settings. */
    public function loadSettingsFiles(LoadSettingsFilesArgs|array $args): LoadSettingsFilesResult
    {
        return $this->call('KclService.LoadSettingsFiles', $args, LoadSettingsFilesResult::class);
    }

    /** KclService.Rename: rename a symbol across files, rewriting them. */
    public function rename(RenameArgs|array $args): RenameResult
    {
        return $this->call('KclService.Rename', $args, RenameResult::class);
    }

    /** KclService.RenameCode: rename a symbol in in-memory sources. */
    public function renameCode(RenameCodeArgs|array $args): RenameCodeResult
    {
        return $this->call('KclService.RenameCode', $args, RenameCodeResult::class);
    }

    /** KclService.Test: run KCL package tests. */
    public function test(TestArgs|array $args): TestResult
    {
        return $this->call('KclService.Test', $args, TestResult::class);
    }

    /** KclService.FormatTestReport: render a TestResult as a report. */
    public function formatTestReport(FormatTestReportArgs|array $args): FormatTestReportResult
    {
        return $this->call('KclService.FormatTestReport', $args, FormatTestReportResult::class);
    }

    /** KclService.UpdateDependencies: download and update kcl.mod deps. */
    public function updateDependencies(UpdateDependenciesArgs|array $args): UpdateDependenciesResult
    {
        return $this->call('KclService.UpdateDependencies', $args, UpdateDependenciesResult::class);
    }

    /** KclService.GenerateToml: evaluate a program and serialize to TOML. */
    public function generateToml(GenerateTomlArgs|array $args): GenerateTomlResult
    {
        return $this->call('KclService.GenerateToml', $args, GenerateTomlResult::class);
    }

    /** KclService.GenerateKcl: KCL source from JSON, YAML or TOML data. */
    public function generateKcl(GenerateKclArgs|array $args): GenerateKclResult
    {
        return $this->call('KclService.GenerateKcl', $args, GenerateKclResult::class);
    }

    /** KclService.GenerateOpenAPI: OpenAPI spec from package schemas. */
    public function generateOpenAPI(GenerateOpenAPIArgs|array $args): GenerateOpenAPIResult
    {
        return $this->call('KclService.GenerateOpenAPI', $args, GenerateOpenAPIResult::class);
    }

    /** KclService.GenerateProto: proto3 definitions from package schemas. */
    public function generateProto(GenerateProtoArgs|array $args): GenerateProtoResult
    {
        return $this->call('KclService.GenerateProto', $args, GenerateProtoResult::class);
    }

    /** KclService.GenerateDoc: documentation from package schemas. */
    public function generateDoc(GenerateDocArgs|array $args): GenerateDocResult
    {
        return $this->call('KclService.GenerateDoc', $args, GenerateDocResult::class);
    }

    // ------------------------------------------------------------------
    // The dispatch every method above reduces to.
    // ------------------------------------------------------------------

    /**
     * @template T of Message
     * @param class-string<T> $resultClass
     * @return T
     */
    private function call(string $rpc, Message|array $args, string $resultClass): Message
    {
        $request = $this->requestOf($rpc, $args);
        $payload = $request->serializeToString();

        $raw = $this->pluginAgent !== null
            ? $this->lib->callWithPluginAgent($rpc, $payload, $this->pluginAgent)
            : $this->lib->callNative($rpc, $payload);

        if (str_starts_with($raw, 'ERROR:')) {
            throw new KclException(substr($raw, strlen('ERROR:')));
        }

        return $this->merge($resultClass, $raw);
    }

    /**
     * @template T of Message
     * @param class-string<T> $resultClass
     * @return T
     */
    private function merge(string $resultClass, string $raw): Message
    {
        $result = new $resultClass();
        $result->mergeFromString($raw);

        return $result;
    }

    private function requestOf(string $rpc, Message|array $args): Message
    {
        if ($args instanceof Message) {
            return $args;
        }

        $request = $this->newRequest($rpc);
        if ($args !== []) {
            $encoded = json_encode($args, JSON_THROW_ON_ERROR);
            // The protobuf PHP runtime's JSON codec accepts the proto field
            // names (snake_case) as well as their lowerCamelCase JSON names.
            $request->mergeFromJsonString($encoded);
        }

        return $request;
    }

    /**
     * The request message type each RPC name expects (spec/spec.proto).
     */
    private function newRequest(string $rpc): Message
    {
        $class = match ($rpc) {
            'BuiltinService.ListMethod' => ListMethodArgs::class,
            'KclService.Ping' => PingArgs::class,
            'KclService.GetVersion' => GetVersionArgs::class,
            'KclService.ParseProgram', 'KclService.ListOptions' => ParseProgramArgs::class,
            'KclService.ParseFile' => ParseFileArgs::class,
            'KclService.LoadPackage' => LoadPackageArgs::class,
            'KclService.ListVariables' => ListVariablesArgs::class,
            'KclService.ExecProgram' => ExecProgramArgs::class,
            'KclService.OverrideFile' => OverrideFileArgs::class,
            'KclService.GetSchemaTypeMapping',
            'KclService.GetSchemaTypeMappingUnderPath' => GetSchemaTypeMappingArgs::class,
            'KclService.FormatCode' => FormatCodeArgs::class,
            'KclService.FormatPath' => FormatPathArgs::class,
            'KclService.LintPath' => LintPathArgs::class,
            'KclService.ValidateCode' => ValidateCodeArgs::class,
            'KclService.LoadSettingsFiles' => LoadSettingsFilesArgs::class,
            'KclService.Rename' => RenameArgs::class,
            'KclService.RenameCode' => RenameCodeArgs::class,
            'KclService.Test' => TestArgs::class,
            'KclService.FormatTestReport' => FormatTestReportArgs::class,
            'KclService.UpdateDependencies' => UpdateDependenciesArgs::class,
            'KclService.GenerateToml' => GenerateTomlArgs::class,
            'KclService.GenerateKcl' => GenerateKclArgs::class,
            'KclService.GenerateOpenAPI' => GenerateOpenAPIArgs::class,
            'KclService.GenerateProto' => GenerateProtoArgs::class,
            'KclService.GenerateDoc' => GenerateDocArgs::class,
            default => throw new KclException("unknown RPC: {$rpc}"),
        };

        return new $class();
    }
}
