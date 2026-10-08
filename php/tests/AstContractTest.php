<?php

declare(strict_types=1);

namespace KclLib\Tests;

use KclLib\Ast\Arguments;
use KclLib\Ast\AssertStmt;
use KclLib\Ast\AssignStmt;
use KclLib\Ast\Ast;
use KclLib\Ast\BasicType;
use KclLib\Ast\Comment;
use KclLib\Ast\Expr;
use KclLib\Ast\Identifier;
use KclLib\Ast\ImportStmt;
use KclLib\Ast\LambdaExpr;
use KclLib\Ast\LiteralType;
use KclLib\Ast\MemberOrIndex;
use KclLib\Ast\Module;
use KclLib\Ast\NamedType;
use KclLib\Ast\NodeRef;
use KclLib\Ast\SchemaStmt;
use KclLib\Ast\Stmt;
use KclLib\Ast\Target;
use KclLib\Ast\Type;
use KclLib\Ast\UnionType;
use KclLib\Ast\AnyType;
use PHPUnit\Framework\TestCase;

/**
 * Decodes the shared golden capture (testdata/ast/alignment.json) through
 * the binding's real decoder and asserts the structure — the same fixture
 * every other binding's contract test pins, and the input the cross-language
 * diff harness compares.
 */
final class AstContractTest extends TestCase
{
    private static ?Module $module = null;

    public static function setUpBeforeClass(): void
    {
        $root = dirname(__DIR__, 2);
        self::$module = Ast::parseModule(
            (string) file_get_contents($root . '/testdata/ast/alignment.json')
        );
    }

    private static function module(): Module
    {
        return self::$module ?? throw new \LogicException('module not decoded');
    }

    public function testModuleShape(): void
    {
        $module = self::module();
        $this->assertSame('testdata/ast/alignment.k', $module->filename);
        $this->assertNull($module->doc);
        $this->assertCount(63, $module->body);
        $this->assertCount(33, $module->comments);
        foreach ($module->body as $ref) {
            $this->assertInstanceOf(NodeRef::class, $ref);
            $this->assertInstanceOf(Stmt::class, $ref->node);
        }
    }

    public function testCommentTextRoundTripsVerbatim(): void
    {
        $comment = self::module()->comments[0];
        $this->assertSame('testdata/ast/alignment.k', $comment->filename);
        $this->assertGreaterThan(0, $comment->line);
        $this->assertInstanceOf(Comment::class, $comment->node);
        // The comment object under `node` is {"text": …}, not the bare
        // string — reading one level too high is the bug this pins.
        $this->assertSame(
            '# Every AST node shape the language bindings model, in one file.',
            $comment->node->text
        );
    }

    public function testImportStmtIsFlatWithAStringPathNode(): void
    {
        $stmt = self::module()->body[0]->node;
        $this->assertInstanceOf(ImportStmt::class, $stmt);
        // `path` is a Node<String>: the payload is the bare string.
        $this->assertSame('data.cloud', $stmt->path->node);
        $this->assertSame('data.cloud', $stmt->rawpath);
        $this->assertSame('cloud', $stmt->name);
        $this->assertSame('__main__', $stmt->pkgName);
    }

    public function testTypeAliasesCoverEveryTypeVariant(): void
    {
        $ty = static fn (int $i): Type => self::module()->body[$i]->node->ty->node;

        $this->assertInstanceOf(AnyType::class, $ty(2));
        $this->assertInstanceOf(BasicType::class, $ty(3));
        $this->assertSame('Str', $ty(3)->name);
        $this->assertInstanceOf(NamedType::class, $ty(8));
        $this->assertInstanceOf(Identifier::class, $ty(8)->identifier);
        $this->assertSame(['Cloud'], array_map(
            static fn (NodeRef $n): string => $n->node,
            $ty(8)->identifier->names
        ));

        $union = $ty(6);
        $this->assertInstanceOf(UnionType::class, $union);
        $this->assertCount(2, $union->typeElements);
        $this->assertInstanceOf(BasicType::class, $union->typeElements[0]->node);
        $this->assertContainsOnlyInstancesOf(NodeRef::class, $union->typeElements);
    }

    public function testLiteralTypeKeepsItsInnerDocumentVerbatim(): void
    {
        $ty = static fn (int $i): LiteralType => self::module()->body[$i]->node->ty->node;

        $int = $ty(9);
        $this->assertSame('Int', $int->inner_tag());
        $this->assertSame(['type' => 'Int', 'value' => ['value' => 1, 'suffix' => null]], $int->value);
        $this->assertSame('Str', $ty(10)->inner_tag());
        $this->assertSame('s', $ty(10)->value['value']);
        $this->assertSame('Bool', $ty(11)->inner_tag());
        $this->assertSame('Float', $ty(12)->inner_tag());
    }

    public function testSchemaStmtIndexSignatureAndArgumentDefaults(): void
    {
        $person = self::module()->body[13]->node;
        $bag = self::module()->body[14]->node;
        $this->assertInstanceOf(SchemaStmt::class, $person);
        $this->assertInstanceOf(SchemaStmt::class, $bag);
        $this->assertSame('Person', $person->name->node);
        $this->assertNull($person->args);
        $this->assertNull($person->indexSignature);

        // `schema Bag[k: str]: ...` carries the index signature in its body
        // statement slot, not the header args.
        $sig = $bag->indexSignature;
        $this->assertNotNull($sig);
        $this->assertSame('k', $sig->node->keyName->node);
        $this->assertFalse($sig->node->anyOther);
    }

    public function testLambdaDefaultsKeepTheirNullSlots(): void
    {
        $lambda = null;
        $walk = static function (mixed $node) use (&$lambda, &$walk): void {
            if ($lambda !== null || $node === null) {
                return;
            }
            if ($node instanceof LambdaExpr) {
                $lambda = $node;
                return;
            }
            if ($node instanceof NodeRef) {
                $walk($node->node);
                return;
            }
            if (is_array($node)) {
                foreach ($node as $item) {
                    $walk($item);
                }
                return;
            }
            if (is_object($node)) {
                foreach (get_object_vars($node) as $value) {
                    $walk($value);
                }
            }
        };
        $walk(self::module());
        $this->assertInstanceOf(LambdaExpr::class, $lambda, 'the capture has a lambda assignment');
        $args = $lambda->args->node;
        $this->assertCount(count($args->args), $args->defaults);
        $this->assertContainsOnlyInstancesOf(NodeRef::class, $args->args);
    }

    public function testMemberOrIndexPathsAreWholeNodeRefs(): void
    {
        $member = 0;
        $index = 0;
        $walkTargets = function (mixed $node) use (&$member, &$index, &$walkTargets): void {
            if ($node instanceof Target) {
                foreach ($node->paths as $path) {
                    $this->assertInstanceOf(MemberOrIndex::class, $path);
                    $this->assertInstanceOf(NodeRef::class, $path->node);
                    if ($path->kind === 'Member') {
                        $member++;
                        $this->assertIsString($path->node->node);
                    } elseif ($path->kind === 'Index') {
                        $index++;
                        $this->assertInstanceOf(Expr::class, $path->node->node);
                    } else {
                        $this->fail("unknown MemberOrIndex kind {$path->kind}");
                    }
                }
            }
            if ($node instanceof NodeRef) {
                $walkTargets($node->node);
            } elseif (is_array($node)) {
                foreach ($node as $item) {
                    $walkTargets($item);
                }
            } elseif (is_object($node)) {
                foreach (get_object_vars($node) as $value) {
                    $walkTargets($value);
                }
            }
        };
        $walkTargets(self::module());
        $this->assertGreaterThan(0, $member);
        $this->assertGreaterThan(0, $index);
    }

    public function testAssignTargetsDecodeAsTargetsWithANameNode(): void
    {
        $stmt = self::module()->body[23]->node;
        $this->assertInstanceOf(AssignStmt::class, $stmt);
        $target = $stmt->targets[0]->node;
        $this->assertInstanceOf(Target::class, $target);
        $this->assertSame('x', $target->name->node);
        $this->assertSame('name', $target->paths[0]->node->node);
    }

    public function testParseProgramFlattensTheEnvelope(): void
    {
        $root = dirname(__DIR__, 2);
        $envelope = [
            'root' => '/mock',
            'pkgs' => ['__main__' => [json_decode((string) file_get_contents($root . '/testdata/ast/alignment.json'), true)]],
        ];
        $modules = Ast::parseProgram((string) json_encode($envelope));
        $this->assertCount(1, $modules);
        $this->assertInstanceOf(Module::class, $modules[0]);
        $this->assertSame('testdata/ast/alignment.k', $modules[0]->filename);

        $legacy = Ast::parseProgram((string) json_encode([$envelope['pkgs']['__main__']]));
        $this->assertCount(1, $legacy);
    }

    public function testUnknownTagsDecodeToNullRatherThanZeroNodes(): void
    {
        $this->assertNull(Expr::fromWire(['type' => 'NotARealExpr']));
        $this->assertNull(Stmt::fromWire(['type' => 'NotARealStmt']));
        $this->assertNull(Type::fromWire(['type' => 'NotARealType']));
        $this->assertNull(Expr::fromWire(null));

        $assert = Stmt::fromWire([
            'type' => 'Assert',
            'test' => ['node' => ['type' => 'NameConstantLit', 'value' => 'True'], 'line' => 1],
        ]);
        $this->assertInstanceOf(AssertStmt::class, $assert);
    }
}
