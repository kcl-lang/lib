<?php

declare(strict_types=1);

namespace KclLib\Tests;

use KclLib\KclException;
use KclLib\ServiceClient;
use PHPUnit\Framework\TestCase;

/**
 * The service client against the vendored prebuilt libkcl: the happy path
 * (Ping, ExecProgram), the in-band error contract (the "ERROR:" prefix
 * becomes a KclException), BuiltinService.ListMethod, and the plugin-agent
 * entry point through a service handle.
 */
final class ServiceClientTest extends TestCase
{
    private static ?ServiceClient $client = null;

    public static function setUpBeforeClass(): void
    {
        self::$client = new ServiceClient();
    }

    private static function client(): ServiceClient
    {
        return self::$client ??= new ServiceClient();
    }

    public function testPingRoundTripsTheValue(): void
    {
        $result = self::client()->ping(['value' => 'hello from php']);
        $this->assertSame('hello from php', $result->getValue());
    }

    public function testPingAcceptsAMessageInstance(): void
    {
        $result = self::client()->ping(new \Com\Kcl\Api\PingArgs(['value' => 'msg']));
        $this->assertSame('msg', $result->getValue());
    }

    public function testExecProgramRunsInMemoryCode(): void
    {
        $result = self::client()->execProgram(['k_code_list' => ['alice = {age = 18}']]);
        $this->assertSame('{"alice": {"age": 18}}', $result->getJsonResult());
        $this->assertSame("alice:\n  age: 18", $result->getYamlResult());
        $this->assertSame('', $result->getErrMessage());
    }

    public function testExecProgramAppliesOverrides(): void
    {
        $result = self::client()->execProgram([
            'k_code_list' => ['alice = {age = 1}'],
            'overrides' => ['alice.age=18'],
        ]);
        $this->assertSame('{"alice": {"age": 18}}', $result->getJsonResult());
    }

    public function testUnknownFileRaisesKclException(): void
    {
        try {
            self::client()->execProgram(['k_filename_list' => ['definitely-not-there.k']]);
            $this->fail('expected KclException');
        } catch (KclException $e) {
            $this->assertStringStartsNotWith('ERROR:', $e->getMessage());
            $this->assertStringContainsStringIgnoringCase('cannot find the kcl file', $e->getMessage());
        }
    }

    public function testListMethodEnumeratesTheDispatcher(): void
    {
        // Cores that predate BuiltinService.ListMethod answer with an empty
        // list or raise; both are a skip, mirroring the Lua and Julia specs.
        try {
            $result = self::client()->listMethod();
        } catch (KclException) {
            $this->markTestSkipped('core does not list methods (old core)');
        }
        $names = iterator_to_array($result->getMethodNameList());
        if ($names === []) {
            $this->markTestSkipped('core lists no methods (old core)');
        }
        $this->assertContains('KclService.Ping', $names);
        $this->assertContains('KclService.ExecProgram', $names);
    }

    public function testPluginAgentReceivesKclPluginCalls(): void
    {
        $calls = [];
        $client = new ServiceClient(null, function (string $method, string $args, string $kwargs) use (&$calls): string {
            $calls[] = ['method' => $method, 'args' => $args, 'kwargs' => $kwargs];
            return '"joined-by-php"';
        });

        $result = $client->execProgram([
            'k_code_list' => ['import kcl_plugin.strings' . "\n" . 'result = strings.join("a", "b")'],
        ]);
        $this->assertSame('{"result": "joined-by-php"}', $result->getJsonResult());

        $this->assertCount(1, $calls);
        $this->assertSame('kcl_plugin.strings.join', $calls[0]['method']);
        $this->assertSame('["a", "b"]', $calls[0]['args']);
    }

    public function testGetVersionReportsTheCore(): void
    {
        $result = self::client()->getVersion();
        $this->assertNotSame('', $result->getVersion());
    }
}
