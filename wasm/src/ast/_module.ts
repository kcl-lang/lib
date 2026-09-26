// _module.ts — Module AST node + parseModule/parseProgram helpers.
//
// Mirrors `ast::Module` in `crates/ast/src/ast.rs`. The Rust struct has no
// `pkg` field — the Java/Go bindings previously exposed one and were aligned
// to drop it.

import { Comment, commentFromWire, Node, nodeFromWire } from "./_base";
import { stmtFromWire } from "./_stmt";

export interface Module {
  filename: string;
  doc?: Node<string>;
  body?: Array<Node<unknown>>;
  comments?: Array<Comment>;
}

export function moduleFromWire(w: Record<string, unknown>): Module {
  const body = ((w.body as unknown[]) || [])
    .map((b) => nodeFromWire(b as never, stmtFromWire as never))
    .filter((n): n is Node<unknown> => n !== undefined);
  const comments = ((w.comments as unknown[]) || [])
    .map((c) => commentFromWire(c as never))
    .filter((c): c is Comment => c !== undefined);
  return {
    filename: (w.filename as string) || "",
    doc: nodeFromWire(w.doc as never, (x: string) => x),
    body,
    comments,
  };
}

export function parseModule(astJson: string): Module {
  return moduleFromWire(JSON.parse(astJson));
}

export function parseProgram(programJson: string): Array<Module> {
  const env = JSON.parse(programJson);
  if (Array.isArray(env)) {
    return (env as unknown[]).map((m) => moduleFromWire(m as Record<string, unknown>));
  }
  const pkgs = (env.pkgs as Record<string, unknown> | undefined) || {};
  const main = (pkgs.__main__ as unknown[]) || [];
  return main.map((m) => moduleFromWire(m as Record<string, unknown>));
}