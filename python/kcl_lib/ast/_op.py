"""Operator enums used across the AST.

Each enum value is the exact string the Rust compiler emits via
``#[serde(rename_all = ...)]``. Keep these in sync with the
``crate::op`` definitions in ``kcl-lang/kcl/crates/ast``.
"""

from __future__ import annotations

from enum import Enum


class AugOp(str, Enum):
    """Augmented assignment operator (e.g. ``x += 1``)."""

    Assign = "Assign"
    Add = "Add"
    Sub = "Sub"
    Mul = "Mul"
    Div = "Div"
    Mod = "Mod"
    BitOr = "BitOr"
    BitXor = "BitXor"
    BitAnd = "BitAnd"
    LShift = "LShift"
    RShift = "RShift"
    Pow = "Pow"
    FloorDiv = "FloorDiv"


class BinOp(str, Enum):
    Add = "Add"
    Sub = "Sub"
    Mul = "Mul"
    Div = "Div"
    Mod = "Mod"
    FloorDiv = "FloorDiv"
    Pow = "Pow"
    LShift = "LShift"
    RShift = "RShift"
    BitOr = "BitOr"
    BitXor = "BitXor"
    BitAnd = "BitAnd"
    Or = "Or"
    And = "And"
    Is = "Is"
    IsNot = "IsNot"
    Not = "Not"
    In = "In"
    NotIn = "NotIn"


class UnaryOp(str, Enum):
    Add = "Add"
    Sub = "Sub"
    Invert = "Invert"
    Not = "Not"
    Is = "Is"


class CmpOp(str, Enum):
    Eq = "Eq"
    NotEq = "NotEq"
    Lt = "Lt"
    LtE = "LtE"
    Gt = "Gt"
    GtE = "GtE"


class QuantOperation(str, Enum):
    All = "All"
    Any = "Any"
    Map = "Map"
    Filter = "Filter"


class ConfigEntryOperation(str, Enum):
    Union = "Union"
    Override = "Override"
    Insert = "Insert"


class NumberBinarySuffix(str, Enum):
    """Binary-size suffix on numeric literals (``1Ki``, ``2Mi``...)."""

    n = "n"
    u = "u"
    m = "m"
    K = "K"
    M = "M"
    G = "G"
    T = "T"
    P = "P"
    Ki = "Ki"
    Mi = "Mi"
    Gi = "Gi"
    Ti = "Ti"
    Pi = "Pi"