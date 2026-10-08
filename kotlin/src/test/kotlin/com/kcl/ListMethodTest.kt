package com.kcl

import com.kcl.api.API
import com.kcl.api.Spec.ListMethodResult
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue

class ListMethodTest {
    @Test
    fun testListMethod() {
        val api = API()
        val result: ListMethodResult = api.listMethod()
        assertNotNull(result.methodNameListList)
        assertTrue(result.methodNameListList.contains("KclService.ExecProgram"))
        assertTrue(result.methodNameListList.contains("KclService.GetVersion"))
        // Pin the registry size so a method cannot be dropped from the core
        // without this binding noticing -- `KclService.ListDepFiles` was removed
        // in v0.13.1, replaced by `LoadPackageResult.imports` / `kcl_mod` / `apps`.
        assertEquals(28, result.methodNameListList.size)
    }
}
