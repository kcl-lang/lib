package com.kcl

import com.kcl.api.API
import com.kcl.api.execProgramArgs
import com.kcl.api.externalPkg
import com.kcl.api.getSchemaTypeMappingArgs
import java.nio.file.Paths
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue

class GetSchemaTypeUnderPathTest {
    companion object {
        private val ROOT = Paths.get("./src/test_data/get_schema_ty_under_path").toAbsolutePath()
    }

    @Test
    fun testGetSchemaTypeUnderPathApi() {
        val execArgsInput = execProgramArgs {
            kFilenameList += ROOT.resolve("aaa").toString()
            externalPkgs += externalPkg {
                pkgName = "bbb"
                pkgPath = ROOT.resolve("bbb").toString()
            }
        }
        val args = getSchemaTypeMappingArgs { execArgs = execArgsInput }
        val api = API()
        val result = api.getSchemaTypeMappingUnderPath(args)

        // Schemas from the external dependency package must be keyed under
        // their own package name, not flattened into "__main__".
        val bbbSchemas = result.getSchemaTypeMappingOrThrow("bbb").schemaTypeList
            .associateBy { it.schemaName }
        assertTrue("Base" in bbbSchemas && "B" in bbbSchemas, "expected schemas Base and B in bbb, got ${bbbSchemas.keys}")

        val base = bbbSchemas["Base"] ?: throw AssertionError("Base schema not found")
        val b = bbbSchemas["B"] ?: throw AssertionError("B schema not found")
        // Regression for https://github.com/kcl-lang/kcl/issues/1546.
        assertEquals("bbb", base.pkgPath)
        assertEquals("bbb", b.pkgPath)
        assertTrue(b.hasBaseSchema(), "B.base_schema must be resolved across the package boundary")
        assertEquals("Base", b.baseSchema.schemaName)
        assertEquals("bbb", b.baseSchema.pkgPath)

        // The main package keeps its own schemas too.
        assertTrue(
            result.getSchemaTypeMappingOrThrow("__main__").schemaTypeList.any { it.schemaName == "A" },
            "expected schema A in __main__",
        )
    }
}
