<?php

// Cross-language AST dump for the PHP binding.
//
//   php hack/dump/php.php <golden.json> <out.json>
//
// Runs the binding's real decoder (KclLib\Ast\Ast::parseModule) over the
// shared capture and writes the tree in the shape hack/ast_diff/canonical.rb
// compares: every object carries "@cls" (the binding's own class name) and
// the tagged variants carry "@tag" (the wire tag the class decodes). PHP
// decodes into class instances rather than plain arrays, so the walk is a
// reflection over the DTO properties — the same field list the L3
// field-types checker reads statically, walked here at runtime.
//
// Two PHP-specific shapes the walk has to get right:
//
//   * A `NodeRef<T>` wrapper flattens the five position keys onto the
//     object beside `node`; the walk writes them flat, which is the wire
//     shape (no `pos` container, R2 is a no-op on this side).
//   * `LiteralType` keeps its inner `tag/content` document verbatim, and
//     the derived `inner_tag()` is written out as `innerTag` — an extra key
//     the harness expects, a copy of `value.type` the wire does not carry.

declare(strict_types=1);

require __DIR__ . '/../../php/vendor/autoload.php';

use KclLib\Ast\Ast;
use KclLib\Ast\LiteralType;

// The wire tag each variant class decodes. Cross-checked three ways by the
// harness (@tag here, @cls in CLASS_TAGS, and the golden itself), so a tag
// that drifts from the dispatcher is a diff, not a silent pass.
const TAGS = [
    // ast::Expr
    KclLib\Ast\Target::class => 'Target',
    KclLib\Ast\Identifier::class => 'Identifier',
    KclLib\Ast\UnaryExpr::class => 'Unary',
    KclLib\Ast\BinaryExpr::class => 'Binary',
    KclLib\Ast\IfExpr::class => 'If',
    KclLib\Ast\SelectorExpr::class => 'Selector',
    KclLib\Ast\CallExpr::class => 'Call',
    KclLib\Ast\ParenExpr::class => 'Paren',
    KclLib\Ast\QuantExpr::class => 'Quant',
    KclLib\Ast\ListExpr::class => 'List',
    KclLib\Ast\ListIfItemExpr::class => 'ListIfItem',
    KclLib\Ast\ListComp::class => 'ListComp',
    KclLib\Ast\StarredExpr::class => 'Starred',
    KclLib\Ast\DictComp::class => 'DictComp',
    KclLib\Ast\ConfigIfEntryExpr::class => 'ConfigIfEntry',
    KclLib\Ast\ConfigExpr::class => 'Config',
    KclLib\Ast\CheckExpr::class => 'Check',
    KclLib\Ast\LambdaExpr::class => 'Lambda',
    KclLib\Ast\Subscript::class => 'Subscript',
    KclLib\Ast\Keyword::class => 'Keyword',
    KclLib\Ast\Arguments::class => 'Arguments',
    KclLib\Ast\Compare::class => 'Compare',
    KclLib\Ast\NumberLit::class => 'NumberLit',
    KclLib\Ast\StringLit::class => 'StringLit',
    KclLib\Ast\NameConstantLit::class => 'NameConstantLit',
    KclLib\Ast\JoinedString::class => 'JoinedString',
    KclLib\Ast\FormattedValue::class => 'FormattedValue',
    KclLib\Ast\MissingExpr::class => 'Missing',
    // ast::Stmt
    KclLib\Ast\TypeAliasStmt::class => 'TypeAlias',
    KclLib\Ast\ExprStmt::class => 'Expr',
    KclLib\Ast\UnificationStmt::class => 'Unification',
    KclLib\Ast\AssignStmt::class => 'Assign',
    KclLib\Ast\AugAssignStmt::class => 'AugAssign',
    KclLib\Ast\AssertStmt::class => 'Assert',
    KclLib\Ast\IfStmt::class => 'If',
    KclLib\Ast\ImportStmt::class => 'Import',
    KclLib\Ast\SchemaStmt::class => 'Schema',
    KclLib\Ast\SchemaAttr::class => 'SchemaAttr',
    KclLib\Ast\RuleStmt::class => 'Rule',
    // ast::Type
    KclLib\Ast\AnyType::class => 'Any',
    KclLib\Ast\BasicType::class => 'Basic',
    KclLib\Ast\NamedType::class => 'Named',
    KclLib\Ast\ListType::class => 'List',
    KclLib\Ast\DictType::class => 'Dict',
    KclLib\Ast\UnionType::class => 'Union',
    KclLib\Ast\LiteralType::class => 'Literal',
    KclLib\Ast\FunctionType::class => 'Function',
];

/**
 * Recursively copy a decoded AST value into the canonical dump shape.
 *
 * @return mixed
 */
function dumpValue(mixed $v): mixed
{
    if ($v === null || is_string($v) || is_bool($v) || is_int($v) || is_float($v)) {
        return $v;
    }
    if (is_array($v)) {
        if (!array_is_list($v)) {
            // A verbatim document (`LiteralType` keeps its inner
            // `tag/content` payload whole) — the keys are data, not list
            // positions, and dropping them would turn the object into a
            // two-element list the comparator reads as a shape change.
            $out = [];
            foreach ($v as $key => $item) {
                $out[$key] = dumpValue($item);
            }

            return $out;
        }
        $out = [];
        foreach ($v as $item) {
            // A null slot (Vec<Option<NodeRef>>) stays a null slot, so the
            // golden and the dump agree on the shape and R14 reads between
            // them the same way as for Lua's sentinel.
            $out[] = dumpValue($item);
        }

        return $out;
    }

    $class = new ReflectionClass($v);
    $out = ['@cls' => $class->getShortName()];
    $tag = TAGS[$class->name] ?? null;
    if ($tag !== null) {
        $out['@tag'] = $tag;
    }
    foreach ($class->getProperties(ReflectionProperty::IS_PUBLIC) as $property) {
        $key = $property->getName();
        $value = $property->getValue($v);
        if ($key === 'innerTag') {
            // Derived, not read off the wire; written explicitly below.
            continue;
        }
        $out[$key] = dumpValue($value);
    }
    if ($v instanceof LiteralType) {
        $out['innerTag'] = $v->inner_tag();
    }

    return $out;
}

$goldenPath = $argv[1] ?? null;
$outPath = $argv[2] ?? null;
if ($goldenPath === null || $outPath === null) {
    fwrite(STDERR, "usage: php hack/dump/php.php <golden.json> <out.json>\n");
    exit(2);
}

$golden = file_get_contents($goldenPath);
if ($golden === false) {
    fwrite(STDERR, "cannot open {$goldenPath}\n");
    exit(2);
}

$module = Ast::parseModule($golden);

$doc = [
    'schema' => 'kcl-ast-canonical/1',
    'binding' => 'php',
    'mode' => 'reflect',
    'root' => dumpValue($module),
];

file_put_contents($outPath, json_encode($doc, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
