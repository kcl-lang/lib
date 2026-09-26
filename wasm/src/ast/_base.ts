// _base.ts — Pos, Node<T>, Comment, and the top-level parse helpers.
// Mirrors `ast::Pos` / `NodeRef<T>` / `Comment` in `crates/ast/src/ast.rs`.

export interface Pos {
  filename: string;
  line: number;
  column: number;
  endLine: number;
  endColumn: number;
}

export interface Node<T> {
  node: T;
  filename?: string;
  line?: number;
  column?: number;
  endLine?: number;
  endColumn?: number;
}

export type Comment = Node<string>;

interface WirePos {
  filename: string;
  line: number;
  column: number;
  end_line: number;
  end_column: number;
}

interface WireNode<U> {
  node: U;
  filename?: string;
  line?: number;
  column?: number;
  end_line?: number;
  end_column?: number;
}

export function posFromWire(w: WirePos | undefined | null): Pos | undefined {
  if (!w) return undefined;
  return {
    filename: w.filename,
    line: w.line,
    column: w.column,
    endLine: w.end_line,
    endColumn: w.end_column,
  };
}

export function nodeFromWire<T, U>(w: WireNode<U> | undefined | null, load: (inner: U) => T): Node<T> | undefined {
  if (!w) return undefined;
  const inner = w.node !== undefined ? load(w.node) : (undefined as unknown as T);
  return {
    node: inner,
    filename: w.filename,
    line: w.line,
    column: w.column,
    endLine: w.end_line,
    endColumn: w.end_column,
  };
}

export function commentFromWire(w: WireNode<string> | undefined | null): Comment | undefined {
  return nodeFromWire(w, (x) => x);
}