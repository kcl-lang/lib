from ._kcl_lib import *
from . import api, ast, plugin
from .api.service import API
from .ast import Module, Node, Pos, parse_module, parse_program

# ``Position`` is the PascalCase alias matching kcl-go/Java/Node.js exports.
Position = Pos
