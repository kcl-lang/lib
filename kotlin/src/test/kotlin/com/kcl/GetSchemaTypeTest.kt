package com.kcl

import com.kcl.api.API
import com.kcl.api.execProgramArgs
import com.kcl.api.getSchemaTypeMappingArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class GetSchemaTypeTest {
    companion object {
        private const val TEST_FILE = "./src/test_data/schema.k"
    }

    @Test
    fun testGetSchemaTypeApi() {
        val args = getSchemaTypeMappingArgs { execArgs = execProgramArgs { kFilenameList += TEST_FILE } }
        val api = API()
        val result = api.getSchemaTypeMapping(args)
        val appSchemaType = result.schemaTypeMappingMap["app"] ?: throw AssertionError("App schema type not found")
        val replicasAttr = appSchemaType.properties["replicas"] ?: throw AssertionError("App schema type of `replicas` not found")
        assertEquals(replicasAttr.type, "int")
    }
}
