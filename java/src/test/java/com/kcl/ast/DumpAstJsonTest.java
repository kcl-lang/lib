package com.kcl.ast;

import com.kcl.api.API;
import com.kcl.api.Spec.ParseFileArgs;
import com.kcl.api.Spec.ParseFileResult;
import org.junit.Test;

/**
 * Diagnostic helper — prints the AST JSON for the alignment fixture so we can
 * inspect the actual wire shape coming out of the parser.
 */
public class DumpAstJsonTest {
    @Test
    public void dumpAstJson() throws Exception {
        API api = new API();
        ParseFileResult r = api.parseFile(ParseFileArgs.newBuilder()
                .setPath("src/test_data/ast_alignment/main.k").build());
        System.out.println("AST_JSON_BEGIN");
        System.out.println(r.getAstJson());
        System.out.println("AST_JSON_END");
    }
}
